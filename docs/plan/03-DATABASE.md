# 03 — Database Schema
## MyGymBro — Drift (local) + Supabase (cloud)

Two stores kept in sync:
- **Drift (SQLite)** — on-device working store. Schema **v12**.
- **Supabase (Postgres + RLS)** — durable/shared backend.

**Universal sync columns** (every user-owned table, both stores): `localId/id`, `remoteId`, `syncStatus`, `createdAt`, `updatedAt`, `deletedAt` (soft delete).

---

## 1. Drift (Local) — Current Tables (v17)

| Table | Key columns | Notes |
|-------|-------------|-------|
| **UserProfiles** | localId, remoteId, displayName, **username** (v17), goal, experience, gender, bodyWeightKg, heightCm, fcmToken, **subscriptionStatus**, subscriptionExpiresAt, **notificationTone**, syncStatus | One row; the user. |
| **Friendships** (v17) | localId, remoteId, requesterId, addresseeId, status ('pending'\|'accepted'\|'blocked'), blockedBy, respondedAt, syncStatus | Cache of every edge the user is a side of; mirrors Supabase `friendships`. |
| **Exercises** | localId, exerciseId (unique), name, bodyParts, targetMuscles, difficulty, isCustom, isFavorite, usageCount | Seeded from `assets/exercises.json`. |
| **Schedules** | localId, name, isActive, syncStatus | One active at a time. |
| **ScheduleDays** | localId, scheduleId (FK), dayIndex, label, isRestDay | |
| **ScheduledExercises** | localId, scheduleDayId (FK), exerciseId, targetSets, targetReps, targetDurationSeconds, targetDistance | Cardio targets supported. |
| **Sessions** | localId, scheduleId (FK), startedAt, finishedAt, durationSeconds, **totalVolume**, notes | A workout instance. |
| **SessionExercises** | localId, sessionId (FK), exerciseId, orderIndex | |
| **WorkoutSets** | localId, sessionExerciseId (FK), weight, reps, isWarmup, isDropset, isFailure, isCompleted, rpe, durationSeconds, distance, speed, incline | |
| **SyncQueue** | localId, syncTableName, rowId, operation, payload(JSON), isSynced | Offline outbox. |
| ~~**DmMessages**~~ | — | ✅ Removed — table dropped in Drift v13, leftover `dm*` strings purged 2026-08-16. |

**Migration history of note:** v7 cardio, v9 favorites, v11 completion tracking, v12
biometrics, v13 DM drop, v15 follows cache, **v17 friendships + username (drops the
follows cache — the one-way follow model was superseded, PRD §5.6)**.

### 1.1 Drift — New Tables to Add (v13+)
> Bump `schemaVersion` and add a migration step per change. Regenerate `.g.dart`.

| Table | Key columns | For |
|-------|-------------|-----|
| ~~**Follows**~~ | — | ~~Followers (one-way)~~ **Superseded + dropped in v17** — replaced by `Friendships` (see §1). |
| **SkinOwnership** | localId, remoteId, skinId, source ('earned'/'purchased'), acquiredAt | Owned skins; drives gallery. |
| **ActiveSkin** | (store on UserProfiles instead) `activeSkinId` column | Currently selected skin. |
| **ChallengeParticipation** | localId, remoteId, challengeId, joinedAt, progress, completedAt, pointsAwarded | Local mirror of joined challenges. |
| **LeaderboardCache** | localId, scope ('global'/'friends'/'rivals'), board ('all_time'/'weekly'/'monthly'), rank, score, snapshotAt | Optional: cache last-fetched standings (all scopes) for offline display. |
| **UserReports** | localId, remoteId, periodType, periodStart, periodEnd, metrics(JSON), deltas(JSON) | Cache of weekly/monthly reports so the Reports window works offline. |

**Column additions for wearables (v1):** `Sessions` gains `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal` (nullable; populated from Health/Fit when permission granted). Mirror on Supabase `sessions`. Bump Drift `schemaVersion` + migration.

> Leaderboard standings and challenge catalogs are primarily **server-computed**; local tables are caches/mirrors so the UI degrades offline.

---

## 2. Supabase (Cloud) — Current Tables

From `001_initial_schema.sql` (+ 002/003/004). **RLS enabled on all user-scoped tables** (`auth.uid() = user_id`).

| Table | Key columns | RLS / notes |
|-------|-------------|-------------|
| **user_profiles** | id(UUID), user_id→auth.users, display_name, avatar_url, banner_url, goal, experience, gender, **trial_started_at**, **subscription_status**, fcm_token, **notification_tone** | Owner CRUD. `notification_tone` added in `004`. |
| **schedules / schedule_days / scheduled_exercises** | user_id on each, FK tree | Owner CRUD. |
| **sessions / session_exercises / sets** | user_id, workout data, completed_at | Owner CRUD. |
| **subscriptions** | user_id(unique), status, product_id, expiration_date, is_sandbox | Written by webhook (service role). |
| ~~**posts / post_likes / post_comments**~~ | — | ✅ **Dropped in `013_drop_community_feed.sql`** (feed cancelled 2026-08-15; `community-images` bucket removed; `delete_account_data` rewritten for the new schema). |
| **notification_templates** | id, category, tone columns, locale | Global read-only seed (18 templates). |
| **exercises** | shared catalog | All authenticated read; writes service-role only (`002`). |
| ~~**dm_conversations / dm_messages**~~ | — | ✅ Resolved — these tables were never created in the repo's migrations (001 has no DM DDL; there is no `003_dm_rls.sql`), so no drop was needed. |

**Helpers/triggers:** `has_active_subscription(uid)`; `updated_at = now()` trigger on all tables; Storage bucket `community-images` with per-user folder RLS.

---

## 3. Supabase — New Tables to Add

> Each via a new numbered migration with RLS. Add indexes on FKs and query columns.

### 3.1 Social: friendships *(REDESIGNED 2026-08-15 — replaces the `follows` design; PRD §5.6)*

> ✅ **Authored as `supabase/migrations/012_friendships.sql` (2026-08-15) — not yet
> deployed** (see SETUP-STATUS). 012 hardens this sketch; its header lists the
> deviations: symmetric pair-unique index (blocks A→B/B→A duplicates), blocked rows
> touchable only by their blocker, constrained update transitions + a pair-lock
> trigger, INSERT of a born-'blocked' row (pre-emptive stranger block), and a
> `sessions_select_friends` policy (groundwork for the bros activity strip).
> `public_profiles` now exposes `username` + `friend_count` and dropped the
> follower/following counts.
```
friendships (
  id uuid pk default gen_random_uuid(),
  requester_id uuid not null references auth.users,  -- who sent the request
  addressee_id uuid not null references auth.users,  -- who received it
  status text not null default 'pending',            -- pending | accepted | blocked
  blocked_by uuid references auth.users,             -- set when status = 'blocked'
  created_at timestamptz default now(),
  responded_at timestamptz,
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
)
```
- **RLS:** insert where `requester_id = auth.uid()` (and no existing blocked row between the pair); update/delete where `auth.uid()` is requester or addressee (addressee accepts/declines, either side blocks); select where `auth.uid()` is either side.
- **Username:** add unique `username text` (lowercase, 3–20 chars) to `user_profiles`; exact-match lookup only — no name search.
- **Friends = accepted rows.** Expose a `friends` view (both directions of accepted, excluding blocked) — used by the Friends leaderboard scope, the bros activity strip, and `friend_count`.
- **Reports:** `user_reports(reporter_id, reported_id, reason, created_at)`, insert-only via RLS, reviewed manually.
- The old `follows` table design is superseded; if it was ever created in an environment, the Phase B migration drops it.

### 3.2 Challenges

> **Status (014_challenges.sql — authored 2026-08-16, not deployed):** shipped
> as specced below plus: a server-only `challenge_templates` pool +
> `seed_daily_challenge()` (pg_cron `5 0 * * *`, also flips `active→ended`;
> one curated challenge per UTC day, idempotent); goal_type gains `'sets'`;
> award + moderation are **DB triggers** (allowed "or DB trigger"), with
> anti-cheat hardening: `challenge_id` immutable on UPDATE, `points_awarded`/
> `completed_at` always recomputed server-side, awards locked once granted,
> 48 h receipt deadline after `ends_at`, community points ≤ 50/challenge +
> `goal_value ≥ 1`, self-created challenges pay 0. Launch moderation policy:
> community rows land **'active'**; ≥ 3 distinct reporters auto-hide
> (`pending_review` kept in the enum for a later pre-approval policy);
> admin review via the `challenge_review_queue` view. Visibility is
> block-aware (no challenges/participation across a blocked pair).
> Completion push rides the `trg_notify_challenge_completion` trigger →
> pg_net → `notify-social-challenge` (best-effort, Vault-gated).
> `delete_account_data` was extended for the three challenge tables.
> Client cache: Drift v18 `challenges` + `challenge_participants` mirrors.

```
challenges (
  id uuid pk,
  source text check (source in ('curated','community')),
  creator_id uuid references auth.users,  -- null for curated
  title text, description text,
  goal_type text,            -- e.g. 'volume','sessions','streak','custom'
  goal_value numeric,
  starts_at timestamptz, ends_at timestamptz,
  points integer default 0,  -- points awarded on completion
  status text check (status in ('active','ended','hidden','pending_review')) default 'active',
  created_at timestamptz default now()
)

challenge_participants (
  id uuid pk,
  challenge_id uuid references challenges,
  user_id uuid references auth.users,
  progress numeric default 0,
  completed_at timestamptz,
  points_awarded integer default 0,
  unique (challenge_id, user_id)
)

challenge_reports (            -- moderation
  id uuid pk,
  challenge_id uuid references challenges,
  reporter_id uuid references auth.users,
  reason text,
  created_at timestamptz default now()
)
```
- **RLS:** read challenges = any active subscriber; community-created insert = `creator_id = auth.uid()` and lands as `pending_review` or `active` per moderation policy; participants insert/update where `user_id = auth.uid()`; reports insert = any subscriber.
- **Moderation:** a community challenge with enough reports flips to `hidden`; manual review path (admin via service role / dashboard).

### 3.3 Skins
```
skins (                       -- catalog (could also be a static client map)
  id text pk,                 -- e.g. 'carbone','gold','galaxy'
  name text, gender text,     -- asset variants resolved client-side
  acquisition text check (acquisition in ('default','earnable','purchasable')),
  product_id text,            -- RevenueCat product for purchasable
  unlock_rule jsonb           -- for earnable: {type:'streak', value:30} etc.
)

skin_ownership (
  id uuid pk,
  user_id uuid references auth.users,
  skin_id text references skins,
  source text check (source in ('default','earned','purchased')),
  acquired_at timestamptz default now(),
  unique (user_id, skin_id)
)
```
- **RLS:** `skins` global read; `skin_ownership` owner read, inserts via server (purchase verification / earn rule evaluation) to prevent spoofing.
- `user_profiles.active_skin_id` stores the selected skin.

### 3.4 Leaderboard (server-computed)

> **Status (008_leaderboard.sql — shipped):** `leaderboard_scores` exists with
> raw + normalised components, computed by the SQL function
> `compute_leaderboard_scores()` (called from the `compute-leaderboard` edge
> function on a cron). RPCs `leaderboard_global` / `leaderboard_friends` /
> `leaderboard_rivals` serve the three scopes. Deviations from the plan below:
> ~~challenge points are 0 until the challenges backend ships~~ **resolved by
> 014**: `compute_leaderboard_scores()` now sums window `points_awarded`
> (excluding hidden and self-created challenges, community-sourced capped at
> 100/window) and the composite is the three-way average; Rivals is a read-time ±5 window around the caller's
> global rank instead of stored pods (§3.4a can replace it later without
> changing the RPC shape); `season_winners` / finalize job not yet built.
> Anti-cheat: volume is recomputed server-side from `sets` with per-set
> plausibility caps (≤500 kg, ≤60 reps, ≤6000 kg·reps) — the client-reported
> session total is never trusted.

Leaderboard is **derived**, not a hand-edited table. Recommended:
```
leaderboard_scores (          -- materialized per user per board, current season
  user_id uuid references auth.users,
  board text check (board in ('all_time','weekly','monthly')),
  season_start date,          -- start of the current season (null for all_time)
  streak_norm numeric,        -- 0..100
  volume_norm numeric,        -- 0..100
  points_norm numeric,        -- 0..100
  composite numeric,          -- avg(streak_norm, volume_norm, points_norm)
  global_rank integer,        -- rank within the Global scope
  computed_at timestamptz default now(),
  primary key (user_id, board)
)

season_winners (              -- history of crowned winners (achievements/skins)
  id uuid pk default gen_random_uuid(),
  scope text check (scope in ('global','friends','rivals')),
  board text check (board in ('weekly','monthly')),
  season_start date, season_end date,
  user_id uuid references auth.users,
  rank integer, composite numeric,
  recorded_at timestamptz default now()
)
```
- **Seasons, not rolling windows:** `weekly`/`monthly` composites are computed from data **since `season_start`** (Monday / 1st), not a rolling trailing window. `all_time` uses all data and never resets.
- Populated by a scheduled edge function (see `04-BACKEND.md`). A **reset/finalize job** at each boundary writes `season_winners` (per scope), fires "season ended" pushes, then advances `season_start`.
- **RLS:** read = any active subscriber; no client writes. `season_winners` read = any subscriber.
- Indexes: `(board, composite desc)` for global ranking, `(board, global_rank)` for fetch; `season_winners(scope, board, season_start)`.
- **Global scope** = ranked by `global_rank`.
- **Friends scope** = computed per viewer: take the viewer's `friends` (mutual follows, §3.1 view), join their `leaderboard_scores.composite` for the chosen board, and rank within that subset at query time (no separate stored table). A `leaderboard_friends(viewer_id, board)` RPC/function returns the ranked friend rows + the viewer's own position.
- **Rivals scope** = a weekly auto-matched cohort of similar users (see below).

### 3.4a Rivals (auto-matched pods)
```
rival_pods (
  id uuid pk default gen_random_uuid(),
  period_start date,            -- weekly refresh
  created_at timestamptz default now()
)

rival_pod_members (
  pod_id uuid references rival_pods,
  user_id uuid references auth.users,
  joined_at timestamptz default now(),
  primary key (pod_id, user_id)
)
```
- Populated weekly by the `assign-rivals` scheduled function (see `04-BACKEND.md`): users are bucketed by **similarity** — nearest `composite` (all-time board), refined by `experience` level and recent volume — into pods of ~10–20 (newcomers grouped together).
- A user belongs to exactly one current pod. The Rivals board ranks the pod by `composite` for the selected board window; a `leaderboard_rivals(board)` RPC returns the caller's pod ranked + own position.
- **RLS:** members can read their own pod's rows; no client writes.
- Pods are kept for the period so rivals don't churn on every score recompute.

---

### 3.5 Periodic Reports
```
user_reports (
  id uuid pk default gen_random_uuid(),
  user_id uuid references auth.users,
  period_type text check (period_type in ('weekly','monthly')),
  period_start date, period_end date,
  metrics jsonb,     -- { volume, sessions, prs, streak, muscle_balance, ... }
  deltas jsonb,      -- same keys, change vs previous period (▲/▼ values)
  created_at timestamptz default now(),
  unique (user_id, period_type, period_start)
)
```
- Generated by the `generate-reports` scheduled function (see `04-BACKEND.md`); a new report triggers a tone-aware push.
- **RLS:** owner read; inserts service-role only (server-computed).
- Optional Drift mirror `UserReports` (cache) so the Reports window renders offline.
- Indexes: `(user_id, period_type, period_start desc)` for the Reports list.

## 4. Schema Change Checklist

When adding/altering a table:
- [ ] Drift: add table/column, **bump `schemaVersion`**, add migration step, regenerate `.g.dart`.
- [ ] Supabase: new numbered migration in `supabase/migrations/`.
- [ ] **RLS policies** for every new table (default owner-only; premium reads via `has_active_subscription`).
- [ ] Indexes on FKs + filter/sort columns.
- [ ] Wire into `SyncService` (table name, payload shape, remote-id resolution).
- [ ] Update this doc + `04-BACKEND.md`.

---

## 5. DM Removal — ✅ DONE (closed 2026-08-16)

- Drift: `DmMessages` + `dm_dao.dart` dropped in v13.
- Supabase: nothing to drop — DM tables were never created in the repo's migrations.
- App: `lib/features/community/dm/**` deleted in v13-era work; the last remnants
  (22 `dm*` l10n keys × 4 ARBs, stale `.ai-codex` DM docs) purged 2026-08-16.
- The community feed tables went with the same cleanup: `013_drop_community_feed.sql`.

---

**End of Database Document**
