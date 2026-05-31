-- ─────────────────────────────────────────────────────────────────────────────
-- 006 — Social graph: one-way follows, mutual-follow friends, public profiles
--
-- Followers are one-way (Instagram-style, no approval). When A follows B and B
-- follows A they are "friends" (derived, no separate table). Public profiles
-- expose only safe columns via a view so the base user_profiles table keeps its
-- strict own-row-only RLS. See docs/plan/01-PRD.md §5.6–5.7, 03-DATABASE.md §3.1.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── follows: directed follow edges ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.follows (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    followee_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (follower_id, followee_id),
    CONSTRAINT follows_no_self CHECK (follower_id <> followee_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows (follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee ON public.follows (followee_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

-- A user may create/remove only their own outgoing follow edges.
CREATE POLICY "follows_insert_own"
    ON public.follows FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows_delete_own"
    ON public.follows FOR DELETE
    TO authenticated
    USING (auth.uid() = follower_id);

-- Any authenticated user can read follow edges — needed for counts, follower/
-- following lists, and mutual-friend detection. (The whole app already sits
-- behind the subscription paywall, so this is not anonymous-readable.)
CREATE POLICY "follows_select_authenticated"
    ON public.follows FOR SELECT
    TO authenticated
    USING (true);

-- ── friends: mutual follows (A→B AND B→A) ───────────────────────────────────
-- Security-definer view (default): reads follow edges regardless of the
-- caller's row policies. Safe — it exposes only the pair of user ids, which are
-- already readable via the follows SELECT policy above.
CREATE OR REPLACE VIEW public.friends AS
SELECT f1.follower_id AS user_id,
       f1.followee_id AS friend_id
FROM public.follows f1
JOIN public.follows f2
  ON f1.follower_id = f2.followee_id
 AND f1.followee_id = f2.follower_id;

GRANT SELECT ON public.friends TO authenticated;

-- ── public_profiles: safe, world-readable profile fields + social counts ────
-- Deliberately a security-DEFINER view (the default). It bypasses the strict
-- own-row-only RLS on user_profiles and exposes ONLY non-sensitive columns, so
-- any authenticated user can view anyone's public profile while subscription
-- status, fcm token, trial dates, language, etc. stay private. This is the
-- column-level privacy boundary RLS alone can't express.
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
    p.user_id,
    p.display_name,
    p.avatar_url,
    p.experience,
    p.created_at,
    (SELECT count(*) FROM public.follows f WHERE f.followee_id = p.user_id) AS follower_count,
    (SELECT count(*) FROM public.follows f WHERE f.follower_id = p.user_id) AS following_count,
    (SELECT count(*) FROM public.friends  fr WHERE fr.user_id  = p.user_id) AS friend_count
FROM public.user_profiles p
WHERE p.deleted_at IS NULL;

GRANT SELECT ON public.public_profiles TO authenticated;
