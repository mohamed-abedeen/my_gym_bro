-- ─────────────────────────────────────────────────────────────────────────────
-- 008 — Leaderboard: server-authoritative scores + scope RPCs
--
-- Implements 04-BACKEND.md §3.1 with two documented deviations:
--   • points_raw (challenge points) is always 0 until the challenges backend
--     ships; the composite therefore averages the streak and volume components
--     only. When challenges land, add points_norm back into the average.
--   • The Rivals scope is computed at read time as the ±window of users
--     adjacent to the caller in the global composite ordering, instead of
--     pre-assigned weekly pods (§3.1a). Same UX (compete against users of
--     similar level) without the pod-assignment scheduler; pods can replace
--     this later without touching clients (same RPC shape).
--
-- Anti-cheat (04-BACKEND.md "plausibility caps"): volume is recomputed from
-- the sets table server-side — the client-reported sessions.total_volume_kg is
-- never trusted — and each set must pass hard plausibility caps (see
-- plausible_sets in compute_leaderboard_scores) or it is excluded.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── leaderboard_scores: server-authoritative, read-only to clients ──────────
CREATE TABLE IF NOT EXISTS public.leaderboard_scores (
    user_id     uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    board       text NOT NULL CHECK (board IN ('weekly', 'monthly', 'all_time')),
    streak_raw  integer          NOT NULL DEFAULT 0,
    volume_raw  double precision NOT NULL DEFAULT 0,
    points_raw  double precision NOT NULL DEFAULT 0,
    streak_norm double precision NOT NULL DEFAULT 0,
    volume_norm double precision NOT NULL DEFAULT 0,
    points_norm double precision NOT NULL DEFAULT 0,
    composite   double precision NOT NULL DEFAULT 0,
    global_rank integer,
    computed_at timestamptz      NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, board)
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_board_rank
    ON public.leaderboard_scores (board, global_rank);

ALTER TABLE public.leaderboard_scores ENABLE ROW LEVEL SECURITY;

-- Premium read; NO insert/update/delete policies — only the service role
-- (which bypasses RLS) writes scores.
CREATE POLICY "leaderboard_select_subscribers"
    ON public.leaderboard_scores FOR SELECT
    TO authenticated
    USING (has_active_subscription(auth.uid()));

-- ── compute_leaderboard_scores(): the scoring engine ─────────────────────────
-- Called by the scheduled `compute-leaderboard` edge function via the service
-- role. Recomputes all three boards in one transaction.
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
        WITH plausible_sets AS (
            -- Anti-cheat: recompute volume from raw sets and drop anything
            -- outside hard plausibility caps. 500 kg exceeds every raw
            -- world record; 60 reps / 6000 kg·reps per set is beyond any
            -- real working set.
            SELECT s.user_id, s.weight_kg * s.reps AS vol
            FROM sets s
            WHERE s.deleted_at IS NULL
              AND s.completed_at IS NOT NULL
              AND s.completed_at >= win_start
              AND s.is_warmup = false
              AND s.weight_kg IS NOT NULL AND s.reps IS NOT NULL
              AND s.weight_kg > 0        AND s.weight_kg <= 500
              AND s.reps      > 0        AND s.reps      <= 60
              AND s.weight_kg * s.reps   <= 6000
        ),
        volumes AS (
            SELECT user_id, sum(vol) AS volume_raw
            FROM plausible_sets
            GROUP BY user_id
        ),
        training_days AS (
            -- Distinct training days inside the window (lifetime count for
            -- the all_time board) — the consistency component.
            SELECT user_id,
                   count(DISTINCT date(started_at)) AS streak_raw
            FROM sessions
            WHERE deleted_at IS NULL
              AND finished_at IS NOT NULL
              AND started_at >= win_start
            GROUP BY user_id
        ),
        population AS (
            -- Every non-deleted profile: new users score 0 and sit at the
            -- bottom of the board rather than being hidden.
            SELECT p.user_id FROM user_profiles p WHERE p.deleted_at IS NULL
        ),
        raw AS (
            SELECT pop.user_id,
                   COALESCE(t.streak_raw, 0)   AS streak_raw,
                   COALESCE(v.volume_raw, 0.0) AS volume_raw,
                   0.0                          AS points_raw
            FROM population pop
            LEFT JOIN training_days t USING (user_id)
            LEFT JOIN volumes       v USING (user_id)
        ),
        normed AS (
            -- Percentile-normalise each component to 0–100 so raw volume
            -- can't numerically dwarf the streak component.
            SELECT user_id, streak_raw, volume_raw, points_raw,
                   percent_rank() OVER (ORDER BY streak_raw) * 100 AS streak_norm,
                   percent_rank() OVER (ORDER BY volume_raw) * 100 AS volume_norm,
                   0.0 AS points_norm
            FROM raw
        )
        SELECT user_id, b,
               streak_raw, volume_raw, points_raw,
               streak_norm, volume_norm, points_norm,
               -- Composite = mean of the live components (challenge points
               -- join the average once that backend exists).
               (streak_norm + volume_norm) / 2.0 AS composite,
               row_number() OVER (
                   ORDER BY (streak_norm + volume_norm) / 2.0 DESC,
                            volume_raw DESC,
                            user_id
               )::integer AS global_rank,
               now()
        FROM normed;
    END LOOP;
END;
$$;

-- Service-role only: never callable from clients.
REVOKE ALL ON FUNCTION public.compute_leaderboard_scores() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.compute_leaderboard_scores() FROM anon, authenticated;

-- ── Shared row shape for the scope RPCs ──────────────────────────────────────
-- (display fields come from public_profiles so private columns stay private)

-- Global scope: top-N plus the caller's own row.
CREATE OR REPLACE FUNCTION public.leaderboard_global(
    p_board text DEFAULT 'weekly',
    p_limit integer DEFAULT 50
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
    SELECT ls.user_id,
           pp.display_name,
           pp.avatar_url,
           ls.volume_raw,
           ls.composite,
           ls.global_rank AS rank,
           ls.user_id = auth.uid() AS is_me
    FROM leaderboard_scores ls
    LEFT JOIN public_profiles pp ON pp.user_id = ls.user_id
    WHERE ls.board = p_board
      AND has_active_subscription(auth.uid())
      AND (ls.global_rank <= p_limit OR ls.user_id = auth.uid())
    ORDER BY ls.global_rank;
$$;

-- Friends scope: the caller's mutual-follow friends (+ the caller), re-ranked
-- within that group. Reuses the stored composite — no extra normalisation.
CREATE OR REPLACE FUNCTION public.leaderboard_friends(
    p_board text DEFAULT 'weekly'
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
    SELECT ls.user_id,
           pp.display_name,
           pp.avatar_url,
           ls.volume_raw,
           ls.composite,
           rank() OVER (ORDER BY ls.composite DESC)::integer AS rank,
           ls.user_id = auth.uid() AS is_me
    FROM leaderboard_scores ls
    LEFT JOIN public_profiles pp ON pp.user_id = ls.user_id
    WHERE ls.board = p_board
      AND has_active_subscription(auth.uid())
      AND ls.user_id IN (
          SELECT friend_id FROM friends WHERE friends.user_id = auth.uid()
          UNION SELECT auth.uid()
      )
    ORDER BY ls.composite DESC;
$$;

-- Rivals scope: the window of users adjacent to the caller in the global
-- ordering — users of comparable level this season.
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
    WITH me AS (
        SELECT global_rank
        FROM leaderboard_scores
        WHERE board = p_board AND leaderboard_scores.user_id = auth.uid()
    )
    SELECT ls.user_id,
           pp.display_name,
           pp.avatar_url,
           ls.volume_raw,
           ls.composite,
           ls.global_rank AS rank,
           ls.user_id = auth.uid() AS is_me
    FROM leaderboard_scores ls
    LEFT JOIN public_profiles pp ON pp.user_id = ls.user_id, me
    WHERE ls.board = p_board
      AND has_active_subscription(auth.uid())
      AND ls.global_rank BETWEEN me.global_rank - p_window
                             AND me.global_rank + p_window
    ORDER BY ls.global_rank;
$$;

GRANT EXECUTE ON FUNCTION public.leaderboard_global(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard_friends(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard_rivals(text, integer) TO authenticated;
