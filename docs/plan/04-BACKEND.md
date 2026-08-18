# 04 — Backend & Contracts
## MyGymBro — Supabase Edge Functions, Sync Protocol, Scoring

> The backend is **Supabase** (Postgres + RLS + Storage + Deno Edge Functions), not a bespoke REST server. The client talks to Postgres directly through the Supabase SDK (guarded by RLS) and calls **edge functions** for privileged/computed work.

---

## 1. Sync Protocol (client ↔ Postgres)

The app does **not** call custom CRUD endpoints — it uses the Supabase SDK against RLS-protected tables, via the offline outbox.

**Outbox item:** `{ syncTableName, rowId, operation: insert|update|delete, payload: <json row> }`

**Push algorithm (per item, oldest first):**
1. `insert` → `supabase.from(table).insert(payload)` → capture `id` → write back as local `remoteId` → mark synced.
2. `update` → resolve `remoteId` → `.update(payload).eq('id', remoteId)` → mark synced.
3. `delete` → resolve `remoteId` → soft-delete (`deletedAt`) or `.delete()` → mark synced.
4. If `remoteId` unresolved (parent not yet synced) → **defer**, retry next pass.
5. Backoff 1s/2s/4s, max 3 retries; cleanup synced rows.

**Rules for new tables (follows, challenge_participants, skin_ownership):** they ride the same outbox. Server-authoritative tables (`leaderboard_scores`, purchased `skin_ownership`) are **read-only to the client** and never enter the outbox.

---

## 2. Current Edge Functions *(built)*

| Function | Purpose |
|----------|---------|
| **verify-subscription** | Returns `{ status, expires_at }` from `subscriptions`; falls back to `trial_started_at` window if no row. |
| **revenuecat-webhook** | HMAC-SHA256-verified; maps RC events (INITIAL_PURCHASE→active, CANCELLATION→expired, BILLING_ISSUE→grace_period) → upserts `subscriptions`. |
| **schedule-notifications** | Cron (pg_cron): sends morning/evening/streak FCM pushes to users with active schedules + valid tokens; filters by weekday + session completion; batches ≤500. |
| **delete-account** | Cascading soft-delete of user data, then hard-delete auth user. |
| **notify-social-challenge** | Sends "new PR / challenge" FCM to active subscribers (except record holder); randomizes template. |
| **send-push-notification** | Generic FCM send (by user-id array or topic). |

---

## 3. New / Modified Edge Functions *(to build)*

### 3.1 `compute-leaderboard` (scheduled)

> **Status: shipped** (`supabase/functions/compute-leaderboard` +
> `migrations/008_leaderboard.sql`). The function authenticates via the
> `x-cron-secret` header (CRON_SECRET project secret) and delegates to the
> `compute_leaderboard_scores()` SQL function so all three boards recompute in
> one transaction. Current deviations: points component is 0 (challenges
> backend pending) so composite = avg(streak_norm, volume_norm); Rivals is a
> read-time rank-window RPC instead of pods; finalize-season not built yet.
> Client wiring: `lib/features/leaderboard/leaderboard_providers.dart` (weekly
> board), offline-safe (empty list without Supabase/auth).

Computes `leaderboard_scores` for all three boards.

**Scoring contract — composite = average of three normalized components:**

For each board (`all_time`; `weekly` = since this Monday; `monthly` = since the 1st) and each active subscriber:
1. **streak_raw** — current consecutive training-day (or week) streak within the window.
2. **volume_raw** — Σ(weight × reps) of completed sets within the window.
3. **points_raw** — Σ challenge `points_awarded` within the window.

Normalize each to **0–100** across the population (percentile or min-max; percentile preferred to resist outliers):
```
streak_norm  = percentile_rank(streak_raw)  * 100
volume_norm  = percentile_rank(volume_raw)  * 100
points_norm  = percentile_rank(points_raw)  * 100
composite    = (streak_norm + volume_norm + points_norm) / 3
rank         = row_number() over (order by composite desc)
```
- New users with no data → components default 0 → bottom of board (not hidden).
- `weekly`/`monthly` aggregate only data **since `season_start`** (not a rolling trailing window); `all_time` uses everything.
- Run cadence: every N minutes/hours (start hourly; tune). `all_time` can run less often.
- Write results to `leaderboard_scores` with `global_rank`; client reads top-N + own row for the **Global** scope.

### 3.1b `finalize-season` (scheduled, at each boundary)

> ✅ **Shipped in 015** (2026-08-17, not deployed): `finalize_season(board)`
> SQL fn on pg_cron (Wed 00:02 / the 3rd 00:02 UTC — 48 h after the boundary
> so 014's late-sync receipt window is fully honored) writes the FULL final
> standings of the closed window into `season_results` (idempotent on PK) —
> one snapshot serves global top-N, own placement, the Friends winner (join
> at read time), and Rivals pod winners; Phase 6 skins/achievements read it
> too. Scoring is the shared `score_board_window(start, end)` fn (008/014
> engine, window-parameterized) — needed because date_trunc has already
> rolled the live table by the time the boundary cron fires; that also makes
> "advance season_start" a no-op by construction. Top-3 pushes go via pg_net
> → `send-push-notification` `{kind:'season_ended'}`, tone-resolved there.
> Client banner reads the `leaderboard_last_winner(board, scope)` RPC.

Runs at the weekly (Monday 00:00) and monthly (1st) reset.
- For each scope (global / friends / rivals), snapshot the final standings of the ending season and write `season_winners` (at least the top placements; rivals = per-pod winners).
- Fire tone-aware "season ended — you placed Nth / you won!" pushes.
- Advance `season_start` so `compute-leaderboard` starts the new season from zero. (For rivals, the weekly pod reset is handled together with `assign-rivals`.)
- Hand winners/placements to `evaluate-earned-skins` (§3.4) and achievements.
- Use a single, fixed timezone (e.g. UTC) for season boundaries so everyone resets together; document it.

**Friends scope** is per-viewer and computed at read time (friend sets differ per user). Provide an RPC `leaderboard_friends(board)`:
```
-- ranks the caller's mutual-follow friends (+ the caller) by composite for the board
select user_id, composite,
       rank() over (order by composite desc) as friend_rank
from leaderboard_scores ls
where ls.board = $board
  and ls.user_id in (
        select friend_id from friends where user_id = auth.uid()
        union select auth.uid())
order by composite desc;
```
This reuses the same per-user `composite`, so no extra normalization or stored table is needed for Friends.

**Rivals scope** uses pre-assigned pods (`rival_pods` / `rival_pod_members`, `03-DATABASE.md` §3.4a). RPC `leaderboard_rivals(board)`:
```
-- ranks the caller's current rival pod by composite for the board
select m.user_id, ls.composite,
       rank() over (order by ls.composite desc) as rival_rank
from rival_pod_members m
join rival_pod_members me on me.pod_id = m.pod_id and me.user_id = auth.uid()
join leaderboard_scores ls on ls.user_id = m.user_id and ls.board = $board
order by ls.composite desc;
```

### 3.1a `assign-rivals` (scheduled, weekly)

> ✅ **Shipped in 015**: `assign_rivals()` SQL fn on pg_cron (Mon 00:10 UTC),
> pods of ~15 ordered by newcomer-status → experience → all-time composite →
> 30-day volume; idempotent per period via UNIQUE (user_id, period_start).
> `leaderboard_rivals()` REPLACED in place (same signature): ranks the
> caller's latest pod, falling back to 008's rank-window for pod-less users.

Builds the weekly rival pods.
- Order active subscribers by all-time `composite`; refine the similarity key with `experience` level and recent 30-day volume so pods group users of comparable level and progress.
- Slice the ordered/bucketed list into pods of ~10–20; newcomers (little/no data) form their own pods.
- Insert a new `rival_pods` row + `rival_pod_members` for the period (`period_start`). Each user belongs to exactly one current pod.
- Idempotent per `period_start`; pods persist for the week so rivals stay stable.

> **Why normalize:** raw volume dwarfs streak/points numerically. Percentile-normalizing each to 0–100 before averaging keeps the three components equally weighted, matching the product decision ("take the average of them").

### 3.2 `award-challenge-points` (or DB trigger)
When `challenge_participants.completed_at` is set, award `challenges.points` → `points_awarded`, and trigger `notify-social-challenge`. Idempotent (unique participant row).

> ✅ **Shipped as DB triggers in 014** (2026-08-16): `award_challenge_points`
> (BEFORE INSERT/UPDATE — server-derives completion + points, locks standing
> awards, `challenge_id` immutable, 48 h receipt deadline, creator self-award
> pays 0) and `trg_notify_challenge_completion` (AFTER, fires only on the
> NULL→set completion transition, pg_net → `notify-social-challenge` with
> `x-cron-secret`, best-effort). `notify-social-challenge` itself was
> rewritten: audience is now the `friends` view (the follows audience died
> with 012), dual entry (user JWT for PRs / cron-secret for the trigger, so
> `verify_jwt = false` in config.toml), challenge completions verified
> against `challenge_participants` before broadcasting, and messages are
> tone-resolved per recipient from `user_profiles.notification_tone`
> (in-function template sets; the §3.7 `notification_templates` tone columns
> remain future work). Curated seeding is `seed_daily_challenge()` SQL +
> pg_cron — no edge function needed.

### 3.3 `purchase-skin` / verify
On a RevenueCat one-time skin purchase, verify the entitlement/receipt server-side and insert `skin_ownership(source='purchased')`. Prevents client-spoofed ownership.

> ✅ **Authored 2026-08-17 (not deployed).** User-JWT function (`verify_jwt`
> stays on). Ignores any client-asserted product: it fetches the caller's
> RevenueCat subscriber (`REVENUECAT_SECRET_KEY`, a *secret* API key — new
> function secret, see SETUP-STATUS) and grants EVERY purchasable skin whose
> product appears in `non_subscriptions` — so one endpoint serves purchase,
> restore, and reinstall, idempotent on `(user_id, skin_id)`. Returns the full
> ownership snapshot for the client mirror. 503 while the secret is unset
> (client degrades to local unlock). Accepted gap: RC v1 keeps refunded
> purchases, so a refund still verifies as owned (webhook/v2-only signal).
> Products: `mgb_skin_gold` / `mgb_skin_galaxy` / `mgb_skin_teddy_bear`.

### 3.4 `evaluate-earned-skins` (scheduled or on-event)
Evaluates `skins.unlock_rule` against user stats (streak length, leaderboard placement, challenge completions) and inserts `skin_ownership(source='earned')`. Fires a "skin unlocked" push.

> ✅ **Shipped as SQL + pg_cron in 016** (the 014/015 precedent — no edge
> function): `evaluate_earned_skins()` daily at 00:20 UTC, after
> finalize_season. New grants push through `send-push-notification`
> (`kind: skin_unlocked`, tone-resolved per recipient, best-effort). Run it
> once at deploy so existing users get session-based grants immediately.

### 3.5 `moderate-challenges` (scheduled or trigger)
Counts `challenge_reports` per challenge; flips to `hidden` past a threshold; surfaces a review queue (admin via service role).

> ✅ **Shipped as a trigger in 014**: AFTER INSERT on `challenge_reports`,
> hides a community challenge at ≥ 3 distinct reporters (UNIQUE
> (challenge, reporter) makes the count people, not clicks). Review queue =
> `challenge_review_queue` view, service-role only.

### 3.6 `generate-reports` (scheduled)

> ✅ **Shipped as SQL + pg_cron in 017** (2026-08-18, the 014–016 precedent —
> no edge function): `generate_progress_reports()` weekly (Wed 00:15 UTC) +
> monthly (3rd 00:15) — 48 h after the boundary for offline late-syncs —
> table named `progress_reports` (see 03-DATABASE §3.5 status note),
> subscriber-gated, skips users with no sessions in the window, pushes
> `kind: report_ready` through `send-push-notification` (tone-resolved) for
> new rows only. ⚠️ Inert until the client pushes workout data at all — see
> the blocker in SETUP-STATUS (sessions/sets never sync up today).

Generates weekly + monthly progress reports.
- **Weekly:** runs on a fixed weekday; aggregates the user's last 7 days vs. the prior 7.
- **Monthly:** runs at month end; aggregates the month vs. the prior month.
- Computes `metrics` (volume, sessions, PRs, streak, muscle balance) and `deltas` (change vs. prior period), inserts a `user_reports` row (idempotent on `(user_id, period_type, period_start)`).
- On insert, sends a **tone-aware** push ("Your weekly report is ready — volume ▲12%…") via FCM.
- Only for active subscribers with enough history; skip users with no sessions in the window.

### 3.7 Tone-resolved push (modify existing)
`schedule-notifications`, `notify-social-challenge`, `send-push-notification` must **resolve tone at delivery time**: join `user_profiles.notification_tone`, pick the matching column from `notification_templates` (`tone_supportive/balanced/bold/savage`), fall back to `balanced`. Localize where applicable.

---

## 4. Community Feed — **REMOVED (2026-08-15, PRD §5.8)**

The feed is cut. No `SupabaseCommunityRepository` will be built. Dormant `posts` / `post_likes` / `post_comments` tables and the `community-images` bucket get dropped in a cleanup migration (pre-launch, no user data).

---

## 5. Friends / "Bros" (client contracts) *(REDESIGNED 2026-08-15 — was one-way followers; PRD §5.6)*

> ✅ **Client side built 2026-08-15** (Bros Phase B): `FriendRepository` +
> `friend_providers.dart` (features/social), `FriendshipDao`, Drift v17 cache,
> outbox-synced ops, pull via `refreshFromServer()` (drains outbox, then snapshots
> rows where I'm a side). Server migration `012_friendships.sql` authored, **not
> deployed** (SETUP-STATUS). Implementation notes on top of the contract below:
> the @username **claim is deliberately online-only** (global uniqueness — a queued
> offline claim could silently lose the race; lookup/search are online too);
> decline/cancel/unfriend/unblock are hard DELETEs of the edge (per this contract)
> while all other writes are offline-first; a block with no existing row INSERTs a
> born-'blocked' row; "blocked by them" is reported to the UI as `none` (discreet
> blocking). No realtime — a new incoming request appears on the next graph refresh
> (Bros sheet open / pull).

- **Request:** insert `friendships(requester_id=me, addressee_id=target, status='pending')` (outbox-synced).
- **Accept / decline:** addressee updates status to `accepted` / deletes the row.
- **Block:** either side sets `status='blocked'` (blocker recorded); blocked pairs are invisible both ways and can't re-request. **Report** goes to a `user_reports` table for review.
- **Lookup:** exact-match on unique `user_profiles.username` (lowercase); invite link/QR encodes the username. No name search endpoint.
- **Counts:** `friend_count` from accepted rows (view or maintained column).
- **Profile fetch:** `user_profiles` (public-safe columns) + friend count + achievements + streak (no posts). Profile shows relationship state (none / pending out / pending in / bros / blocked).
- **Activity strip:** "Latest from your bros" reads friends' recent session summaries (already synced `sessions` rows) — no new content type, no free text.

---

## 5a. Wearables / Health (client-side)

- Health data is read/written **on-device** via the `health` package (HealthKit / Health Connect) — there is **no dedicated backend** for it.
- Imported metrics that the user already syncs (avg/max HR, active energy) land on `Sessions` (Drift) and ride the normal sync outbox to Supabase `sessions`.
- Raw Health records are **not** uploaded; only derived per-session metrics. No advertising use (store policy).

## 6. Storage

| Bucket | Contents | Access |
|--------|----------|--------|
| `community-images` | Post images | Authenticated upload/read, per-user folder RLS |
| `avatars` (add) | Profile avatars/banners | Owner write, public read |

---

## 7. Push & Tokens

- FCM token stored on `user_profiles.fcm_token` (and Drift `UserProfiles.fcmToken`).
- All sends go through edge functions using the service role + FCM credentials (server secret).
- Respect tone + locale; never include PII in payload beyond what's needed.

---

## 8. Security & RLS Summary

- Every user-owned table: owner-only CRUD via `auth.uid()`.
- Premium reads (feed, challenges, leaderboard): require `has_active_subscription(auth.uid())`.
- Server-authoritative tables (`subscriptions`, `leaderboard_scores`, purchased `skin_ownership`): no client writes — service role only.
- Webhooks verify signatures (RevenueCat HMAC). Edge functions validate input and never trust client-asserted entitlements.

---

## 9. Backend Build Checklist (per new function/table)

- [ ] Migration + RLS committed.
- [ ] Edge function input-validated, service-role scoped, idempotent where needed.
- [ ] Wired into client (SDK call or outbox).
- [ ] Tone + locale respected for any user-facing copy.
- [ ] Indexes for ranking/pagination.
- [ ] Documented here + in `03-DATABASE.md`.

---

**End of Backend Document**
