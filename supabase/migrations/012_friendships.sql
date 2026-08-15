-- ─────────────────────────────────────────────────────────────────────────────
-- 012 — Bros Phase B: friendships (request → accept), @username, reports
--
-- Replaces the one-way follows model (006) with mutual friendships per the
-- 2026-08-15 redesign (PRD §5.6, 03-DATABASE.md §3.1, 04-BACKEND.md §5).
-- Rebuilds the `friends` and `public_profiles` views on top of `friendships`
-- (same column contract the 008 leaderboard RPCs read), then drops `follows`.
--
-- Deviations from the 03-DATABASE.md §3.1 sketch (all strictly tighter):
--   1. `unique (requester_id, addressee_id)` is upgraded to a SYMMETRIC unique
--      index on (least(pair), greatest(pair)) — also forbids the reversed
--      duplicate (A→B and B→A coexisting after a request race).
--   2. Blocked rows can only be modified/deleted by the blocker — otherwise the
--      blocked party could delete the row and re-request (block evasion).
--   3. Update transitions are constrained: only the addressee can set
--      'accepted'; 'blocked' requires blocked_by = auth.uid(). Declining,
--      cancelling, and unfriending are DELETEs, unblocking is a DELETE by the
--      blocker (pair may then re-request). INSERT additionally allows a row
--      born 'blocked' (blocker = inserter) so a stranger can be blocked from
--      their profile before any request exists.
--   4. A trigger locks requester_id/addressee_id on UPDATE — without it an
--      accepted row's pair could be rewritten to fabricate a friendship with
--      a user who never consented (RLS WITH CHECK can't compare OLD vs NEW).
--   5. `public_profiles` loses follower_count/following_count (dead concepts —
--      view is dropped + recreated since REPLACE can't remove columns; the
--      008 RPCs only read user_id/display_name/avatar_url) and gains
--      `username`. friend_count now counts accepted friendships.
--   6. Per the doc, SELECT is allowed to both sides of a row including blocked
--      ones — the client renders the blocked state discreetly; the blocked
--      party seeing the raw status via the API is accepted at v1 scale.
--
-- NOT YET DEPLOYED — Supabase cloud project isn't provisioned (SETUP-STATUS).
-- TODO(deploy): run against the cloud project, then verify: RLS matrix
-- (request/accept/decline/block from both sides), username uniqueness race,
-- leaderboard_friends still returns rows, delete-account cascades the graph.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── friendships: one row per pair, direction = who asked ────────────────────
CREATE TABLE IF NOT EXISTS public.friendships (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    addressee_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'accepted', 'blocked')),
    blocked_by   uuid REFERENCES auth.users (id) ON DELETE CASCADE,
    created_at   timestamptz NOT NULL DEFAULT now(),
    responded_at timestamptz,
    CONSTRAINT friendships_no_self CHECK (requester_id <> addressee_id),
    -- blocked_by is set exactly when blocked, and must be one of the pair.
    CONSTRAINT friendships_blocked_by_consistent CHECK (
        (status = 'blocked' AND blocked_by IN (requester_id, addressee_id))
        OR (status <> 'blocked' AND blocked_by IS NULL)
    )
);

-- One row per unordered pair (deviation 1).
CREATE UNIQUE INDEX IF NOT EXISTS uniq_friendships_pair
    ON public.friendships (least(requester_id, addressee_id),
                           greatest(requester_id, addressee_id));
CREATE INDEX IF NOT EXISTS idx_friendships_requester
    ON public.friendships (requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee
    ON public.friendships (addressee_id);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Both sides of a row can read it (doc §3.1; deviation 6 for blocked rows).
CREATE POLICY "friendships_select_involved"
    ON public.friendships FOR SELECT
    TO authenticated
    USING (auth.uid() IN (requester_id, addressee_id));

-- Only I can create rows, either as a friend request (born 'pending') or as a
-- pre-emptive block of a stranger I have no row with yet (born 'blocked' with
-- me as blocker — needed so "block from profile" works before any request
-- exists). Never toward a pair that already has a row (the visible-row guard;
-- the symmetric unique index is the hard backstop for rows my SELECT policy
-- can't see).
CREATE POLICY "friendships_insert_own_request"
    ON public.friendships FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = requester_id
        AND responded_at IS NULL
        AND (
            (status = 'pending' AND blocked_by IS NULL)
            OR (status = 'blocked' AND blocked_by = auth.uid())
        )
        AND NOT EXISTS (
            SELECT 1
            FROM public.friendships f
            WHERE (f.requester_id = friendships.requester_id
                   AND f.addressee_id = friendships.addressee_id)
               OR (f.requester_id = friendships.addressee_id
                   AND f.addressee_id = friendships.requester_id)
        )
    );

-- Accept: addressee only. Block: either side, recording themselves as blocker.
-- A blocked row is only touchable by its blocker (deviations 2 + 3).
CREATE POLICY "friendships_update_involved"
    ON public.friendships FOR UPDATE
    TO authenticated
    USING (
        auth.uid() IN (requester_id, addressee_id)
        AND (status <> 'blocked' OR blocked_by = auth.uid())
    )
    WITH CHECK (
        (status = 'accepted' AND auth.uid() = addressee_id)
        OR (status = 'blocked' AND blocked_by = auth.uid())
    );

-- Decline / cancel / unfriend / unblock are all DELETEs by an involved side;
-- a blocked row is only deletable by its blocker (deviation 2).
CREATE POLICY "friendships_delete_involved"
    ON public.friendships FOR DELETE
    TO authenticated
    USING (
        auth.uid() IN (requester_id, addressee_id)
        AND (status <> 'blocked' OR blocked_by = auth.uid())
    );

-- Lock the pair columns on UPDATE (deviation 4).
CREATE OR REPLACE FUNCTION public.friendships_lock_pair()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NEW.requester_id <> OLD.requester_id
       OR NEW.addressee_id <> OLD.addressee_id THEN
        RAISE EXCEPTION 'friendship pair is immutable';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_friendships_lock_pair ON public.friendships;
CREATE TRIGGER trg_friendships_lock_pair
    BEFORE UPDATE ON public.friendships
    FOR EACH ROW EXECUTE FUNCTION public.friendships_lock_pair();

-- ── user_reports: insert-only abuse reports, reviewed manually ──────────────
CREATE TABLE IF NOT EXISTS public.user_reports (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    reported_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    reason      text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_reports_no_self CHECK (reporter_id <> reported_id)
);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Insert-only: no SELECT/UPDATE/DELETE policies — review happens with the
-- service role in the dashboard.
CREATE POLICY "user_reports_insert_own"
    ON public.user_reports FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = reporter_id);

-- ── @username on user_profiles: unique handle, the only lookup key ──────────
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS username text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'user_profiles_username_format'
    ) THEN
        -- Lowercase a-z, digits, underscore; 3–20 chars (PRD §5.6).
        ALTER TABLE public.user_profiles
            ADD CONSTRAINT user_profiles_username_format
            CHECK (username IS NULL OR username ~ '^[a-z0-9_]{3,20}$');
    END IF;
END $$;

-- Soft-deleted accounts release their handle.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_user_profiles_username
    ON public.user_profiles (username)
    WHERE username IS NOT NULL AND deleted_at IS NULL;

-- ── friends view: both directions of accepted rows ──────────────────────────
-- Same (user_id, friend_id) contract 008's leaderboard_friends reads.
-- Security-definer on purpose (like 006): exposes only id pairs.
CREATE OR REPLACE VIEW public.friends AS
SELECT requester_id AS user_id,
       addressee_id AS friend_id
FROM public.friendships
WHERE status = 'accepted'
UNION ALL
SELECT addressee_id AS user_id,
       requester_id AS friend_id
FROM public.friendships
WHERE status = 'accepted';

GRANT SELECT ON public.friends TO authenticated;

-- ── public_profiles: + username + friend_count, − follower/following ────────
-- DROP + CREATE because REPLACE can't remove columns (deviation 5). Still the
-- column-level privacy boundary: only public-safe fields leave this view.
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT
    p.user_id,
    p.display_name,
    p.username,
    p.avatar_url,
    p.experience,
    p.created_at,
    (SELECT count(*) FROM public.friends fr WHERE fr.user_id = p.user_id) AS friend_count
FROM public.user_profiles p
WHERE p.deleted_at IS NULL;

GRANT SELECT ON public.public_profiles TO authenticated;

-- ── bros can read each other's sessions ─────────────────────────────────────
-- Groundwork for the "Latest from your bros" activity strip (PRD §5.6): the
-- strip renders friends' workout summaries from their already-synced sessions
-- rows. Additive SELECT policy — owner CRUD from 001 is untouched, and only
-- accepted friendships (never pending/blocked) open the read.
CREATE POLICY "sessions_select_friends"
    ON public.sessions FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE f.status = 'accepted'
              AND ((f.requester_id = auth.uid() AND f.addressee_id = user_id)
                OR (f.addressee_id = auth.uid() AND f.requester_id = user_id))
        )
    );

-- ── follows: superseded by friendships — drop (03-DATABASE.md §3.1) ─────────
-- Plain DROP (no CASCADE): if anything still depends on it, fail loudly here.
DROP TABLE IF EXISTS public.follows;
