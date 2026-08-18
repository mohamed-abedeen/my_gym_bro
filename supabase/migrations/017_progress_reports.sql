-- ─────────────────────────────────────────────────────────────────────────────
-- 017 — Periodic progress reports (PRD §5.17, 03-DATABASE §3.5, 04-BACKEND §3.6)
--
-- ⚠ Naming deviation from 03-DATABASE §3.5: the planned table name
-- `user_reports` was already taken by 012's abuse-report table (block+report
-- flow), so periodic reports live in `progress_reports`. The plan doc carries
-- a matching correction.
--
-- Generation is SQL + pg_cron (the 014/015/016 precedent — no edge function):
--   • weekly  — Wednesday 00:15 UTC, for the ISO week that ended Monday
--   • monthly — the 3rd 00:15 UTC, for the calendar month that just ended
-- The 48 h lag after each boundary mirrors 015's finalize_season rationale:
-- this is an offline-first app, and a final-day workout that syncs Monday
-- morning must still count. The window math is date_trunc-derived and
-- day-of-run independent, so the lag changes nothing but the run time.
-- Each run computes per-user `metrics` for the closed period and `deltas`
-- (current − previous period, same keys), inserts idempotently on
-- (user_id, period_type, period_start), and pushes "report ready"
-- (tone-resolved by send-push-notification, kind: report_ready) only for
-- genuinely-new rows — re-runs can't double-push.
--
-- Metrics are limited to what synced data can honestly answer server-side:
-- volume_kg, sets, sessions, training_days, pr_count (exercises whose
-- in-period max weight beats their prior all-time max), challenge_points.
-- `streak` and `muscle_balance` from the plan are deliberately absent: streak
-- has no server-side parity with the locked computeStreak semantics, and the
-- exercise→muscle mapping lives only in the client catalogue. The client can
-- render both locally if a future report screen wants them. Period
-- boundaries are UTC (sessions bucket by server `started_at`), so a
-- around-midnight local workout can land one period off vs the client's
-- local-time stats — inherent to server-side generation, accepted.
--
-- NOT YET DEPLOYED — rides the first `supabase db push` (SETUP-STATUS).
-- TODO(deploy): Vault secrets `project_url` + `cron_secret` (010 header) for
-- the pushes; absent Vault degrades to no-push, never fails the run.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── progress_reports ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.progress_reports (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    period_type  text NOT NULL CHECK (period_type IN ('weekly', 'monthly')),
    period_start date NOT NULL,
    period_end   date NOT NULL,
    metrics      jsonb NOT NULL,
    deltas       jsonb NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, period_type, period_start)
);

-- The Reports window's list query (newest first per type).
CREATE INDEX IF NOT EXISTS idx_progress_reports_user_type_start
    ON public.progress_reports (user_id, period_type, period_start DESC);

ALTER TABLE public.progress_reports ENABLE ROW LEVEL SECURITY;

-- Owner-read; all writes are server-side (the generator is SECURITY DEFINER,
-- cron runs as postgres). Same explicit-GRANT posture as 016.
DROP POLICY IF EXISTS "progress_reports_select_own" ON public.progress_reports;
CREATE POLICY "progress_reports_select_own"
    ON public.progress_reports FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

GRANT SELECT ON public.progress_reports TO authenticated;

-- ── metrics for one user over [p_from, p_to) ─────────────────────────────────
-- Semantics mirror the client's own numbers: finished, non-deleted sessions;
-- sets with both weight and reps. No plausibility caps — the report shows the
-- user their own data, not a competitive board.
CREATE OR REPLACE FUNCTION public.progress_report_metrics(
    p_user uuid,
    p_from timestamptz,
    p_to   timestamptz
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH sess AS (
        SELECT id, started_at
        FROM sessions
        WHERE user_id = p_user
          AND finished_at IS NOT NULL AND deleted_at IS NULL
          AND started_at >= p_from AND started_at < p_to
    ),
    set_rows AS (
        SELECT st.weight_kg, st.reps
        FROM sess s
        JOIN session_exercises se
          ON se.session_id = s.id AND se.deleted_at IS NULL
        JOIN sets st
          ON st.session_exercise_id = se.id AND st.deleted_at IS NULL
        WHERE st.weight_kg IS NOT NULL AND st.reps IS NOT NULL
    )
    SELECT jsonb_build_object(
        'volume_kg',
            COALESCE((SELECT round(SUM(weight_kg * reps)::numeric, 1)
                      FROM set_rows), 0),
        'sets', (SELECT COUNT(*) FROM set_rows),
        'sessions', (SELECT COUNT(*) FROM sess),
        'training_days',
            (SELECT COUNT(DISTINCT date_trunc('day', started_at)) FROM sess),
        'pr_count', (
            -- Exercises whose best set weight inside the window beats their
            -- best from ALL prior history (first-ever exercises don't count
            -- — a debut isn't a PR).
            SELECT COUNT(*)
            FROM (
                SELECT
                    MAX(st.weight_kg)
                        FILTER (WHERE s2.started_at >= p_from) AS in_window,
                    MAX(st.weight_kg)
                        FILTER (WHERE s2.started_at < p_from) AS prior
                FROM sessions s2
                JOIN session_exercises se
                  ON se.session_id = s2.id AND se.deleted_at IS NULL
                JOIN sets st
                  ON st.session_exercise_id = se.id AND st.deleted_at IS NULL
                WHERE s2.user_id = p_user
                  AND s2.finished_at IS NOT NULL AND s2.deleted_at IS NULL
                  AND s2.started_at < p_to
                  AND st.weight_kg IS NOT NULL
                GROUP BY se.exercise_id
            ) x
            WHERE x.in_window IS NOT NULL
              AND x.prior IS NOT NULL
              AND x.in_window > x.prior
        ),
        'challenge_points',
            COALESCE((SELECT SUM(points_awarded)
                      FROM challenge_participants
                      WHERE user_id = p_user
                        AND completed_at >= p_from
                        AND completed_at < p_to), 0)
    )
$$;

REVOKE ALL ON FUNCTION public.progress_report_metrics(uuid, timestamptz, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.progress_report_metrics(uuid, timestamptz, timestamptz) FROM anon, authenticated;

-- ── the generator ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.generate_progress_reports(p_period text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    cur_start  timestamptz;
    cur_end    timestamptz;
    prev_start timestamptz;
    created    integer := 0;
    inserted   integer;
    u          RECORD;
    cur_m      jsonb;
    prev_m     jsonb;
    delta_m    jsonb;
BEGIN
    IF p_period = 'weekly' THEN
        cur_end    := date_trunc('week', now());   -- most recent Monday 00:00 UTC
        cur_start  := cur_end - interval '7 days';
        prev_start := cur_start - interval '7 days';
    ELSIF p_period = 'monthly' THEN
        cur_end    := date_trunc('month', now());  -- most recent 1st 00:00 UTC
        cur_start  := cur_end - interval '1 month';
        prev_start := cur_start - interval '1 month';
    ELSE
        RAISE EXCEPTION 'generate_progress_reports: unknown period %', p_period;
    END IF;

    -- Only subscribers who actually trained in the closed period (§3.6:
    -- skip users with no sessions in the window).
    FOR u IN
        SELECT DISTINCT s.user_id
        FROM sessions s
        WHERE s.finished_at IS NOT NULL AND s.deleted_at IS NULL
          AND s.started_at >= cur_start AND s.started_at < cur_end
          AND has_active_subscription(s.user_id)
    LOOP
        cur_m  := progress_report_metrics(u.user_id, cur_start, cur_end);
        prev_m := progress_report_metrics(u.user_id, prev_start, cur_start);

        -- Same keys as metrics; value = current − previous (▲/▼ client-side).
        SELECT jsonb_object_agg(
                   k,
                   to_jsonb(
                       COALESCE((cur_m ->> k)::numeric, 0)
                       - COALESCE((prev_m ->> k)::numeric, 0)
                   )
               )
        INTO delta_m
        FROM jsonb_object_keys(cur_m) AS k;

        INSERT INTO progress_reports
            (user_id, period_type, period_start, period_end, metrics, deltas)
        VALUES (
            u.user_id,
            p_period,
            cur_start::date,
            (cur_end - interval '1 day')::date,  -- inclusive last day
            cur_m,
            delta_m
        )
        ON CONFLICT (user_id, period_type, period_start) DO NOTHING;
        GET DIAGNOSTICS inserted = ROW_COUNT;

        IF inserted > 0 THEN
            created := created + 1;
            -- Tone-resolved "report ready" push — best-effort, never fails
            -- the run (014/015/016 idiom).
            BEGIN
                PERFORM net.http_post(
                    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
                           || '/functions/v1/send-push-notification',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
                    ),
                    body := jsonb_build_object(
                        'user_ids', jsonb_build_array(u.user_id),
                        'kind', 'report_ready',
                        'period', p_period
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END LOOP;

    RETURN created;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_progress_reports(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.generate_progress_reports(text) FROM anon, authenticated;

-- ── schedules ────────────────────────────────────────────────────────────────
-- 48 h after each period boundary (015's finalize_season precedent) so
-- offline late-syncs still count: weekly on Wednesday for the week that
-- ended Monday, monthly on the 3rd. Same day as finalize-season (00:02) —
-- reports run at 00:15, before the 00:20 skins evaluation.
SELECT cron.unschedule('generate-reports-weekly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'generate-reports-weekly');

SELECT cron.schedule(
    'generate-reports-weekly',
    '15 0 * * 3',
    $$ SELECT public.generate_progress_reports('weekly'); $$
);

SELECT cron.unschedule('generate-reports-monthly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'generate-reports-monthly');

SELECT cron.schedule(
    'generate-reports-monthly',
    '15 0 3 * *',
    $$ SELECT public.generate_progress_reports('monthly'); $$
);

-- ── delete_account_data: + progress_reports (013/014/016 contract) ───────────
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
    -- Challenges: participation + reports first, then authored challenges
    -- (cascades their participants/reports).
    DELETE FROM challenge_participants WHERE user_id = target;
    DELETE FROM challenge_reports      WHERE reporter_id = target;
    DELETE FROM challenges             WHERE creator_id = target AND source = 'community';
    -- Social graph (friendships replaced follows in 012), reports either way.
    DELETE FROM friendships  WHERE requester_id = target OR addressee_id = target;
    DELETE FROM user_reports WHERE reporter_id = target OR reported_id = target;
    -- Cosmetics + progress snapshots.
    DELETE FROM skin_ownership   WHERE user_id = target;
    DELETE FROM progress_reports WHERE user_id = target;
    -- Billing, leaderboard, profile.
    DELETE FROM subscriptions      WHERE user_id = target;
    DELETE FROM leaderboard_scores WHERE user_id = target;
    DELETE FROM user_profiles      WHERE user_id = target;
END;
$$;
