-- ─────────────────────────────────────────────────────────────────────────────
-- 014 — Challenges: curated daily + community challenges, moderation,
--       challenge points wired into the leaderboard composite
--
-- Implements 03-DATABASE.md §3.2 and 04-BACKEND.md §3.2/§3.5, with these
-- documented decisions:
--   • award-challenge-points and moderate-challenges are DB TRIGGERS, not edge
--     functions (both docs allow "or DB trigger"). Awarding inside the row's
--     own transaction is inherently idempotent and can't miss a sync write.
--   • Curated seeding is a SQL function + pg_cron job (04-BACKEND allows
--     "cron/edge"); no FCM is needed at seed time, so no edge function.
--   • Moderation policy: community challenges land 'active' immediately and
--     are auto-hidden at >= 3 distinct reporters ('pending_review' stays in
--     the status enum so a pre-approval policy can be adopted later without a
--     schema change). Rationale: there is no admin approval tool at launch;
--     report-threshold takedown + the review queue view satisfies App Store
--     1.2 (report ✓, block ✓ via friendships, takedown ✓).
--   • Anti-cheat: community challenge points are capped (≤ 50/challenge) at
--     the RLS layer, points_awarded / completed_at are ALWAYS recomputed
--     server-side by the award trigger, challenge_id is immutable on UPDATE
--     (blocks past-challenge farming), awards need a receipt within 48 h of
--     the window closing, and the leaderboard sums no self-created
--     challenges and caps community-sourced points at 100 per window — so
--     self-serve creation cannot mint leaderboard position.
--   • Block-aware visibility: a challenge is invisible to a viewer when a
--     'blocked' friendships edge exists between viewer and creator (either
--     direction) — App Store 1.2 "block abusive users" applied to UGC.
--
-- Points → leaderboard: compute_leaderboard_scores() is REPLACED below; the
-- composite becomes avg(streak_norm, volume_norm, points_norm) as 008's
-- header promised ("when challenges land, add points_norm back").
--
-- delete_account_data (rewritten in 013) is REPLACED to wipe challenge rows.
--
-- NOT YET DEPLOYED — runs with 012/013 on the first `supabase db push`
-- (SETUP-STATUS). TODO(deploy): store `project_url` + `cron_secret` in Vault
-- (010 header) — the completion-push trigger reads them; it degrades to
-- no-push (never fails the transaction) while they're absent.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── challenge_templates: the curated pool the daily seeder rotates through ──
-- Server-side only: the client localizes curated challenges by template id
-- (ARB keys), so no client SELECT policy is needed. title/description here are
-- the canonical English fallback for clients that don't know a new id yet.
CREATE TABLE IF NOT EXISTS public.challenge_templates (
    id          text PRIMARY KEY,
    title       text    NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
    description text    NOT NULL CHECK (char_length(description) <= 500),
    goal_type   text    NOT NULL CHECK (goal_type IN ('volume', 'sessions', 'sets', 'streak', 'custom')),
    goal_value  numeric NOT NULL CHECK (goal_value > 0),
    points      integer NOT NULL DEFAULT 10 CHECK (points BETWEEN 0 AND 100),
    active      boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.challenge_templates ENABLE ROW LEVEL SECURITY;
-- No policies: deny all client access; only the service role touches the pool.

INSERT INTO public.challenge_templates (id, title, description, goal_type, goal_value, points) VALUES
    ('tpl_daily_one_session', 'Show Up',           'Complete one workout session today.',            'sessions', 1,     10),
    ('tpl_daily_volume_5k',   'Move 5,000 kg',     'Lift a total of 5,000 kg across all sets today.', 'volume',  5000,  15),
    ('tpl_daily_volume_10k',  'Move 10,000 kg',    'Lift a total of 10,000 kg across all sets today.','volume',  10000, 25),
    ('tpl_daily_sets_12',     '12 Working Sets',   'Complete 12 working sets today (warm-ups don''t count).', 'sets', 12, 15),
    ('tpl_daily_sets_20',     '20 Working Sets',   'Complete 20 working sets today (warm-ups don''t count).', 'sets', 20, 25)
ON CONFLICT (id) DO NOTHING;

-- ── challenges ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.challenges (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source      text NOT NULL CHECK (source IN ('curated', 'community')),
    creator_id  uuid REFERENCES auth.users (id) ON DELETE CASCADE,  -- NULL for curated
    template_id text REFERENCES public.challenge_templates (id),    -- NULL for community
    title       text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
    description text CHECK (char_length(description) <= 500),
    goal_type   text NOT NULL CHECK (goal_type IN ('volume', 'sessions', 'sets', 'streak', 'custom')),
    goal_value  numeric NOT NULL CHECK (goal_value > 0),
    starts_at   timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL,
    points      integer NOT NULL DEFAULT 0 CHECK (points >= 0),
    status      text NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'ended', 'hidden', 'pending_review')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT challenges_window_valid CHECK (ends_at > starts_at),
    -- curated ⇔ no creator; community ⇔ creator present.
    CONSTRAINT challenges_creator_consistent CHECK (
        (source = 'curated'   AND creator_id IS NULL)
        OR (source = 'community' AND creator_id IS NOT NULL AND template_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_challenges_status_window
    ON public.challenges (status, ends_at);
CREATE INDEX IF NOT EXISTS idx_challenges_creator
    ON public.challenges (creator_id) WHERE creator_id IS NOT NULL;

-- One curated challenge per UTC day — makes the daily seeder idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS uq_challenges_curated_daily
    ON public.challenges ((timezone('utc', starts_at)::date))
    WHERE source = 'curated';

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

-- Read: subscribers see live/finished challenges — but never one authored by
-- someone in a blocked relationship with them (either direction). Creators
-- always see their own rows (incl. hidden/pending) so their list is honest.
DROP POLICY IF EXISTS "challenges_select_subscribers" ON public.challenges;
CREATE POLICY "challenges_select_subscribers"
    ON public.challenges FOR SELECT
    TO authenticated
    USING (
        creator_id = auth.uid()
        OR (
            has_active_subscription(auth.uid())
            AND status IN ('active', 'ended')
            AND (
                creator_id IS NULL
                OR NOT EXISTS (
                    SELECT 1 FROM friendships f
                    WHERE f.status = 'blocked'
                      AND ((f.requester_id = auth.uid() AND f.addressee_id = creator_id)
                        OR (f.addressee_id = auth.uid() AND f.requester_id = creator_id))
                )
            )
        )
    );

-- Create: community only, self-authored, subscriber, sane window (≤ 31 days,
-- not already over), capped points, goal floor (a 0.001 goal would be a free
-- completion). Status must be 'active' (launch policy).
DROP POLICY IF EXISTS "challenges_insert_community" ON public.challenges;
CREATE POLICY "challenges_insert_community"
    ON public.challenges FOR INSERT
    TO authenticated
    WITH CHECK (
        source = 'community'
        AND creator_id = auth.uid()
        AND status = 'active'
        AND has_active_subscription(auth.uid())
        AND points BETWEEN 0 AND 50
        AND goal_value >= 1
        AND ends_at > now()
        AND starts_at >= now() - interval '1 day'
        AND ends_at <= starts_at + interval '31 days'
    );

-- Delete: a creator can take down their own community challenge (participants
-- and reports cascade). No client UPDATE path — status changes are server-side.
DROP POLICY IF EXISTS "challenges_delete_own" ON public.challenges;
CREATE POLICY "challenges_delete_own"
    ON public.challenges FOR DELETE
    TO authenticated
    USING (source = 'community' AND creator_id = auth.uid());

-- ── challenge_participants ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.challenge_participants (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id   uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
    user_id        uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    progress       numeric NOT NULL DEFAULT 0 CHECK (progress >= 0),
    joined_at      timestamptz NOT NULL DEFAULT now(),
    completed_at   timestamptz,
    points_awarded integer NOT NULL DEFAULT 0,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (challenge_id, user_id)
);

-- Serves the leaderboard points CTE (completed rows in a window, per user).
CREATE INDEX IF NOT EXISTS idx_challenge_participants_user_completed
    ON public.challenge_participants (user_id, completed_at);
CREATE INDEX IF NOT EXISTS idx_challenge_participants_challenge
    ON public.challenge_participants (challenge_id);

ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;

-- Read: own rows always (offline restore after a lapsed sub); other people's
-- rows only for subscribers, only on challenges the viewer can see (mirrors
-- the challenges SELECT policy: no hidden challenges), and never rows of a
-- user in a blocked pair with the viewer (App Store 1.2 posture).
DROP POLICY IF EXISTS "challenge_participants_select" ON public.challenge_participants;
CREATE POLICY "challenge_participants_select"
    ON public.challenge_participants FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR (
            has_active_subscription(auth.uid())
            AND EXISTS (
                SELECT 1 FROM challenges c
                WHERE c.id = challenge_id
                  AND c.status IN ('active', 'ended')
            )
            AND NOT EXISTS (
                SELECT 1 FROM friendships f
                WHERE f.status = 'blocked'
                  AND ((f.requester_id = auth.uid() AND f.addressee_id = user_id)
                    OR (f.addressee_id = auth.uid() AND f.requester_id = user_id))
            )
        )
    );

-- Join: self, subscriber, challenge window still open (+ 24 h grace so an
-- offline join+completion from the final day can sync late — 'ended' is
-- allowed because the daily janitor flips status at 00:05, long before the
-- grace runs out; the award trigger still validates completed_at against the
-- real window).
DROP POLICY IF EXISTS "challenge_participants_insert_self" ON public.challenge_participants;
CREATE POLICY "challenge_participants_insert_self"
    ON public.challenge_participants FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND has_active_subscription(auth.uid())
        AND EXISTS (
            SELECT 1 FROM challenges c
            WHERE c.id = challenge_id
              AND c.status IN ('active', 'ended')
              AND now() < c.ends_at + interval '24 hours'
        )
    );

DROP POLICY IF EXISTS "challenge_participants_update_self" ON public.challenge_participants;
CREATE POLICY "challenge_participants_update_self"
    ON public.challenge_participants FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Leave a challenge.
DROP POLICY IF EXISTS "challenge_participants_delete_self" ON public.challenge_participants;
CREATE POLICY "challenge_participants_delete_self"
    ON public.challenge_participants FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- ── challenge_reports (moderation, 04-BACKEND §3.5) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.challenge_reports (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
    reporter_id  uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    reason       text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
    created_at   timestamptz NOT NULL DEFAULT now(),
    -- One report per user per challenge: the hide threshold counts people,
    -- not clicks, and one user can't spam a challenge into hiding.
    UNIQUE (challenge_id, reporter_id)
);

ALTER TABLE public.challenge_reports ENABLE ROW LEVEL SECURITY;

-- Insert-only for clients (admin reads via service role / review queue view).
-- Only community content is reportable.
DROP POLICY IF EXISTS "challenge_reports_insert" ON public.challenge_reports;
CREATE POLICY "challenge_reports_insert"
    ON public.challenge_reports FOR INSERT
    TO authenticated
    WITH CHECK (
        reporter_id = auth.uid()
        AND has_active_subscription(auth.uid())
        AND EXISTS (
            SELECT 1 FROM challenges c
            WHERE c.id = challenge_id AND c.source = 'community'
        )
    );

-- ── award-challenge-points (04-BACKEND §3.2, as a trigger) ───────────────────
-- BEFORE trigger: completed_at/points_awarded are SERVER-DERIVED. Whatever the
-- client sends, completion only stands if progress met the goal inside the
-- challenge window on a non-hidden challenge — otherwise both fields reset.
-- Re-running the same sync write recomputes the same result (idempotent).
CREATE OR REPLACE FUNCTION public.award_challenge_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    c challenges%ROWTYPE;
BEGIN
    -- Remapping a row to another challenge would let a client farm awards
    -- from every past challenge through the UPDATE policy (WITH CHECK can't
    -- compare OLD/NEW — same reason 012 has friendships_lock_pair).
    IF TG_OP = 'UPDATE' AND NEW.challenge_id IS DISTINCT FROM OLD.challenge_id THEN
        RAISE EXCEPTION 'challenge_id is immutable';
    END IF;

    -- A standing award is locked: idempotent sync replays and late progress
    -- updates must not revoke (or re-mint) it. Moderated-away challenges are
    -- excluded at leaderboard-compute time instead of clawing back here.
    IF TG_OP = 'UPDATE' AND OLD.completed_at IS NOT NULL
       AND OLD.points_awarded > 0
    THEN
        NEW.completed_at   := OLD.completed_at;
        NEW.points_awarded := OLD.points_awarded;
        NEW.updated_at     := now();
        RETURN NEW;
    END IF;

    SELECT * INTO c FROM challenges WHERE id = NEW.challenge_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'challenge % not found', NEW.challenge_id;
    END IF;

    IF NEW.completed_at IS NOT NULL
       AND NEW.progress >= c.goal_value
       AND c.status IN ('active', 'ended')
       AND NEW.completed_at >= c.starts_at
       AND NEW.completed_at <= c.ends_at
       -- Receipt deadline: an in-window completion must sync within 48 h of
       -- the window closing, bounding back-dated claims on long-ended
       -- challenges (the client detects completion live, so honest syncs
       -- land well inside this).
       AND now() <= c.ends_at + interval '48 hours'
    THEN
        -- Completing your own challenge counts as completed but pays 0 —
        -- keeps the row consistent with the leaderboard's self-award
        -- exclusion (which stays as belt-and-braces).
        NEW.points_awarded :=
            CASE WHEN NEW.user_id IS DISTINCT FROM c.creator_id
                 THEN c.points ELSE 0 END;
    ELSE
        NEW.completed_at   := NULL;
        NEW.points_awarded := 0;
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_challenge_points ON public.challenge_participants;
CREATE TRIGGER trg_award_challenge_points
    BEFORE INSERT OR UPDATE ON public.challenge_participants
    FOR EACH ROW EXECUTE FUNCTION public.award_challenge_points();

-- ── completion push → notify-social-challenge ────────────────────────────────
-- AFTER trigger, fires only on the NULL → NOT NULL completion transition, so
-- sync retries can't double-notify. Best-effort: pg_net/Vault problems are
-- swallowed — a missing push must never fail the award write.
CREATE OR REPLACE FUNCTION public.notify_challenge_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.completed_at IS NOT NULL AND NEW.points_awarded > 0
       AND (TG_OP = 'INSERT' OR OLD.completed_at IS NULL)
    THEN
        BEGIN
            PERFORM net.http_post(
                url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
                       || '/functions/v1/notify-social-challenge',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
                ),
                body := jsonb_build_object(
                    'kind', 'challenge_completed',
                    'user_id', NEW.user_id,
                    'challenge_id', NEW.challenge_id
                )
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_challenge_completion ON public.challenge_participants;
CREATE TRIGGER trg_notify_challenge_completion
    AFTER INSERT OR UPDATE ON public.challenge_participants
    FOR EACH ROW EXECUTE FUNCTION public.notify_challenge_completion();

-- ── moderate-challenges (04-BACKEND §3.5, as a trigger) ──────────────────────
-- ≥ 3 distinct reporters hides a community challenge. SECURITY DEFINER because
-- reporters have no UPDATE right on challenges.
CREATE OR REPLACE FUNCTION public.moderate_challenges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE challenges c
    SET status = 'hidden'
    WHERE c.id = NEW.challenge_id
      AND c.source = 'community'
      AND c.status <> 'hidden'
      AND (SELECT count(*) FROM challenge_reports r
           WHERE r.challenge_id = NEW.challenge_id) >= 3;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_moderate_challenges ON public.challenge_reports;
CREATE TRIGGER trg_moderate_challenges
    AFTER INSERT ON public.challenge_reports
    FOR EACH ROW EXECUTE FUNCTION public.moderate_challenges();

-- Review queue: admin-only (service role / dashboard SQL). Hidden and reported
-- challenges with their report tallies.
CREATE OR REPLACE VIEW public.challenge_review_queue AS
SELECT c.id, c.source, c.creator_id, c.title, c.description, c.status,
       c.starts_at, c.ends_at, c.points, c.created_at,
       (SELECT count(*)          FROM public.challenge_reports r WHERE r.challenge_id = c.id) AS report_count,
       (SELECT max(r.created_at) FROM public.challenge_reports r WHERE r.challenge_id = c.id) AS last_reported_at
FROM public.challenges c
WHERE c.status IN ('hidden', 'pending_review')
   OR EXISTS (SELECT 1 FROM public.challenge_reports r WHERE r.challenge_id = c.id);

REVOKE ALL ON public.challenge_review_queue FROM anon, authenticated;

-- ── seed_daily_challenge(): curated daily + status sweep ─────────────────────
-- Runs daily via pg_cron. Also the janitor: flips finished challenges to
-- 'ended'. Template choice is a deterministic rotation over the active pool
-- (stable per day, no RNG), idempotent via uq_challenges_curated_daily.
CREATE OR REPLACE FUNCTION public.seed_daily_challenge()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    today date := (now() AT TIME ZONE 'utc')::date;
    tpl   challenge_templates%ROWTYPE;
    n     integer;
BEGIN
    UPDATE challenges SET status = 'ended'
    WHERE status = 'active' AND ends_at <= now();

    SELECT count(*) INTO n FROM challenge_templates WHERE active;
    IF n = 0 THEN
        RETURN;
    END IF;

    SELECT t.* INTO tpl
    FROM (
        SELECT ct.*, row_number() OVER (ORDER BY ct.id) - 1 AS rn
        FROM challenge_templates ct
        WHERE ct.active
    ) t
    WHERE t.rn = (today - date '2026-01-05') % n;

    INSERT INTO challenges
        (source, creator_id, template_id, title, description,
         goal_type, goal_value, starts_at, ends_at, points, status)
    VALUES
        ('curated', NULL, tpl.id, tpl.title, tpl.description,
         tpl.goal_type, tpl.goal_value,
         today::timestamp AT TIME ZONE 'utc',
         (today + 1)::timestamp AT TIME ZONE 'utc',
         tpl.points, 'active')
    ON CONFLICT DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.seed_daily_challenge() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.seed_daily_challenge() FROM anon, authenticated;

-- Schedule (010 pattern; pg_cron/pg_net created there). Direct SQL call — no
-- edge function or secret needed for seeding.
SELECT cron.unschedule('seed-daily-challenge')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'seed-daily-challenge');

SELECT cron.schedule(
    'seed-daily-challenge',
    '5 0 * * *',
    $$ SELECT public.seed_daily_challenge(); $$
);

-- Seed immediately so a curated challenge exists from deploy day one.
SELECT public.seed_daily_challenge();

-- ── compute_leaderboard_scores(): points join the composite ──────────────────
-- Replaces 008's version. Only the points wiring changes: points_raw is the
-- window sum of points_awarded on non-hidden challenges, points_norm is its
-- percentile, and the composite becomes the three-way average — exactly the
-- follow-up 008's header called for. Streak/volume/anti-cheat are unchanged.
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
        challenge_points AS (
            -- Challenge points completed inside the window. Anti-mint rules:
            -- hidden (moderated-away) challenges stop paying out at the next
            -- recompute; a creator's own challenges never pay them (self-
            -- serve creation must not be a points printer); and community-
            -- sourced points are capped at 100 per user per window so
            -- colluding rings can't hand each other the points component.
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
              AND cp.completed_at >= win_start
            GROUP BY cp.user_id
        ),
        population AS (
            -- Every non-deleted profile: new users score 0 and sit at the
            -- bottom of the board rather than being hidden.
            SELECT p.user_id FROM user_profiles p WHERE p.deleted_at IS NULL
        ),
        raw AS (
            SELECT pop.user_id,
                   COALESCE(t.streak_raw, 0)    AS streak_raw,
                   COALESCE(v.volume_raw, 0.0)  AS volume_raw,
                   COALESCE(cp.points_raw, 0.0) AS points_raw
            FROM population pop
            LEFT JOIN training_days    t  USING (user_id)
            LEFT JOIN volumes          v  USING (user_id)
            LEFT JOIN challenge_points cp USING (user_id)
        ),
        normed AS (
            -- Percentile-normalise each component to 0–100 so raw volume
            -- can't numerically dwarf the streak or points components.
            SELECT user_id, streak_raw, volume_raw, points_raw,
                   percent_rank() OVER (ORDER BY streak_raw) * 100 AS streak_norm,
                   percent_rank() OVER (ORDER BY volume_raw) * 100 AS volume_norm,
                   percent_rank() OVER (ORDER BY points_raw) * 100 AS points_norm
            FROM raw
        )
        SELECT user_id, b,
               streak_raw, volume_raw, points_raw,
               streak_norm, volume_norm, points_norm,
               -- Composite = mean of all three components (04-BACKEND §3.1).
               (streak_norm + volume_norm + points_norm) / 3.0 AS composite,
               row_number() OVER (
                   ORDER BY (streak_norm + volume_norm + points_norm) / 3.0 DESC,
                            volume_raw DESC,
                            user_id
               )::integer AS global_rank,
               now()
        FROM normed;
    END LOOP;
END;
$$;

-- 008 already revoked client EXECUTE; CREATE OR REPLACE preserves ACLs.

-- ── delete_account_data: add the challenge tables (013 contract) ─────────────
-- Same belt-and-braces rationale as 013: the FKs cascade off auth.users, but
-- doing the deletes here keeps the whole wipe in one transaction. Deleting the
-- user's community challenges also cascades everyone else's participation in
-- them — authored UGC does not outlive the account (store/GDPR posture).
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
    -- Billing, leaderboard, profile.
    DELETE FROM subscriptions      WHERE user_id = target;
    DELETE FROM leaderboard_scores WHERE user_id = target;
    DELETE FROM user_profiles      WHERE user_id = target;
END;
$$;
