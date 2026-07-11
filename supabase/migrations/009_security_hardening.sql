-- ─────────────────────────────────────────────────────────────────────────────
-- 009 — Security hardening
--   D/S2  Paywall data bypass: user_profiles.subscription_status/trial columns
--         were client-writable (RLS allowed own-row UPDATE of ANY column), so a
--         user could PATCH themselves to 'active' via PostgREST and get premium
--         forever. Lock those columns with a column-level GRANT.
--   I     has_active_subscription() didn't treat 'grace_period' as active, so a
--         billing-retry user lost access immediately. Include it.
--   C     Delete Account didn't delete: public.* FKs to auth.users have no
--         ON DELETE CASCADE, so auth.admin.deleteUser() failed and the account +
--         PII persisted. Add a transactional hard-delete the function calls
--         before removing the auth user.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── D/S2 — lock the subscription/trial columns to server writers only ────────
-- REVOKE all column UPDATEs from clients, then GRANT back only the safe,
-- user-editable columns. subscription_status, subscription_expires_at and
-- trial_started_at are intentionally excluded — only the RevenueCat webhook /
-- verify-subscription (service role) and the signup trigger (SECURITY DEFINER)
-- may set them, and neither is affected by role-level grants.
REVOKE UPDATE ON public.user_profiles FROM authenticated;
GRANT  UPDATE (
    display_name,
    avatar_url,
    goal,
    experience,
    weight_unit,
    preferred_language,
    default_rest_seconds,
    fcm_token,
    notification_tone,
    updated_at
) ON public.user_profiles TO authenticated;

-- INSERT is owned by the handle_new_user() trigger (007); a client can't create
-- a second profile (unique user_id). Belt-and-suspenders: block the client from
-- INSERTing a pre-activated row on the off chance the trigger didn't run.
REVOKE INSERT ON public.user_profiles FROM authenticated;
GRANT  INSERT (
    user_id,
    display_name,
    avatar_url,
    goal,
    experience,
    weight_unit,
    preferred_language,
    default_rest_seconds,
    fcm_token,
    notification_tone
) ON public.user_profiles TO authenticated;

-- ── I — grace_period counts as active ───────────────────────────────────────
CREATE OR REPLACE FUNCTION has_active_subscription(check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM subscriptions
        WHERE user_id = check_user_id
          AND (
              status IN ('active', 'grace_period')
              OR (status = 'trial' AND expiration_date > now())
          )
          AND deleted_at IS NULL
    ) OR EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = check_user_id
          AND deleted_at IS NULL
          AND (
              subscription_status IN ('active', 'grace_period')
              OR (
                  subscription_status = 'trial'
                  AND subscription_expires_at IS NOT NULL
                  AND subscription_expires_at > now()
              )
          )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── C — transactional account deletion ───────────────────────────────────────
-- Hard-deletes every row the user owns (plus engagement on their posts) in
-- FK-safe order, in one transaction. The delete-account edge function calls this
-- with the service role, then auth.admin.deleteUser() to remove the auth row
-- (follows + leaderboard_scores already ON DELETE CASCADE, so they're covered
-- either way).
CREATE OR REPLACE FUNCTION public.delete_account_data(target uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Engagement on the user's posts, authored by anyone.
    DELETE FROM post_likes    WHERE post_id IN (SELECT id FROM posts WHERE user_id = target);
    DELETE FROM post_comments WHERE post_id IN (SELECT id FROM posts WHERE user_id = target);
    -- The user's own engagement on any post.
    DELETE FROM post_likes    WHERE user_id = target;
    DELETE FROM post_comments WHERE user_id = target;
    DELETE FROM posts         WHERE user_id = target;
    -- Workout data (children first).
    DELETE FROM sets              WHERE user_id = target;
    DELETE FROM session_exercises WHERE user_id = target;
    DELETE FROM sessions          WHERE user_id = target;
    -- Schedule data (children first).
    DELETE FROM scheduled_exercises WHERE user_id = target;
    DELETE FROM schedule_days        WHERE user_id = target;
    DELETE FROM schedules            WHERE user_id = target;
    -- Social graph, billing, leaderboard, profile.
    DELETE FROM follows            WHERE follower_id = target OR followee_id = target;
    DELETE FROM subscriptions      WHERE user_id = target;
    DELETE FROM leaderboard_scores WHERE user_id = target;
    DELETE FROM user_profiles      WHERE user_id = target;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_account_data(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_account_data(uuid) FROM anon, authenticated;
