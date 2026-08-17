-- ─────────────────────────────────────────────────────────────────────────────
-- 016 — Skins economy (PRD §5.10 / §4.3, 03-DATABASE §3.3, 04-BACKEND §3.3/§3.4)
--
-- Adds the server half of the cosmetic-skin economy:
--   • `skins` — the catalog (mirrors the client's static map in
--     lib/features/settings/skin_provider.dart; ids must match exactly).
--     `unlock_rule` drives server-side earning; `product_id` names the
--     RevenueCat one-time product for purchasable skins.
--   • `skin_ownership` — durable earned/purchased grants. Owner-read only;
--     ALL writes are server-side (purchase-skin edge fn verifies receipts,
--     evaluate_earned_skins() evaluates rules) so ownership can't be spoofed.
--   • `user_profiles.active_skin_id` — the selected skin, synced from the
--     client like any other profile field and exposed on public_profiles so
--     a bro's profile can render their skinned body.
--   • `evaluate_earned_skins()` + daily pg_cron — grants earnable skins from
--     synced data (session counts, challenge completions, season placements
--     via season_results) and fires a tone-resolved "skin unlocked" push
--     through send-push-notification (kind: skin_unlocked).
--
-- Earning rules: the session thresholds shipped in the client stay EXACTLY
-- as they are (live beta behaviour — the client still unlocks them locally
-- and offline). Server rules re-grant them durably (cross-device) and add
-- OR-alternatives on the top tiers only (challenges / season placements), so
-- no skin gets harder to earn. `streak`-type rules are deliberately NOT
-- seeded: server-side streak parity with the locked computeStreak semantics
-- (schedule-aware allowance + monthly skips) doesn't exist, and an
-- approximation would mis-grant. The rule engine ignores unknown types, so a
-- streak rule can ship later without a schema change.
--
-- NOT YET DEPLOYED — rides the first `supabase db push` (SETUP-STATUS).
-- TODO(deploy): Vault secrets `project_url` + `cron_secret` (010 header) must
-- exist for the unlock pushes; absent Vault degrades to no-push, never fails.
-- TODO(deploy): run `SELECT evaluate_earned_skins();` once after push so
-- existing users get their sessions-based grants without waiting for cron.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── skins: the catalog ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.skins (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    gender      text NOT NULL DEFAULT 'both' CHECK (gender IN ('both', 'male', 'female')),
    acquisition text NOT NULL CHECK (acquisition IN ('default', 'earnable', 'purchasable')),
    product_id  text,
    unlock_rule jsonb,
    sort_order  integer NOT NULL DEFAULT 0
);

ALTER TABLE public.skins ENABLE ROW LEVEL SECURITY;

-- Catalog is world-readable for signed-in users (the gallery itself sits
-- behind the app's paywall gate); writes are service-role only.
DROP POLICY IF EXISTS "skins_select_authenticated" ON public.skins;
CREATE POLICY "skins_select_authenticated"
    ON public.skins FOR SELECT
    TO authenticated
    USING (true);

-- Cloud projects created after 2026-05-30 no longer auto-grant table
-- privileges to the API roles (config.toml api section) — RLS policies alone
-- aren't enough, the role also needs the table-level GRANT.
GRANT SELECT ON public.skins TO authenticated;

-- Seed / re-sync the catalog. DO UPDATE so a redeploy propagates rule or
-- product corrections; ids are the client's stable identifiers — never rename.
INSERT INTO public.skins (id, name, gender, acquisition, product_id, unlock_rule, sort_order) VALUES
    ('default',    'Default',    'both',   'default',     NULL, NULL, 0),
    ('carbone',    'Carbone',    'both',   'default',     NULL, NULL, 1),
    ('smoke',      'Smoke',      'both',   'default',     NULL, NULL, 2),
    ('white',      'White',      'male',   'default',     NULL, NULL, 3),
    ('light',      'Light',      'female', 'default',     NULL, NULL, 4),
    ('carbon',     'Carbon',     'both',   'earnable',    NULL, '{"any":[{"type":"sessions","value":10}]}',  5),
    ('gold',       'Gold',       'both',   'purchasable', 'mgb_skin_gold',       NULL, 6),
    ('metal',      'Metal',      'both',   'earnable',    NULL, '{"any":[{"type":"sessions","value":25}]}',  7),
    ('liquid',     'Liquid',     'both',   'earnable',    NULL, '{"any":[{"type":"sessions","value":50}]}',  8),
    ('atack',      'Attack',     'both',   'earnable',    NULL, '{"any":[{"type":"sessions","value":75},{"type":"challenges","value":15}]}', 9),
    ('galaxy',     'Galaxy',     'female', 'purchasable', 'mgb_skin_galaxy',     NULL, 10),
    ('teddy_bear', 'Teddy Bear', 'female', 'purchasable', 'mgb_skin_teddy_bear', NULL, 11),
    ('gren_guy',   'Green Guy',  'male',   'earnable',    NULL, '{"any":[{"type":"sessions","value":120},{"type":"season_top3","board":"monthly"}]}', 12),
    ('volkano',    'Volcano',    'male',   'earnable',    NULL, '{"any":[{"type":"sessions","value":200},{"type":"season_win","board":"weekly"}]}',   13)
ON CONFLICT (id) DO UPDATE SET
    name        = EXCLUDED.name,
    gender      = EXCLUDED.gender,
    acquisition = EXCLUDED.acquisition,
    product_id  = EXCLUDED.product_id,
    unlock_rule = EXCLUDED.unlock_rule,
    sort_order  = EXCLUDED.sort_order;

-- ── skin_ownership: durable grants, server-written only ──────────────────────
CREATE TABLE IF NOT EXISTS public.skin_ownership (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    skin_id     text NOT NULL REFERENCES public.skins (id),
    source      text NOT NULL CHECK (source IN ('earned', 'purchased')),
    acquired_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, skin_id)
);

CREATE INDEX IF NOT EXISTS idx_skin_ownership_user
    ON public.skin_ownership (user_id);

ALTER TABLE public.skin_ownership ENABLE ROW LEVEL SECURITY;

-- Owner-read always (cosmetics stay visible through a lapsed subscription);
-- deliberately NO client INSERT/UPDATE/DELETE policies — the service role
-- (purchase-skin verify, evaluate_earned_skins) bypasses RLS and is the only
-- writer, per 03-DATABASE §3.3's anti-spoofing contract.
DROP POLICY IF EXISTS "skin_ownership_select_own" ON public.skin_ownership;
CREATE POLICY "skin_ownership_select_own"
    ON public.skin_ownership FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Same post-2026-05-30 grant requirement as `skins` above; SELECT only —
-- the absence of INSERT/UPDATE/DELETE grants is the anti-spoof contract's
-- second lock alongside the missing policies.
GRANT SELECT ON public.skin_ownership TO authenticated;

-- ── user_profiles.active_skin_id ─────────────────────────────────────────────
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS active_skin_id text
    CHECK (active_skin_id IS NULL OR char_length(active_skin_id) <= 40);

-- 009 revoked UPDATE/INSERT and granted back per-column; grants are additive,
-- so extend them with just the new column. Selection is a cosmetic,
-- user-editable field — lock-gating is enforced at selection time in the app
-- and ownership itself is server-authoritative, so a spoofed active_skin_id
-- only ever points at an asset the client refuses to render as unlocked.
GRANT UPDATE (active_skin_id) ON public.user_profiles TO authenticated;
GRANT INSERT (active_skin_id) ON public.user_profiles TO authenticated;

-- public_profiles: + active_skin_id (a bro's profile renders their skin).
-- DROP + CREATE because REPLACE can't reorder/extend safely (012 precedent);
-- still the column-level privacy boundary.
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT
    p.user_id,
    p.display_name,
    p.username,
    p.avatar_url,
    p.experience,
    p.created_at,
    p.active_skin_id,
    (SELECT count(*) FROM public.friends fr WHERE fr.user_id = p.user_id) AS friend_count
FROM public.user_profiles p
WHERE p.deleted_at IS NULL;

GRANT SELECT ON public.public_profiles TO authenticated;

-- ── evaluate_earned_skins(): rule evaluation + unlock push ───────────────────
-- Set-based over all users; idempotent via the (user_id, skin_id) unique key
-- (ON CONFLICT DO NOTHING) — the push loop only sees genuinely-new grants, so
-- re-runs can't double-notify. Unknown rule types are ignored (forward
-- compatibility). Pushes are best-effort: absent pg_net/Vault never fails.
CREATE OR REPLACE FUNCTION public.evaluate_earned_skins()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    granted integer := 0;
    g RECORD;
BEGIN
    FOR g IN
        WITH rules AS (
            SELECT s.id AS skin_id, s.name AS skin_name, r.rule
            FROM skins s
            CROSS JOIN LATERAL jsonb_array_elements(
                coalesce(s.unlock_rule -> 'any', '[]'::jsonb)
            ) AS r(rule)
            WHERE s.acquisition = 'earnable'
        ),
        session_counts AS (
            SELECT user_id, count(*) AS n
            FROM sessions
            WHERE finished_at IS NOT NULL AND deleted_at IS NULL
            GROUP BY user_id
        ),
        challenge_counts AS (
            -- Mirror 014's anti-mint posture: self-created and since-hidden
            -- challenges don't count toward earn rules, or 15 trivial
            -- self-completions would mint 'atack'.
            SELECT cp.user_id, count(*) AS n
            FROM challenge_participants cp
            JOIN challenges c
              ON c.id = cp.challenge_id
             AND c.status <> 'hidden'
             AND c.creator_id IS DISTINCT FROM cp.user_id
            WHERE cp.completed_at IS NOT NULL
            GROUP BY cp.user_id
        ),
        qualifying AS (
            SELECT sc.user_id, r.skin_id, r.skin_name
            FROM rules r
            JOIN session_counts sc
              ON r.rule ->> 'type' = 'sessions'
             AND sc.n >= (r.rule ->> 'value')::integer
            UNION
            SELECT cc.user_id, r.skin_id, r.skin_name
            FROM rules r
            JOIN challenge_counts cc
              ON r.rule ->> 'type' = 'challenges'
             AND cc.n >= (r.rule ->> 'value')::integer
            UNION
            SELECT sr.user_id, r.skin_id, r.skin_name
            FROM rules r
            JOIN season_results sr
              ON r.rule ->> 'type' = 'season_win'
             AND sr.board = r.rule ->> 'board'
             AND sr.final_rank = 1
            UNION
            SELECT sr.user_id, r.skin_id, r.skin_name
            FROM rules r
            JOIN season_results sr
              ON r.rule ->> 'type' = 'season_top3'
             AND sr.board = r.rule ->> 'board'
             AND sr.final_rank <= 3
        ),
        new_grants AS (
            INSERT INTO skin_ownership (user_id, skin_id, source)
            SELECT DISTINCT q.user_id, q.skin_id, 'earned'
            FROM qualifying q
            ON CONFLICT (user_id, skin_id) DO NOTHING
            RETURNING user_id, skin_id
        )
        SELECT ng.user_id, ng.skin_id, s.name AS skin_name
        FROM new_grants ng
        JOIN skins s ON s.id = ng.skin_id
    LOOP
        granted := granted + 1;
        BEGIN
            PERFORM net.http_post(
                url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
                       || '/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
                ),
                body := jsonb_build_object(
                    'user_ids', jsonb_build_array(g.user_id),
                    'kind', 'skin_unlocked',
                    'skin_id', g.skin_id,
                    'skin_name', g.skin_name
                )
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END LOOP;

    RETURN granted;
END;
$$;

REVOKE ALL ON FUNCTION public.evaluate_earned_skins() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.evaluate_earned_skins() FROM anon, authenticated;

-- Daily at 00:20 UTC — after finalize_season (00:02, migration 015) so fresh
-- season placements convert to skins the same morning. Idempotent reschedule.
SELECT cron.unschedule('evaluate-earned-skins-daily')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'evaluate-earned-skins-daily');

SELECT cron.schedule(
    'evaluate-earned-skins-daily',
    '20 0 * * *',
    $$ SELECT public.evaluate_earned_skins(); $$
);

-- ── delete_account_data: add skin_ownership (013/014 contract) ───────────────
-- Belt-and-braces as before: the FK cascades off auth.users, but the explicit
-- delete keeps the whole wipe in one transaction. active_skin_id dies with the
-- profile row.
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
    -- Cosmetics.
    DELETE FROM skin_ownership WHERE user_id = target;
    -- Billing, leaderboard, profile.
    DELETE FROM subscriptions      WHERE user_id = target;
    DELETE FROM leaderboard_scores WHERE user_id = target;
    DELETE FROM user_profiles      WHERE user_id = target;
END;
$$;
