-- ─────────────────────────────────────────────────────────────────────────────
-- 011: pre-launch checklist fixes (2026-07-10 deploy-readiness audit)
--   1. Index the hourly leaderboard volume scan: compute_leaderboard_scores
--      (008:78-98) filters sets by completed_at/is_warmup/deleted_at and groups
--      by user_id — sets is the largest table and only had an index on
--      session_exercise_id.
--   2. Index post_comments(post_id): per-post comment fetches were seq scans
--      (post_likes is already covered by its UNIQUE(post_id, user_id)).
--   3. Pin search_path on the two remaining SECURITY DEFINER functions
--      (has_active_subscription is the paywall gate). Both bodies reference
--      public.* / pg_catalog only, so pinning is behavior-preserving.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_sets_user_completed
    ON public.sets (user_id, completed_at)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_post_comments_post
    ON public.post_comments (post_id);

ALTER FUNCTION public.has_active_subscription(UUID) SET search_path = public;
ALTER FUNCTION public.handle_new_user() SET search_path = public;
