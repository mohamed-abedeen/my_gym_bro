-- ─────────────────────────────────────────────────────────────────────────────
-- 007 — Auto-create profiles on signup + trial-aware subscription gate
--
-- Two foundational fixes for the social features:
--   1. Every new auth user gets a public.user_profiles row automatically, with
--      a 7-day trial window. Without this, real users had NO server-side
--      profile (the app only wrote the local Drift copy), so public_profiles
--      was empty and the community feed had no author data.
--   2. has_active_subscription() now also honours the trial window recorded on
--      user_profiles. Previously it only checked the `subscriptions` table
--      (written solely by the RevenueCat webhook), so trial users — who get
--      full access per the product model — were wrongly locked out of the
--      subscriber-gated feed.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Auto-create a profile (with trial) when an auth user is created ─────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (
        user_id,
        display_name,
        trial_started_at,
        subscription_status,
        subscription_expires_at
    )
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data ->> 'display_name',
            NEW.raw_user_meta_data ->> 'full_name',
            NEW.raw_user_meta_data ->> 'name',
            split_part(NEW.email, '@', 1)
        ),
        now(),
        'trial',
        now() + interval '7 days'
    )
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- user_profiles.user_id had no uniqueness guarantee; ON CONFLICT (user_id)
-- needs one, and conceptually there is one profile per user anyway.
CREATE UNIQUE INDEX IF NOT EXISTS user_profiles_user_id_key
    ON public.user_profiles (user_id);

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── Trial-aware subscription gate ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION has_active_subscription(check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        -- Paid / webhook-backed subscription.
        SELECT 1 FROM subscriptions
        WHERE user_id = check_user_id
          AND (
              status = 'active'
              OR (status = 'trial' AND expiration_date > now())
          )
          AND deleted_at IS NULL
    ) OR EXISTS (
        -- Trial (or active) recorded on the profile itself.
        SELECT 1 FROM user_profiles
        WHERE user_id = check_user_id
          AND deleted_at IS NULL
          AND (
              subscription_status = 'active'
              OR (
                  subscription_status = 'trial'
                  AND subscription_expires_at IS NOT NULL
                  AND subscription_expires_at > now()
              )
          )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
