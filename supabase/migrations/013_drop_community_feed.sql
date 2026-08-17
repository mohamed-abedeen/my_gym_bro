-- ─────────────────────────────────────────────────────────────────────────────
-- 013 — Drop the community feed (posts) + community-images storage; fix
--       delete_account_data for the post-follows, post-feed schema
--
-- The photo/text feed was cut from the product on 2026-08-15 (PRD §5.8): the
-- Bros activity strip replaces its engagement job with no free-text UGC. The
-- client feed UI was deleted in Bros Phase A; these tables have been dormant
-- since. Pre-launch, no user data at stake. (DM tables never existed server-
-- side — the client-only DM feature was removed in Drift v13 — so there is
-- nothing else to drop.)
--
-- ⚠ delete_account_data (009 §C) is rewritten here because it still hard-
-- deleted from posts/post_likes/post_comments AND from follows (dropped in
-- 012). Left as-is, the delete-account edge function would throw on the first
-- missing relation and ACCOUNT DELETION WOULD FAIL — an App Store blocker.
--
-- NOT YET DEPLOYED — runs with 012 on the first `supabase db push`
-- (SETUP-STATUS). TODO(deploy): after pushing, verify delete-account end to
-- end: auth user gone, friendships/user_reports rows gone, storage clean.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── community-images storage: objects, bucket, and its 4 policies ───────────
-- Objects must go before the bucket (FK). Policy names from 001 §7.
-- Storage API ≥ mid-2026 installs an event trigger that forbids direct DML on
-- storage tables (SQLSTATE 42501, "Use the Storage API instead"), which made
-- the bare DELETEs abort the whole migration on current stacks. Pre-launch
-- the bucket is empty, so skipping the cleanup is safe — the DO block deletes
-- where allowed and downgrades the refusal to a NOTICE. If a deployed project
-- ever has objects in this bucket, empty + delete it via the Storage API.
DO $$
BEGIN
    DELETE FROM storage.objects WHERE bucket_id = 'community-images';
    DELETE FROM storage.buckets WHERE id = 'community-images';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'community-images storage cleanup skipped: %', SQLERRM;
END $$;

DROP POLICY IF EXISTS "Users can upload community images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view community images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own community images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own community images" ON storage.objects;

-- ── feed tables: children first ──────────────────────────────────────────────
-- RLS policies, triggers, and indexes (incl. 011's idx_post_comments_post)
-- are dropped with their tables. Plain DROP (no CASCADE) so any forgotten
-- dependent object fails loudly here instead of vanishing silently.
DROP TABLE IF EXISTS public.post_comments;
DROP TABLE IF EXISTS public.post_likes;
DROP TABLE IF EXISTS public.posts;

-- ── delete_account_data: same contract, current schema ──────────────────────
-- Called by the delete-account edge function (service role) before
-- auth.admin.deleteUser(). The friendships/user_reports deletes are belt-and-
-- braces — their FKs are ON DELETE CASCADE off auth.users (012) — but doing
-- them here keeps the whole wipe inside one transaction.
CREATE OR REPLACE FUNCTION public.delete_account_data(target uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Workout data (children first).
    DELETE FROM sets              WHERE user_id = target;
    DELETE FROM session_exercises WHERE user_id = target;
    DELETE FROM sessions          WHERE user_id = target;
    -- Schedule data (children first).
    DELETE FROM scheduled_exercises WHERE user_id = target;
    DELETE FROM schedule_days        WHERE user_id = target;
    DELETE FROM schedules            WHERE user_id = target;
    -- Social graph (friendships replaced follows in 012), reports either way.
    DELETE FROM friendships  WHERE requester_id = target OR addressee_id = target;
    DELETE FROM user_reports WHERE reporter_id = target OR reported_id = target;
    -- Billing, leaderboard, profile.
    DELETE FROM subscriptions      WHERE user_id = target;
    DELETE FROM leaderboard_scores WHERE user_id = target;
    DELETE FROM user_profiles      WHERE user_id = target;
END;
$$;
