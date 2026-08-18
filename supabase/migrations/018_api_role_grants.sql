-- ─────────────────────────────────────────────────────────────────────────────
-- 018 — Table-level grants for the API roles (empirically confirmed 2026-08-18)
--
-- Projects/stacks created after Supabase's 2026-05-30 default flip no longer
-- auto-grant table privileges to the Data API roles. On a fresh environment
-- every table created by 001–015 has NO SELECT/INSERT/UPDATE/DELETE for
-- `authenticated` OR `service_role` — RLS policies alone don't open the
-- table gate. Confirmed against a fresh local stack: challenge joins,
-- friendship requests and profile PATCHes 403'd, and the RevenueCat webhook
-- 500'd on "permission denied for table subscriptions" (service_role!).
-- The existing cloud project predates the flip (classic grants), so this
-- migration is a no-op there — but it is REQUIRED for any fresh project,
-- preview branch, or local stack. 016/017 already carry their own grants;
-- they're repeated here so this file is the single audit list.
--
-- Principles:
--   • service_role gets ALL (it bypasses RLS by design — the classic
--     Supabase posture; edge functions and triggers rely on it), including
--     future tables via default privileges.
--   • authenticated gets exactly the DML surface its RLS policies allow —
--     the policies stay the row gate, these grants open the table gate.
--   • user_profiles keeps 009/016's column-scoped INSERT/UPDATE lockdown:
--     table-level SELECT only here — a blanket UPDATE grant would reopen
--     the subscription-column paywall bypass 009 closed.
--   • anon gets nothing (the app is authenticated-only; sign-in goes
--     through the auth schema, never these tables).
-- ─────────────────────────────────────────────────────────────────────────────

-- ── service_role: everything, now and for future tables ──────────────────────
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO service_role;

-- ── authenticated: per-table, mirroring the RLS policy surface ───────────────
-- Workout + schedule data (001 policies: own-row CRUD).
GRANT SELECT, INSERT, UPDATE, DELETE ON public.schedules            TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.schedule_days        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.scheduled_exercises  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sessions             TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.session_exercises    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sets                 TO authenticated;

-- Profile: SELECT at table level only — INSERT/UPDATE stay column-scoped
-- (009 base columns + 012 username + 016 active_skin_id). No client DELETE
-- (account deletion is the service-role delete_account_data path).
GRANT SELECT ON public.user_profiles TO authenticated;

-- Billing: read own subscription state (001 policy); writes are the
-- RevenueCat webhook / verify-subscription, service-role only.
GRANT SELECT ON public.subscriptions TO authenticated;

-- Social graph (012): decline/cancel/unfriend are contract hard-DELETEs.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.friendships TO authenticated;
-- Abuse reports (012): write-only for clients.
GRANT INSERT ON public.user_reports TO authenticated;

-- Challenges (014): create/read/take-down own; participation CRUD;
-- reports write-only. challenge_templates stays deny-all (server pool).
GRANT SELECT, INSERT, DELETE          ON public.challenges            TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE  ON public.challenge_participants TO authenticated;
GRANT INSERT                          ON public.challenge_reports      TO authenticated;

-- Leaderboard + seasons (008/015): read-only; writes are server-side.
GRANT SELECT ON public.leaderboard_scores TO authenticated;
GRANT SELECT ON public.season_results     TO authenticated;
GRANT SELECT ON public.rival_pods         TO authenticated;
GRANT SELECT ON public.rival_pod_members  TO authenticated;

-- Notification templates (001): read-only.
GRANT SELECT ON public.notification_templates TO authenticated;

-- Skins + reports (016/017 already grant these; repeated for the audit).
GRANT SELECT ON public.skins            TO authenticated;
GRANT SELECT ON public.skin_ownership   TO authenticated;
GRANT SELECT ON public.progress_reports TO authenticated;

-- Views (012/016 already grant these; repeated for the audit).
GRANT SELECT ON public.friends         TO authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;
