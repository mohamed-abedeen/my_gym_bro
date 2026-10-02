-- ─────────────────────────────────────────────────────────────────────────────
-- 021 — Onboarding v3 answers on the profile
--
-- The redesigned onboarding (design_handoff_onboarding v3) persists every
-- answer; Drift schema v22 mirrors these columns. The body metrics that were
-- local-only until now (gender, body weight, height) join them, so the whole
-- intake follows the account to a new device (auth_notifier pulls these on
-- the first sign-in).
--
-- Privacy: own-row RLS from 001 already covers every column, and the
-- public_profiles view (016) lists its columns explicitly — none of this
-- (health data included) is visible to other users.
--
-- Consent (GDPR Art. 9): weight, height, target weight, health issue,
-- injuries and rest days are health data. The app asks for explicit consent
-- first and records when it was given (`health_consent_at`); declining or
-- withdrawing (Settings) nulls them. The `user_profiles_health_needs_consent`
-- CHECK makes the server refuse health data without a consent timestamp.
--
-- Client wire values: lib/features/onboarding/onboarding_state.dart.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS gender text
        CHECK (gender IS NULL OR gender IN ('male', 'female')),
    ADD COLUMN IF NOT EXISTS body_weight_kg numeric(5, 1)
        CHECK (body_weight_kg IS NULL OR body_weight_kg BETWEEN 20 AND 400),
    ADD COLUMN IF NOT EXISTS height_cm numeric(5, 1)
        CHECK (height_cm IS NULL OR height_cm BETWEEN 50 AND 280),
    ADD COLUMN IF NOT EXISTS height_unit text NOT NULL DEFAULT 'cm'
        CHECK (height_unit IN ('cm', 'ft')),
    ADD COLUMN IF NOT EXISTS birth_date date
        CHECK (birth_date IS NULL OR birth_date >= DATE '1900-01-01'),
    ADD COLUMN IF NOT EXISTS target_weight_kg numeric(5, 1)
        CHECK (target_weight_kg IS NULL OR target_weight_kg BETWEEN 20 AND 400),
    ADD COLUMN IF NOT EXISTS focus_areas text[]
        CHECK (focus_areas IS NULL OR focus_areas <@ ARRAY[
            'back', 'chest', 'arms', 'abs', 'glutes', 'legs', 'full_body'
        ]),
    ADD COLUMN IF NOT EXISTS health_issue text
        CHECK (health_issue IS NULL OR health_issue IN (
            'prolonged_sitting', 'poor_sleep', 'diet', 'healthy'
        )),
    -- '{}' = answered "None"; NULL = never asked.
    ADD COLUMN IF NOT EXISTS injuries text[]
        CHECK (injuries IS NULL OR injuries <@ ARRAY[
            'shoulder', 'back', 'waist', 'wrist', 'knee'
        ]),
    ADD COLUMN IF NOT EXISTS injury_rest_days smallint
        CHECK (injury_rest_days IS NULL OR injury_rest_days BETWEEN 1 AND 14),
    -- ISO weekdays, Monday = 1.
    ADD COLUMN IF NOT EXISTS training_days smallint[]
        CHECK (training_days IS NULL OR training_days <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::smallint[]),
    ADD COLUMN IF NOT EXISTS health_consent_at timestamptz;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'user_profiles_health_needs_consent'
    ) THEN
        ALTER TABLE public.user_profiles
            ADD CONSTRAINT user_profiles_health_needs_consent CHECK (
                health_consent_at IS NOT NULL
                OR (
                    body_weight_kg IS NULL
                    AND height_cm IS NULL
                    AND target_weight_kg IS NULL
                    AND health_issue IS NULL
                    AND injuries IS NULL
                    AND injury_rest_days IS NULL
                )
            );
    END IF;
END $$;

-- 009 revoked blanket UPDATE/INSERT and granted back per column; grants are
-- additive, so extend them with just the new user-editable columns (the
-- subscription columns stay server-only).
GRANT UPDATE (
    gender,
    body_weight_kg,
    height_cm,
    height_unit,
    birth_date,
    target_weight_kg,
    focus_areas,
    health_issue,
    injuries,
    injury_rest_days,
    training_days,
    health_consent_at
) ON public.user_profiles TO authenticated;

GRANT INSERT (
    gender,
    body_weight_kg,
    height_cm,
    height_unit,
    birth_date,
    target_weight_kg,
    focus_areas,
    health_issue,
    injuries,
    injury_rest_days,
    training_days,
    health_consent_at
) ON public.user_profiles TO authenticated;
