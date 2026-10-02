-- ─────────────────────────────────────────────────────────────────────────────
-- 023 — Let users claim their @username
--
-- 012 added user_profiles.username (format CHECK + partial unique index) for
-- Bros invite links and exact @search. But 009 had already revoked blanket
-- UPDATE / INSERT on user_profiles and grants columns back one at a time
-- (016: active_skin_id, 021: the onboarding answers), and username was never
-- granted. So every claim was refused, and invite links / @search could never
-- resolve. (The client also filtered on `id` instead of `user_id`; fixed in
-- friend_repository.dart alongside this.)
--
-- Own-row RLS from 001 still limits the update to the caller's row, the
-- 012 CHECK enforces the format, and the unique index settles races (23505).
-- ─────────────────────────────────────────────────────────────────────────────

GRANT UPDATE (username) ON public.user_profiles TO authenticated;
GRANT INSERT (username) ON public.user_profiles TO authenticated;
