# 06 — Implementation Plan
## MyGymBro — Current-State Audit + Phase-by-Phase Finish Roadmap

> The foundation is built. This plan takes the app from ~70% to **v1 ship**. Each phase is independently shippable-ish and ordered by dependency and risk.

---

## 0. Current-State Audit

Honest assessment of what exists today.

### ✅ DONE (production-ready)
- **Local DB (Drift v12):** 10 tables, full sync/audit columns, live migrations.
- **Supabase backend:** 12+ tables, RLS everywhere, soft-delete + `updated_at` triggers, Storage, 6 edge functions.
- **Offline sync:** working outbox, deferred remote-id resolution, backoff. *(Old empty-`{}` payload bug is fixed.)*
- **Auth & DI:** Supabase auth + OAuth, RevenueCat login, graceful offline fallback (nullable clients).
- **Monetization plumbing:** RevenueCat purchase/restore + webhook upsert + `verify-subscription`. **Purchase flow works.**
- **Workout core:** active session, set logging (RPE/warmup/dropset/failure/cardio), rest timer (persistent + actionable), log/status sheets.
- **Schedule builder & exercise browser:** multi-day programs, 3 seeded programs, filtering/favorites/recents, exercise detail.
- **Design system:** complete liquid-glass component family, theming, navigation shell.

### 🟡 PARTIAL (finish for v1)
- **Anatomy body:** recovery coloring works; **no volume view**; transitions/posterior view minimal. (Skins: 14 wired in `skin_provider.dart` — picker works, but no ownership/earn/buy economy.)
- **Paywall gate:** exists in `my_gym_bro_scaffold.dart:63-71` (trial-expiry/expired → push paywall) but is a dismissible `push`, not a hard block — needs hardening + a single shared guard.
- **Localization:** de/es/fr ≈77% (≈84 keys missing each).
- **Notifications:** tone system + rest timer solid; **force-kill resilience** deferred; reminder scheduling needs verification.
- **Profile / Settings:** profile renders metrics/anatomy but **no followers / no public-profile view**; settings UI incomplete.

### 🔴 NOT BUILT / MOCK (build for v1)
- **Skins economy** — 14 skins are *selectable* but there's no ownership/earn/purchase/persistence (every skin free; selection not saved).
- **Community feed** — REMOVED 2026-08-15 (Bros Phase A); client UI deleted, dormant tables pending a cleanup migration.
- **Leaderboard** — hardcoded rows; no scoring, no backend.
- **Friends ("bros") graph** — does not exist yet (Bros Phase B; the followers design was scrapped 2026-08-15).
- **Challenges** — mock; no curated/community backend, no moderation.
- **Progress charts** — not built.
- **Share cards** — not built.
- **Friends leaderboard** — needs mutual-follow detection + per-viewer ranking (Global scope alone insufficient).
- **Rivals leaderboard** — weekly auto-matched pods of similar users; matching + ranking not built.
- **Periodic reports** — weekly/monthly improvement reports (push + Workout→Status→Reports) not built.
- **Training calendar** — Home day-strip tap → calendar of worked days/sessions not built.
- **Light-mode accent** — lime is hardcoded; light mode needs an orange accent token (text, selected nav icon, Start Workout button, streak icon).
- **Wearables / Health** — no Apple Health/Watch or Google Fit/Health Connect integration yet.

### ⚠️ REMOVE
- **DM subsystem** — `lib/features/community/dm/**` (9 files), Drift `DmMessages` + `dm_dao.dart`, Supabase `dm_*` tables + `003_dm_rls.sql`, and any schedule-share-via-DM references.

---

## Phase Overview

| Phase | Theme | Unblocks |
|-------|-------|----------|
| 1 | Monetization gate + DM removal + cleanup | Revenue, smaller surface |
| 2 | Friends ("bros") graph + public profiles (Bros Phase B) | Leaderboard rows, bros identity |
| 3 | ~~Community feed backend~~ **CANCELLED 2026-08-15** | — |
| 4 | Challenges (curated + member-created; Bros Phase C) + moderation | Challenge points |
| 5 | Leaderboard (composite scoring; Global + Friends + Rivals) | Competition loop |
| 6 | Anatomy volume + skins + charts + reports + calendar + share cards + light-mode accent + l10n | Engagement complete |
| 7 | Wearables (Apple Health/Watch, Google Fit/Health Connect) | Health sync, live HR |
| 8 | Release prep | Ship |

> **Apple Developer account** is a hard prerequisite for APNs, Live Activities, IAP testing on device, and App Store submission. Set it up early (see `07-SETUP.md`); it gates final monetization/notification verification and release.

---

## 🚪 Phase 1 — Monetization Gate, DM Removal, Cleanup

**Goal:** the paywall actually gates the app; dead DM code is gone.

### Deliverables *(audited + gap-filled 2026-08-16)*
- [x] **Paywall gate:** `subscriptionLockedProvider` (single source of truth) + GoRouter redirect with `refreshListenable`; trial-elapsed locks; `kBetaFreeAccess` kill switch; **bounded offline grace** — `active`/`grace_period` honored until 30 days past the last known expiry, then locked (airplane-mode-forever is not a free subscription).
- [x] Wire `verify-subscription` + `SubscriptionSyncService` on app start (main.dart), resume (scaffold lifecycle observer), post-purchase/restore (paywall), and explicitly after sign-in (auth_notifier).
- [x] Trial countdown surfaced in UI: Settings pill + Home banner (frosted, tap → paywall). Fixed the duplicate `trialDaysLeft` ARB key that made en render a different string shape than de/es/fr.
- [x] **Restore Purchases** (`SubscriptionSyncService.restore`) now a direct Settings row AND on the paywall; **Delete Account** from Settings → `delete-account` edge fn + local wipe.
- [x] **Remove DMs:** client code/tables were already gone (Drift v13); purged the 22 leftover `dm*` keys × 4 ARBs and the stale `.ai-codex` DM docs. Server-side there were never DM tables — nothing to drop.
- [x] Community feed server-side cleanup (`013_drop_community_feed.sql`, NOT deployed): drops `posts`/`post_likes`/`post_comments` + `community-images` bucket/policies, and **rewrites `delete_account_data`** (it still referenced posts and the 012-dropped `follows` — left alone, account deletion would fail).
- [x] Offline behavior verified in tests: active subscriber offline stays in (≤30d past expiry), expired/new users gated.

### Phase 1 Checklist
- [x] Expired user cannot use core features without subscribing/restoring (gate + redirect; unit-tested).
- [x] Trial users have full access with visible countdown (Home banner + Settings pill).
- [x] Restore + delete-account flows implemented + unit-tested; end-to-end against live RC/Supabase pending service setup (SETUP-STATUS).
- [x] No DM code/tables/strings remain; app compiles, `flutter analyze` clean.

---

## 👥 Phase 2 — Friends ("Bros") Graph + Public Profiles *(REDESIGNED 2026-08-15 — was Followers; see PRD §5.6)*

**Goal:** users add each other as bros (request → accept) and view real public profiles. This is **Bros Phase B**.

### Deliverables
- [x] Supabase `friendships` table (requester/addressee + `pending|accepted|blocked` status) + RLS; friend count via view — **authored as `012_friendships.sql`, NOT deployed (SETUP-STATUS)**.
- [x] Unique **@username** claim (lowercase, 3–20 chars) on `user_profiles` + exact-match lookup (claim/lookup are online-only by design; see 04-BACKEND §5).
- [x] **Invite link + QR** sheet — client + in-app `/bro/:username` route done; ⚠️ universal-link platform config (AASA/assetlinks) + App Store fallback page pending (SETUP-STATUS).
- [x] Requests inbox on the Bros tab (Bros sheet): accept / decline; badge on the 48pt add-bros header button.
- [x] **Block + report** from the request row, search hit, and the add-bro/profile card; blocking hides both directions (blocked side sees `none`).
- [x] Drift cache (v17) + sync wiring (outbox) for friendships; account deletion cleans the graph via `ON DELETE CASCADE`.
- [ ] Public profile fetch: profile + friend count done (`public_profiles` + `PublicProfile`); achievements + streak on it still pending.
- [ ] Profile screen: relationship states exist on the minimal add-bro card; the full §5.7 public profile (gendered anatomy, achievements, streak tabs) still pending.
- [x] Privacy: no global real-name search (exact @username only); public_profiles exposes only safe columns.

### Phase 2 Checklist
- [x] Request → accept flow works offline-queued and syncs (unit-tested in `test/friend_repository_test.dart`; live sync against cloud pending deploy).
- [ ] Friends power the Friends leaderboard scope + "Latest from your bros" strip (scope: view rebuilt server-side, verify after deploy; strip: `sessions_select_friends` RLS ready, strip UI not built).
- [x] Block/report works from every surface a stranger can reach (request row, search result, add-bro card).
- [ ] No private data leaks on public profiles — re-verify on the finished §5.7 profile screen.

---

## 📰 Phase 3 — Community Feed Backend — **CANCELLED (2026-08-15)**

The photo/text feed is cut (PRD §5.8). The client feed UI was deleted in Bros Phase A; the dormant `posts` / `post_likes` / `post_comments` tables + `community-images` bucket get dropped in a cleanup migration. The engagement job moves to the auto-generated bros activity strip (Phase B) and challenges (Phase 4 = Bros Phase C: duels, squad goals, open ladders, rate-limited nudges).

### Phase 3 Checklist
- [ ] Posting/liking/commenting persists and appears across accounts.
- [ ] Non-subscribers cannot read the feed (gate + RLS).
- [ ] Images upload and render (cached).

---

## 🏆 Phase 4 — Challenges (Curated + Community) + Moderation

**Goal:** real challenges that award points.

> **Status (2026-08-16): built offline, not deployed.** Migration
> `014_challenges.sql` + rewritten `notify-social-challenge` + Drift v18
> caches + `ChallengeRepository`/providers + Challenges tab UI (hero cards
> restored from history) + ARB ×4 + unit tests. Award/moderation run as DB
> triggers; curated seeding is SQL + pg_cron. Challenge points now feed the
> leaderboard composite (three-way average — the Phase 5 contract).
> Remaining: cloud deploy (SETUP-STATUS), then the checklist below against
> real accounts.

### Deliverables
- [x] Supabase `challenges`, `challenge_participants`, `challenge_reports` + RLS.
- [x] Curated daily challenge source (table + cron/edge seeding) — `challenge_templates` + `seed_daily_challenge()` on pg_cron.
- [x] Community challenge creation (lands `active`; report-threshold auto-hide is the launch policy, `pending_review` reserved).
- [x] Join + progress tracking; completion → `award_challenge_points` trigger → `points_awarded` + `notify-social-challenge`.
- [x] Moderation: report action; `moderate_challenges` trigger hides over-reported challenges; `challenge_review_queue`.
- [x] Challenges UI (Bros tab): curated daily + community list, join, progress, create, report.

### Phase 4 Checklist *(needs cloud deploy)*
- [ ] Curated daily challenge appears and is joinable.
- [ ] Users can create/join community challenges; reports hide abusive ones.
- [ ] Completing a challenge awards points (idempotent) and notifies.

---

## 📊 Phase 5 — Leaderboard (Composite Scoring)

**Goal:** a real Global leaderboard with all-time + rolling boards.

> **Status (2026-08-17): built offline, not deployed.** Migration
> `015_leaderboard_seasons.sql` (season_results snapshots, finalize_season +
> assign_rivals crons, pod-backed leaderboard_rivals, leaderboard_last_winner
> RPC, shared score_board_window engine), tone-resolved season push in
> send-push-notification, Drift v19 caches, board switch + countdown +
> winner banner + row-tap in the client. Deploy checklist in SETUP-STATUS.

### Deliverables
- [x] Supabase `leaderboard_scores` + indexes *(008)*.
- [x] `compute-leaderboard` scheduled function implementing the **composite = avg(streak_norm, volume_norm, points_norm)** contract (percentile normalization) for `all_time` / `weekly` / `monthly` **seasons** *(008 + 014 points + 015 shared engine; season windows are date_trunc-derived, so no stored season_start)*.
- [x] **Seasons:** `finalize_season` at weekly (Mon) + monthly (1st) UTC boundaries → full `season_results` snapshot, "season ended" push (top 3, tone-resolved); winners feed achievements/earned skins via `season_results` (Phase 6).
- [x] **Friends scope:** `leaderboard_friends(board)` RPC *(008)*.
- [x] **Rivals scope:** `rival_pods` / `rival_pod_members` + `assign_rivals` weekly matching; `leaderboard_rivals(board)` ranks the caller's pod (rank-window fallback for pod-less users). Weekly pod reset aligns with the weekly season.
- [x] Client: scope switch (was built with 008) + board switch (All-time / Weekly / Monthly); reset countdown + last-winner banner; offline cache (`LeaderboardCache` + `SeasonWinnerCache`, all scopes×boards).
- [x] Row tap → public profile (self → profile screen; others resolve @username → bro screen).

### Phase 5 Checklist
- [ ] Scores recompute on schedule; global ranks correct and stable.
- [ ] Weekly/monthly seasons reset on schedule, crown winners, and start fresh; all-time never resets.
- [ ] Friends board ranks only mutual friends (+ self) and is correct per viewer.
- [ ] Rivals pods assigned weekly group similar users; pod ranking correct; pods stable within the week.
- [ ] All three scopes × three boards switchable; reset countdown + last winner shown; user sees own position even outside top-N.
- [ ] No single component dominates (normalization verified with real-ish data).

---

## 🎨 Phase 6 — Anatomy Volume, Skins, Charts, Reports, Calendar, Share Cards, Accent, l10n

**Goal:** complete the visual/engagement features.

### 6.1 Anatomy Volume View
- [ ] Volume mode: color/annotate muscles by training volume over a window; Recovery|Volume toggle.
- [ ] Smooth state transitions; verify both genders.

### 6.2 Skins Economy
- [ ] `skins` catalog + `skin_ownership` + `user_profiles.active_skin_id`.
- [ ] Skins gallery (owned / earnable / buyable) with preview + select; wire all ~20 variants.
- [ ] Purchasable skins via RevenueCat one-time products → `purchase-skin` verify → ownership.
- [ ] Earned skins via `evaluate-earned-skins` (streak/leaderboard/challenge rules) → ownership + unlock push.

### 6.3 Progress Charts (Status Log)
- [ ] Compare identical past sessions over time (volume, top set, est. 1RM) per exercise; charts in status/profile.

### 6.4 Share Cards
- [ ] On session completion, render a shareable summary image (volume/duration/PRs/streak); share + optional post to feed.

### 6.4a Periodic Reports
- [ ] `user_reports` table + `generate-reports` scheduled function (weekly + monthly, metrics + deltas vs. prior period).
- [ ] Tone-aware push when a report is ready.
- [ ] Reports window reachable from **Workout → Status sheet → Reports**; lists past reports with ▲/▼ deltas; offline via `UserReports` cache.

### 6.4b Training Calendar
- [ ] Home day-strip tap opens a month calendar marking worked days (from local `Sessions`).
- [ ] Tap a day → that day's session(s) summary → route into the full log; works offline.

### 6.4c Light-Mode Accent
- [ ] Add an `accent` theme token resolved per brightness: **orange in light mode**, lime in dark.
- [ ] Apply to accent text, selected bottom-nav icon, Start Workout button, and streak icon; remove hardcoded lime in those widgets.

### 6.5 Notifications hardening
- [ ] Force-kill resync on resume; verify reminder scheduling (cron) and tone+locale resolution server-side.

### 6.6 Localization backfill
- [ ] Fill the ≈84 missing keys in de/es/fr; verify no English leakage (except intentional tone samples).

### Phase 6 Checklist
- [ ] Anatomy has working Recovery + Volume modes.
- [ ] Skins can be earned and purchased; gallery + selection work.
- [ ] Progress charts, periodic reports, training calendar, and share cards functional.
- [ ] Light-mode orange accent applied to the four target elements.
- [ ] All four locales complete.

---

## ⌚ Phase 7 — Wearable & Health Integration

**Goal:** sync with Apple Health/Watch and Google Fit/Health Connect.

### Deliverables
- [ ] Add the `health` package; configure HealthKit entitlement + usage strings (iOS) and Health Connect permissions + manifest (Android).
- [ ] Contextual permission flow + a Settings "Health/Wearable" connect screen (optional, revocable).
- [ ] **Read:** heart rate, active energy, bodyweight, external workouts → merge into sessions/status/recovery.
- [ ] Add `Sessions` fields (avgHeartRate/maxHeartRate/activeEnergyKcal) — Drift migration + Supabase migration; ride sync outbox.
- [ ] **Write back:** completed sessions → HealthKit/Health Connect workouts.
- [ ] **Apple Watch:** live heart rate during active session via a HealthKit workout session.
- [ ] Verify app is fully functional with Health denied/unavailable.

### Phase 7 Checklist
- [ ] Permissions requested with clear rationale; revocable; app works without them.
- [ ] HR/energy import into sessions; sessions export to Health/Fit.
- [ ] Live HR shows during active session when connected.
- [ ] No Health data leaves the device except derived session metrics; no advertising use.

---

## 🚀 Phase 8 — Release Prep

**Goal:** ship to the App Store (Android build ready).

### Deliverables
- [ ] App Store / Play Store listings, screenshots, privacy manifest, ATT, age rating, Health-data privacy disclosures.
- [ ] **Create App Store Connect + Play Console entries** *(carried reminder)*.
- [ ] Subscription products + RevenueCat entitlements + skin IAP products configured for production.
- [ ] Crashlytics verified; smoke test on physical iOS + Android.
- [ ] Tests for: subscription state machine, sync resolution, leaderboard scoring (all scopes), rivals matching, recovery/volume math, tone resolution, report deltas.
- [ ] CI green: analyze + test + build; signed builds for both stores.

### Phase 8 Checklist
- [ ] App passes a self-run store-compliance review (incl. HealthKit rules).
- [ ] Signed builds produced for iOS + Android.
- [ ] All v1 success criteria met (below).

---

## 📌 Cross-Phase (ongoing)
- ✅ Keep all four ARB files in sync as strings are added.
- ✅ Tag every notification/motivation with a tone.
- ✅ Maintain offline-first on every new feature.
- ✅ Add RLS + indexes for every new Supabase table.
- ✅ Keep the subscription gate a single source of truth.
- ✅ `flutter analyze` clean; tests for business logic.

---

## 🎯 v1 Success Criteria
- Paywall enforced; trial→subscription conversion measurable.
- Community, challenges, and leaderboard run on real data (no mocks).
- Followers + mutual friends + public profiles live.
- Leaderboard works across **Global, Friends, and Rivals** scopes.
- Anatomy shows recovery **and** volume; skins economy active.
- Weekly/monthly reports, training calendar, and share cards functional.
- Wearable/Health integration (Apple Health/Watch, Google Fit/Health Connect) working and optional.
- App ships on the App Store (iOS) with Android build ready.
- No critical crashes for 2 weeks post-launch.

---

**End of Implementation Plan**
