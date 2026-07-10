-- ─────────────────────────────────────────────────────────────────────────────
-- 010 — Scheduled jobs (pg_cron + pg_net)
--
-- Without these, compute-leaderboard never runs (so leaderboard_scores stays
-- empty and every user — including the new rank badges — shows "Unranked"), and
-- schedule-notifications never fires.
--
-- Secrets are NOT committed. Before/after applying this migration, store two
-- values in Supabase Vault (Dashboard → Project Settings → Vault, or SQL):
--
--   select vault.create_secret('https://<PROJECT_REF>.supabase.co', 'project_url');
--   select vault.create_secret('<YOUR_CRON_SECRET>',                 'cron_secret');
--
-- <YOUR_CRON_SECRET> must match the CRON_SECRET set on the edge functions.
-- The cron jobs read these from vault at run time, so this file stays secret-free
-- and safe to commit.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Idempotent: drop prior definitions so re-applying this migration is safe.
SELECT cron.unschedule('compute-leaderboard-hourly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'compute-leaderboard-hourly');
SELECT cron.unschedule('schedule-notifications-hourly')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'schedule-notifications-hourly');

-- Recompute leaderboard scores every hour on the hour.
SELECT cron.schedule(
    'compute-leaderboard-hourly',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
               || '/functions/v1/compute-leaderboard',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Notification dispatcher runs hourly; the function itself decides what to send
-- based on the current UTC hour (08:00 morning, 09:00 streak, 19:00 evening).
SELECT cron.schedule(
    'schedule-notifications-hourly',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
               || '/functions/v1/schedule-notifications',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
        ),
        body := '{}'::jsonb
    );
    $$
);
