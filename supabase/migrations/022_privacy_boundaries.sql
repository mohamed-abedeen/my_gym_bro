-- ─────────────────────────────────────────────────────────────────────────────
-- 022 — Privacy boundaries: the public views + what Bros see of your sessions
--
-- The 2026-09-30 privacy audit checked the backend against the privacy policy
-- (website/public/privacy.html §7, "What other users can see") and found these
-- in the cloud project. It predates Supabase's 2026-05-30 default-grant flip,
-- so its classic default privileges hand `anon` AND `authenticated` ALL on
-- every relation postgres creates (both views: ACL `arwdDxtm`). 018 only ever
-- GRANTs, so its "anon gets nothing" held on fresh stacks, never in the cloud.
-- The views are owned by postgres (BYPASSRLS, no FORCE RLS), so they skip
-- their base tables' RLS:
--
--   1. anon (its key ships inside the app) could SELECT `public_profiles`,
--      i.e. every user's id, display name, @username, avatar, experience,
--      join date, skin and Bro count, plus `friends`, every accepted pair,
--      all without signing in. §7 shows profiles to signed-in users only.
--   2. `public_profiles` is auto-updatable (one base table, no top-level
--      aggregate) and the same ALL grant includes INSERT/UPDATE/DELETE: anon
--      and every signed-in user could rewrite or delete ANY user_profiles row
--      through it, running as the view owner, i.e. past the own-row RLS and
--      009's column lockdown. (`friends` is a UNION, so not updatable.)
--   3. `friends` let every signed-in user list anyone's Bros. §7 makes only
--      the Bro COUNT public.
--   4. `sessions_select_friends` (012) gave accepted Bros every column of each
--      other's sessions (free-text `notes` included) and soft-deleted rows.
--      §7: Bros see when you trained, for how long and your total volume.
--
-- Fixes:
--   • public_profiles stays a SECURITY DEFINER view on purpose. user_profiles
--     RLS is own-row only, so security_invoker would shrink it to the caller's
--     own row (breaks @username lookup and every Bro profile). It remains the
--     column-level boundary; Supabase's advisor keeps flagging it
--     (security_definer_view), which is expected. friend_count now counts
--     friendships directly: an invoker view nested in a definer view is still
--     checked as the CALLER, so reading the now-invoker `friends` would cap
--     everyone else's count at 0 or 1.
--   • friends → security_invoker: friendships_select_involved limits it to
--     the caller's own edges. Its privileged readers are unaffected: the
--     leaderboard RPCs (008/015) run as postgres and notify-social-challenge
--     uses the service role, both BYPASSRLS.
--   • Both views: ALL revoked from anon, authenticated and PUBLIC, then SELECT
--     granted back to authenticated only. service_role keeps 018's ALL.
--   • sessions_select_friends is dropped. Bros read `friend_sessions` instead:
--     user_id + the four §7 columns, non-deleted sessions, accepted pairs only
--     (pending/blocked never). A security_barrier definer view, SELECT-only:
--     it's auto-updatable too, so a write grant would let a Bro edit your
--     sessions, and the classic defaults grant ALL at creation, hence the
--     explicit REVOKE.
--
-- Idempotent (replace / IF EXISTS / grants): safe to re-run.
-- supabase/tests/local_integration.sh re-applies it over classic grants.
--
-- NOT YET DEPLOYED — rides the next `supabase db push` (SETUP-STATUS).
-- TODO(deploy): verify in the cloud that anon is gone and authenticated is
-- read-only on all three views, and that friends has security_invoker=true:
--   SELECT relname, relacl, reloptions FROM pg_class
--   WHERE relname IN ('public_profiles', 'friends', 'friend_sessions');
-- ─────────────────────────────────────────────────────────────────────────────

-- ── public_profiles: same columns, friend_count off the `friends` view ───────
-- Same column list/order/types as 016, so REPLACE works (no DROP, and the
-- leaderboard RPCs keep resolving it).
CREATE OR REPLACE VIEW public.public_profiles
WITH (security_invoker = false)
AS
SELECT
    p.user_id,
    p.display_name,
    p.username,
    p.avatar_url,
    p.experience,
    p.created_at,
    p.active_skin_id,
    (SELECT count(*)
     FROM public.friendships f
     WHERE f.status = 'accepted'
       AND p.user_id IN (f.requester_id, f.addressee_id)) AS friend_count
FROM public.user_profiles p
WHERE p.deleted_at IS NULL;

REVOKE ALL ON public.public_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;

-- ── friends: only the caller's own edges ─────────────────────────────────────
ALTER VIEW public.friends SET (security_invoker = true);

REVOKE ALL ON public.friends FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.friends TO authenticated;

-- ── Bros' session reads: four columns, live rows, accepted pairs ────────────
-- Replaces 012's table policy (which exposed every column). The owner's own
-- CRUD policies from 001 are untouched.
DROP POLICY IF EXISTS "sessions_select_friends" ON public.sessions;

-- security_barrier: the WHERE clause is the access gate, so caller-supplied
-- filters that aren't leakproof must never run on rows it rejects.
CREATE OR REPLACE VIEW public.friend_sessions
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
    s.user_id,
    s.started_at,
    s.finished_at,
    s.duration_seconds,
    s.total_volume_kg
FROM public.sessions s
WHERE s.deleted_at IS NULL
  AND s.user_id IN (
      SELECT f.addressee_id FROM public.friendships f
      WHERE f.status = 'accepted' AND f.requester_id = auth.uid()
      UNION ALL
      SELECT f.requester_id FROM public.friendships f
      WHERE f.status = 'accepted' AND f.addressee_id = auth.uid()
  );

REVOKE ALL ON public.friend_sessions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.friend_sessions TO authenticated;
