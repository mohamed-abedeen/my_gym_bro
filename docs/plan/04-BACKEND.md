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
Builds the weekly rival pods.
- Order active subscribers by all-time `composite`; refine the similarity key with `experience` level and recent 30-day volume so pods group users of comparable level and progress.
- Slice the ordered/bucketed list into pods of ~10–20; newcomers (little/no data) form their own pods.
- Insert a new `rival_pods` row + `rival_pod_members` for the period (`period_start`). Each user belongs to exactly one current pod.
- Idempotent per `period_start`; pods persist for the week so rivals stay stable.

> **Why normalize:** raw volume dwarfs streak/points numerically. Percentile-normalizing each to 0–100 before averaging keeps the three components equally weighted, matching the product decision ("take the average of them").

### 3.2 `award-challenge-points` (or DB trigger)
When `challenge_participants.completed_at` is set, award `challenges.points` → `points_awarded`, and trigger `notify-social-challenge`. Idempotent (unique participant row).

### 3.3 `purchase-skin` / verify
On a RevenueCat one-time skin purchase, verify the entitlement/receipt server-side and insert `skin_ownership(source='purchased')`. Prevents client-spoofed ownership.

### 3.4 `evaluate-earned-skins` (scheduled or on-event)
Evaluates `skins.unlock_rule` against user stats (streak length, leaderboard placement, challenge completions) and inserts `skin_ownership(source='earned')`. Fires a "skin unlocked" push.

### 3.5 `moderate-challenges` (scheduled or trigger)
Counts `challenge_reports` per challenge; flips to `hidden` past a threshold; surfaces a review queue (admin via service role).

### 3.6 `generate-reports` (scheduled)
Generates weekly + monthly progress reports.
- **Weekly:** runs on a fixed weekday; aggregates the user's last 7 days vs. the prior 7.
- **Monthly:** runs at month end; aggregates the month vs. the prior month.
- Computes `metrics` (volume, sessions, PRs, streak, muscle balance) and `deltas` (change vs. prior period), inserts a `user_reports` row (idempotent on `(user_id, period_type, period_start)`).
- On insert, sends a **tone-aware** push ("Your weekly report is ready — volume ▲12%…") via FCM.
- Only for active subscribers with enough history; skip users with no sessions in the window.

### 3.7 Tone-resolved push (modify existing)
`schedule-notifications`, `notify-social-challenge`, `send-push-notification` must **resolve tone at delivery time**: join `user_profiles.notification_tone`, pick the matching column from `notification_templates` (`tone_supportive/balanced/bold/savage`), fall back to `balanced`. Localize where applicable.

---

## 4. Community Feed (replace mocks)

Client uses the Supabase SDK directly (tables + RLS already exist):
- **Feed:** `posts` join `post_likes`/`post_comments` counts; paginate by `created_at desc`. Reads gated by `has_active_subscription`.
- **Compose:** upload image to Storage `community-images/<uid>/...` → insert `posts` row with `image_url`.
- **Like/Comment:** insert/delete `post_likes`; insert `post_comments`.
- Replace `MockCommunityRepository` with `SupabaseCommunityRepository`; keep the same interface so the UI is untouched.

---

## 5. Followers (client contracts)

- **Follow:** insert `follows(follower_id=me, followee_id=target)` (outbox-synced).
- **Unfollow:** delete the row.
- **Friends:** derived — a friend is a mutual follow (read via the `friends` view, `03-DATABASE.md` §3.1). No explicit accept step. Friend count = rows in `friends` for the user.
- **Counts:** read from a `user_profiles` view exposing `follower_count`/`following_count` (+ `friend_count`), or maintained columns updated by trigger on `follows`.
- **Profile fetch:** `user_profiles` (public-safe columns) + counts + recent `posts` + achievements + streak. Profile shows a relationship state (not following / following / **friends** when mutual).

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
