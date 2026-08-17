-- ─────────────────────────────────────────────────────────────────────────────
-- 015 — Leaderboard seasons: final standings, winners, rival pods
--
-- Implements 04-BACKEND.md §3.1a/§3.1b and 06-IMPLEMENTATION Phase 5:
--   • score_board_window(win_start, win_end): the scoring engine from 008/014,
--     extracted and window-parameterized. compute_leaderboard_scores() now
--     delegates to it (live boards use an open end), and finalize_season()
--     scores the CLOSED window — necessary because by the time the boundary
--     cron runs, date_trunc has already rolled the live table into the new
--     season.
--   • season_results: full final standings per (board, season_start, user) —
--     one table serves global top-N, "you placed Nth", the Friends-scope
--     winner (join against the viewer's friends at read time), and Rivals
--     pod winners. Launch-scale row counts make a full snapshot the simple
--     correct choice.
--   • rival_pods / rival_pod_members + assign_rivals(): weekly pods of
--     ~POD_SIZE users ordered by newcomer-status, experience, all-time
--     composite, and 30-day volume (§3.1a). leaderboard_rivals() is
--     REPLACED (same signature → no client change) to rank the caller's
--     current pod, falling back to 008's rank-window behavior for users
--     without a pod (pre-first-assignment, or joined mid-week).
--   • Season boundaries are UTC (weekly = Monday 00:00, monthly = 1st
--     00:00), matching compute_leaderboard_scores. Finalize runs 48 h AFTER
--     the boundary (Wed / the 3rd) — 014 grants offline completions a 48 h
--     receipt window, and snapshotting at boundary+2min would erase exactly
--     the late-sync data that grace exists for. date_trunc makes the math
--     run-date-tolerant, so only the schedule differs from the boundary.
--   • Pod population = every non-deleted profile (deviation from §3.1a's
--     "active subscribers" — deliberate, matching 008's decision that the
--     scored population is everyone; a subscriber's pod thus mirrors the
--     people they see on the global board).
--   • Winner pushes: finalize_season fires best-effort pg_net calls to
--     send-push-notification for the top 3 global placements per board.
--   • Earned-skins/achievements feed (Phase 6) reads season_results.
--
-- NOT YET DEPLOYED — rides the same first `supabase db push` as 012–014
-- (SETUP-STATUS). Crons follow 010's Vault pattern; pushes degrade to no-op
-- while Vault secrets are absent.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── season_results: immutable final standings of closed seasons ──────────────
CREATE TABLE IF NOT EXISTS public.season_results (
    board        text NOT NULL CHECK (board IN ('weekly', 'monthly')),
    season_start timestamptz NOT NULL,
    user_id      uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    final_rank   integer NOT NULL,
    composite    double precision NOT NULL DEFAULT 0,
    volume_raw   double precision NOT NULL DEFAULT 0,
    finalized_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (board, season_start, user_id)
);

CREATE INDEX IF NOT EXISTS idx_season_results_board_rank
    ON public.season_results (board, season_start, final_rank);

ALTER TABLE public.season_results ENABLE ROW LEVEL SECURITY;

-- Read-only for subscribers (winner banners, placement history); writes are
-- service-side only (finalize_season is SECURITY DEFINER).
DROP POLICY IF EXISTS "season_results_select_subscribers" ON public.season_results;
CREATE POLICY "season_results_select_subscribers"
    ON public.season_results FOR SELECT
    TO authenticated
    USING (has_active_subscription(auth.uid()));

-- ── rival pods (04-BACKEND §3.1a) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rival_pods (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    period_start date NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rival_pod_members (
    pod_id       uuid NOT NULL REFERENCES public.rival_pods (id) ON DELETE CASCADE,
    user_id      uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    period_start date NOT NULL,
    PRIMARY KEY (pod_id, user_id),
    -- Each user belongs to exactly one pod per period (idempotency anchor).
    UNIQUE (user_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_rival_pod_members_period
    ON public.rival_pod_members (period_start, pod_id);

ALTER TABLE public.rival_pods        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rival_pod_members ENABLE ROW LEVEL SECURITY;

-- The caller's pod ids, RLS-free. A policy on rival_pod_members cannot
-- sub-select rival_pod_members directly — Postgres applies RLS to policy
-- subqueries and detects infinite recursion (42P17). SECURITY DEFINER
-- helper is the standard workaround.
CREATE OR REPLACE FUNCTION public.my_rival_pod_ids()
RETURNS SETOF uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT m.pod_id FROM rival_pod_members m WHERE m.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.my_rival_pod_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_rival_pod_ids() TO authenticated;

-- A member can see their own pod's roster (the RPC is SECURITY DEFINER and
-- doesn't need these, but direct reads shouldn't leak other pods).
DROP POLICY IF EXISTS "rival_pods_select_member" ON public.rival_pods;
CREATE POLICY "rival_pods_select_member"
    ON public.rival_pods FOR SELECT
    TO authenticated
    USING (id IN (SELECT public.my_rival_pod_ids()));

DROP POLICY IF EXISTS "rival_pod_members_select_own_pod" ON public.rival_pod_members;
CREATE POLICY "rival_pod_members_select_own_pod"
    ON public.rival_pod_members FOR SELECT
    TO authenticated
    USING (pod_id IN (SELECT public.my_rival_pod_ids()));

-- ── score_board_window(): the scoring engine, window-parameterized ───────────
-- Body is 008's engine with the 014 points wiring, plus an explicit upper
-- bound on every aggregate so a closed season scores only its own window.
CREATE OR REPLACE FUNCTION public.score_board_window(
    win_start timestamptz,
    win_end   timestamptz
)
RETURNS TABLE (
    user_id     uuid,
    streak_raw  integer,
    volume_raw  double precision,
    points_raw  double precision,
    streak_norm double precision,
    volume_norm double precision,
    points_norm double precision,
    composite   double precision,
    board_rank  integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH plausible_sets AS (
        -- Anti-cheat: recompute volume from raw sets and drop anything
        -- outside hard plausibility caps (008). 500 kg exceeds every raw
        -- world record; 60 reps / 6000 kg·reps per set is beyond any real
        -- working set.
        SELECT s.user_id, s.weight_kg * s.reps AS vol
        FROM sets s
        WHERE s.deleted_at IS NULL
          AND s.completed_at IS NOT NULL
          AND s.completed_at >= win_start AND s.completed_at < win_end
          AND s.is_warmup = false
          AND s.weight_kg IS NOT NULL AND s.reps IS NOT NULL
          AND s.weight_kg > 0        AND s.weight_kg <= 500
          AND s.reps      > 0        AND s.reps      <= 60
          AND s.weight_kg * s.reps   <= 6000
    ),
    volumes AS (
        SELECT ps.user_id, sum(ps.vol) AS volume_raw
        FROM plausible_sets ps
        GROUP BY ps.user_id
    ),
    training_days AS (
        -- Distinct training days inside the window — the consistency
        -- component (lifetime count on the all_time board).
        SELECT se.user_id,
               count(DISTINCT date(se.started_at)) AS streak_raw
        FROM sessions se
        WHERE se.deleted_at IS NULL
          AND se.finished_at IS NOT NULL
          AND se.started_at >= win_start AND se.started_at < win_end
        GROUP BY se.user_id
    ),
    challenge_points AS (
        -- 014's anti-mint rules: hidden challenges never pay, creators
        -- never earn from their own challenges, community-sourced points
        -- cap at 100 per user per window.
        SELECT cp.user_id,
               (COALESCE(sum(cp.points_awarded)
                    FILTER (WHERE c.source = 'curated'), 0)
                + LEAST(COALESCE(sum(cp.points_awarded)
                    FILTER (WHERE c.source = 'community'), 0), 100)
               )::double precision AS points_raw
        FROM challenge_participants cp
        JOIN challenges c
          ON c.id = cp.challenge_id
         AND c.status <> 'hidden'
         AND c.creator_id IS DISTINCT FROM cp.user_id
        WHERE cp.completed_at IS NOT NULL
          AND cp.completed_at >= win_start AND cp.completed_at < win_end
        GROUP BY cp.user_id
    ),
    population AS (
        -- Every non-deleted profile: new users score 0 and sit at the
        -- bottom of the board rather than being hidden.
        SELECT p.user_id FROM user_profiles p WHERE p.deleted_at IS NULL
    ),
    raw AS (
        SELECT pop.user_id,
               COALESCE(t.streak_raw, 0)     AS streak_raw,
               COALESCE(v.volume_raw, 0.0)   AS volume_raw,
               COALESCE(cpt.points_raw, 0.0) AS points_raw
        FROM population pop
        LEFT JOIN training_days    t   USING (user_id)
        LEFT JOIN volumes          v   USING (user_id)
        LEFT JOIN challenge_points cpt USING (user_id)
    ),
    normed AS (
        -- Percentile-normalise each component to 0–100 so raw volume can't
        -- numerically dwarf the streak or points components.
        SELECT r.user_id, r.streak_raw, r.volume_raw, r.points_raw,
               percent_rank() OVER (ORDER BY r.streak_raw) * 100 AS streak_norm,
               percent_rank() OVER (ORDER BY r.volume_raw) * 100 AS volume_norm,
               percent_rank() OVER (ORDER BY r.points_raw) * 100 AS points_norm
        FROM raw r
    )
    SELECT n.user_id,
           n.streak_raw, n.volume_raw, n.points_raw,
           n.streak_norm, n.volume_norm, n.points_norm,
           (n.streak_norm + n.volume_norm + n.points_norm) / 3.0 AS composite,
           row_number() OVER (
               ORDER BY (n.streak_norm + n.volume_norm + n.points_norm) / 3.0 DESC,
                        n.volume_raw DESC,
                        n.user_id
           )::integer AS board_rank
    FROM normed n
$$;

REVOKE ALL ON FUNCTION public.score_board_window(timestamptz, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.score_board_window(timestamptz, timestamptz) FROM anon, authenticated;

-- ── compute_leaderboard_scores(): now a thin wrapper ─────────────────────────
CREATE OR REPLACE FUNCTION public.compute_leaderboard_scores()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    b         text;
    win_start timestamptz;
BEGIN
    FOREACH b IN ARRAY ARRAY['weekly', 'monthly', 'all_time'] LOOP
        -- Season windows are fixed to UTC boundaries so everyone resets
        -- together (weekly = Monday 00:00 UTC, monthly = 1st 00:00 UTC).
        win_start := CASE b
            WHEN 'weekly'  THEN date_trunc('week',  now() AT TIME ZONE 'utc')
            WHEN 'monthly' THEN date_trunc('month', now() AT TIME ZONE 'utc')
            ELSE '-infinity'::timestamptz
        END;

        DELETE FROM leaderboard_scores WHERE board = b;

        INSERT INTO leaderboard_scores (
            user_id, board,
            streak_raw, volume_raw, points_raw,
            streak_norm, volume_norm, points_norm,
            composite, global_rank, computed_at
        )
        SELECT s.user_id, b,
               s.streak_raw, s.volume_raw, s.points_raw,
               s.streak_norm, s.volume_norm, s.points_norm,
               s.composite, s.board_rank, now()
        FROM score_board_window(win_start, 'infinity'::timestamptz) s;
    END LOOP;
END;
$$;

-- ── finalize_season(board): snapshot the closed window at each boundary ──────
-- Weekly: runs Monday shortly after 00:00 UTC and scores [prev Mon, this Mon).
-- Monthly: runs on the 1st and scores the prior month. Idempotent: re-runs
-- insert nothing (PK conflict) and re-push nothing (guarded by inserted count).
CREATE OR REPLACE FUNCTION public.finalize_season(p_board text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    boundary   timestamptz;
    prev_start timestamptz;
    inserted   integer;
    w          record;
    n          integer := 0;
BEGIN
    IF p_board = 'weekly' THEN
        boundary   := date_trunc('week', now() AT TIME ZONE 'utc');
        prev_start := boundary - interval '7 days';
    ELSIF p_board = 'monthly' THEN
        boundary   := date_trunc('month', now() AT TIME ZONE 'utc');
        prev_start := date_trunc('month', boundary - interval '1 day');
    ELSE
        RAISE EXCEPTION 'finalize_season: unknown board %', p_board;
    END IF;

    INSERT INTO season_results
        (board, season_start, user_id, final_rank, composite, volume_raw)
    SELECT p_board, prev_start, s.user_id, s.board_rank, s.composite, s.volume_raw
    FROM score_board_window(prev_start, boundary) s
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS inserted = ROW_COUNT;

    -- Winner pushes (top 3 global) — only on the run that actually finalized,
    -- and always best-effort: absent pg_net/Vault must never fail the job.
    IF inserted > 0 THEN
        FOR w IN
            SELECT sr.user_id, sr.final_rank
            FROM season_results sr
            WHERE sr.board = p_board AND sr.season_start = prev_start
              AND sr.final_rank <= 3
            ORDER BY sr.final_rank
        LOOP
            BEGIN
                PERFORM net.http_post(
                    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
                           || '/functions/v1/send-push-notification',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
                    ),
                    body := jsonb_build_object(
                        'user_ids', jsonb_build_array(w.user_id),
                        'kind', 'season_ended',
                        'board', p_board,
                        'placement', w.final_rank
                    )
                );
                n := n + 1;
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END LOOP;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_season(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finalize_season(text) FROM anon, authenticated;

-- ── assign_rivals(): weekly pods of similar users (04-BACKEND §3.1a) ─────────
-- Ordering key: newcomers last (they form their own pods), then experience
-- bucket, then all-time composite, then 30-day volume — so each slice of
-- POD_SIZE users is a cohort of comparable level and progress. Idempotent
-- per period via the (user_id, period_start) unique key.
CREATE OR REPLACE FUNCTION public.assign_rivals()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    period      date := (date_trunc('week', now() AT TIME ZONE 'utc'))::date;
    pod_size    constant integer := 15;
    total       integer;
    pods_needed integer;
    i           integer;
    pod_ids     uuid[];
BEGIN
    -- Already assigned this period → nothing to do.
    IF EXISTS (SELECT 1 FROM rival_pod_members m WHERE m.period_start = period) THEN
        RETURN;
    END IF;

    CREATE TEMP TABLE tmp_rival_order ON COMMIT DROP AS
    SELECT p.user_id,
           row_number() OVER (
               ORDER BY
                   -- Newcomers (no scored data yet) cluster at the end.
                   (COALESCE(ls.volume_raw, 0) = 0 AND COALESCE(ls.streak_raw, 0) = 0),
                   CASE p.experience
                       WHEN 'advanced' THEN 0
                       WHEN 'intermediate' THEN 1
                       WHEN 'beginner' THEN 2
                       ELSE 3
                   END,
                   COALESCE(ls.composite, 0) DESC,
                   COALESCE(v30.vol, 0) DESC,
                   p.user_id
           ) - 1 AS rn
    FROM user_profiles p
    LEFT JOIN leaderboard_scores ls
      ON ls.user_id = p.user_id AND ls.board = 'all_time'
    LEFT JOIN (
        SELECT s.user_id, sum(s.weight_kg * s.reps) AS vol
        FROM sets s
        WHERE s.deleted_at IS NULL AND s.completed_at IS NOT NULL
          AND s.is_warmup = false
          AND s.weight_kg IS NOT NULL AND s.reps IS NOT NULL
          AND s.completed_at >= now() - interval '30 days'
        GROUP BY s.user_id
    ) v30 ON v30.user_id = p.user_id
    WHERE p.deleted_at IS NULL;

    SELECT count(*) INTO total FROM tmp_rival_order;
    IF total = 0 THEN
        RETURN;
    END IF;
    -- Floor, not ceil: the remainder folds into the last pod (15–29 members)
    -- instead of stranding 1–14 users — usually newcomers, who sort last —
    -- in a lonely micro-pod for the whole week.
    pods_needed := GREATEST(1, total / pod_size);

    pod_ids := ARRAY(
        SELECT gen_random_uuid() FROM generate_series(1, pods_needed)
    );
    FOR i IN 1..pods_needed LOOP
        INSERT INTO rival_pods (id, period_start) VALUES (pod_ids[i], period);
    END LOOP;

    INSERT INTO rival_pod_members (pod_id, user_id, period_start)
    SELECT pod_ids[LEAST((o.rn / pod_size) + 1, pods_needed)], o.user_id, period
    FROM tmp_rival_order o
    ON CONFLICT DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.assign_rivals() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_rivals() FROM anon, authenticated;

-- ── leaderboard_rivals(): pods replace the 008 rank-window (same shape) ──────
CREATE OR REPLACE FUNCTION public.leaderboard_rivals(
    p_board text DEFAULT 'weekly',
    p_window integer DEFAULT 5
)
RETURNS TABLE (
    user_id      uuid,
    display_name text,
    avatar_url   text,
    volume_raw   double precision,
    composite    double precision,
    rank         integer,
    is_me        boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH my_pod AS (
        -- Strictly the CURRENT period's pod: an unboundedly stale pod would
        -- desync the live board from leaderboard_last_winner (which resolves
        -- pods per season). No pod this period — assign-rivals missed, the
        -- 00:00–00:10 Monday gap, or a mid-week signup — uses the fallback.
        SELECT m.pod_id
        FROM rival_pod_members m
        WHERE m.user_id = auth.uid()
          AND m.period_start = (date_trunc('week', now() AT TIME ZONE 'utc'))::date
        LIMIT 1
    ),
    pod_rows AS (
        SELECT ls.user_id,
               pp.display_name,
               pp.avatar_url,
               ls.volume_raw,
               ls.composite,
               rank() OVER (ORDER BY ls.composite DESC)::integer AS rank,
               ls.user_id = auth.uid() AS is_me
        FROM rival_pod_members m
        JOIN my_pod mp ON mp.pod_id = m.pod_id
        JOIN leaderboard_scores ls ON ls.user_id = m.user_id AND ls.board = p_board
        LEFT JOIN public_profiles pp ON pp.user_id = ls.user_id
        WHERE has_active_subscription(auth.uid())
    ),
    -- Fallback (008 behavior): users without a pod — before the first
    -- assign_rivals run, or accounts created mid-week — still get a rivals
    -- view: the ±window of users adjacent in the global ordering.
    me AS (
        SELECT ls.global_rank
        FROM leaderboard_scores ls
        WHERE ls.board = p_board AND ls.user_id = auth.uid()
    ),
    window_rows AS (
        SELECT ls.user_id,
               pp.display_name,
               pp.avatar_url,
               ls.volume_raw,
               ls.composite,
               ls.global_rank AS rank,
               ls.user_id = auth.uid() AS is_me
        FROM leaderboard_scores ls
        LEFT JOIN public_profiles pp ON pp.user_id = ls.user_id
        CROSS JOIN me
        WHERE ls.board = p_board
          AND has_active_subscription(auth.uid())
          AND ls.global_rank BETWEEN me.global_rank - p_window
                                 AND me.global_rank + p_window
    )
    SELECT * FROM pod_rows
    UNION ALL
    SELECT * FROM window_rows
    WHERE NOT EXISTS (SELECT 1 FROM my_pod)
    ORDER BY rank;
$$;

GRANT EXECUTE ON FUNCTION public.leaderboard_rivals(text, integer) TO authenticated;

-- ── leaderboard_last_winner(): the banner query, per scope ───────────────────
-- Latest CLOSED season's winner for the caller's scope. Friends resolves
-- against the caller's mutual friends (+ self); rivals against the caller's
-- pod of that closed period; global is rank 1.
CREATE OR REPLACE FUNCTION public.leaderboard_last_winner(
    p_board text DEFAULT 'weekly',
    p_scope text DEFAULT 'global'
)
RETURNS TABLE (
    user_id      uuid,
    display_name text,
    avatar_url   text,
    composite    double precision,
    season_start timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH latest AS (
        SELECT max(sr.season_start) AS season_start
        FROM season_results sr
        WHERE sr.board = p_board
    ),
    scoped AS (
        SELECT sr.*
        FROM season_results sr
        JOIN latest l ON sr.season_start = l.season_start
        WHERE sr.board = p_board
          AND has_active_subscription(auth.uid())
          AND CASE p_scope
              WHEN 'friends' THEN sr.user_id IN (
                  SELECT f.friend_id FROM friends f WHERE f.user_id = auth.uid()
                  UNION SELECT auth.uid()
              )
              WHEN 'rivals' THEN sr.user_id IN (
                  -- The caller's pod DURING the closed season. Weekly pods
                  -- start exactly at season_start; a monthly season spans
                  -- several weekly pods (months rarely start on Monday), so
                  -- match by range and take the latest pod in the season.
                  SELECT m2.user_id
                  FROM rival_pod_members m2
                  JOIN (
                      SELECT me.pod_id
                      FROM rival_pod_members me
                      WHERE me.user_id = auth.uid()
                        AND me.period_start >= (l.season_start AT TIME ZONE 'utc')::date
                        AND me.period_start < ((l.season_start
                            + CASE WHEN p_board = 'weekly'
                                   THEN interval '7 days'
                                   ELSE interval '1 month' END
                            ) AT TIME ZONE 'utc')::date
                      ORDER BY me.period_start DESC
                      LIMIT 1
                  ) mp ON mp.pod_id = m2.pod_id
              )
              ELSE true
          END
    )
    SELECT s.user_id, pp.display_name, pp.avatar_url, s.composite, s.season_start
    FROM scoped s
    LEFT JOIN public_profiles pp ON pp.user_id = s.user_id
    ORDER BY s.final_rank
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.leaderboard_last_winner(text, text) TO authenticated;

-- ── crons (010 pattern; pg_cron/pg_net created there) ────────────────────────
-- Finalize runs 48 h AFTER each boundary (Wed 00:02 / the 3rd 00:02) so the
-- snapshot includes everything 014's receipt window still accepts — an
-- offline final-day workout that syncs Monday morning must count. The
-- boundary math is run-date-tolerant (date_trunc of now() gives the same
-- prev_start anywhere inside the following period), so only the schedule
-- shifts; placements/pushes simply arrive two days after the reset.
SELECT cron.unschedule('finalize-season-weekly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'finalize-season-weekly');
SELECT cron.schedule(
    'finalize-season-weekly',
    '2 0 * * 3',
    $$ SELECT public.finalize_season('weekly'); $$
);

SELECT cron.unschedule('finalize-season-monthly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'finalize-season-monthly');
SELECT cron.schedule(
    'finalize-season-monthly',
    '2 0 3 * *',
    $$ SELECT public.finalize_season('monthly'); $$
);

SELECT cron.unschedule('assign-rivals-weekly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'assign-rivals-weekly');
SELECT cron.schedule(
    'assign-rivals-weekly',
    '10 0 * * 1',
    $$ SELECT public.assign_rivals(); $$
);

-- First-time setup: pods exist from deploy day (idempotent if already run).
SELECT public.assign_rivals();
