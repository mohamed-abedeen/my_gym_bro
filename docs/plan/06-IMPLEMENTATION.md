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
- **Community feed** — `CommunityMockData` only; composer doesn't persist.
- **Leaderboard** — hardcoded rows; no scoring, no backend.
- **Followers / social graph** — does not exist.
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
| 2 | Social graph (followers) + public profiles | Leaderboard rows, community identity |
| 3 | Community feed backend | Engagement loop |
| 4 | Challenges (curated + community) + moderation | Challenge points |
| 5 | Leaderboard (composite scoring; Global + Friends + Rivals) | Competition loop |
| 6 | Anatomy volume + skins + charts + reports + calendar + share cards + light-mode accent + l10n | Engagement complete |
| 7 | Wearables (Apple Health/Watch, Google Fit/Health Connect) | Health sync, live HR |
| 8 | Release prep | Ship |

> **Apple Developer account** is a hard prerequisite for APNs, Live Activities, IAP testing on device, and App Store submission. Set it up early (see `07-SETUP.md`); it gates final monetization/notification verification and release.

---

## 🚪 Phase 1 — Monetization Gate, DM Removal, Cleanup

**Goal:** the paywall actually gates the app; dead DM code is gone.

### Deliverables
- [ ] **Paywall gate:** central guard reading `UserProfiles.subscriptionStatus` (`trial`/`active`/`grace_period`/`expired`). On `expired` (and trial elapsed), route to paywall and block core use.
- [ ] Wire `verify-subscription` + `SubscriptionSyncService` on app start and resume to refresh status.
- [ ] Trial countdown surfaced in UI (days left).
- [ ] **Restore Purchases** + **Delete Account** reachable from Settings and (restore) from paywall.
- [ ] **Remove DMs:** delete `lib/features/community/dm/**`; drop `DmMessages` + `dm_dao.dart` (Drift migration); new Supabase migration dropping `dm_*` tables/policies; remove share-via-DM hooks.
- [ ] Verify offline behavior: a previously-active subscriber stays in (grace) when offline; new/expired users see gate.

### Phase 1 Checklist
- [ ] Expired user cannot use core features without subscribing/restoring.
- [ ] Trial users have full access with visible countdown.
- [ ] Restore + delete-account work end to end.
- [ ] No DM code/tables remain; app compiles, `flutter analyze` clean.

---

## 👥 Phase 2 — Social Graph (Followers) + Public Profiles

**Goal:** users can follow each other and view real public profiles.

### Deliverables
- [ ] Supabase `follows` table + RLS; counts via view or maintained columns on `user_profiles`.
- [ ] **`friends` view** (mutual follow) + friend count; relationship state (not following / following / friends).
- [ ] Drift `Follows` cache + sync wiring (outbox).
- [ ] Follow/unfollow actions (optimistic local → sync); mutual follow surfaces "friends" automatically.
- [ ] Public profile fetch: profile + counts + recent posts + achievements + streak.
- [ ] Profile screen: follow button (with friend state), follower/following/friend counts, public-safe fields, gendered anatomy.
- [ ] Privacy: hide sensitive raw metrics unless user opts in.

### Phase 2 Checklist
- [ ] Follow/unfollow works offline and syncs.
- [ ] Mutual follow correctly yields "friends" (powers Phase 5 Friends board).
- [ ] Counts accurate; tapping a leaderboard/feed row opens that profile.
- [ ] No private data leaks on public profiles.

---

## 📰 Phase 3 — Community Feed Backend

**Goal:** replace mock feed with real Supabase-backed posts.

### Deliverables
- [ ] `SupabaseCommunityRepository` implementing the existing repo interface (drop-in for `MockCommunityRepository`).
- [ ] Feed: paginated `posts` + like/comment counts; reads gated by `has_active_subscription`.
- [ ] Composer: image upload to `community-images/<uid>/…` + insert post (sanitize text via `input_sanitiser`).
- [ ] Likes/comments (insert/delete `post_likes`, insert `post_comments`).
- [ ] Loading/empty/error states; delete `community_mock_data.dart` once wired.

### Phase 3 Checklist
- [ ] Posting/liking/commenting persists and appears across accounts.
- [ ] Non-subscribers cannot read the feed (gate + RLS).
- [ ] Images upload and render (cached).

---

## 🏆 Phase 4 — Challenges (Curated + Community) + Moderation

**Goal:** real challenges that award points.

### Deliverables
- [ ] Supabase `challenges`, `challenge_participants`, `challenge_reports` + RLS.
- [ ] Curated daily challenge source (table + cron/edge seeding).
- [ ] Community challenge creation (lands `pending_review`/`active` per policy).
- [ ] Join + progress tracking; completion → `award-challenge-points` (or trigger) → `points_awarded` + `notify-social-challenge`.
- [ ] Moderation: report action; `moderate-challenges` hides over-reported challenges; review queue.
- [ ] Challenges UI (Leaderboard tab): curated daily + community list, join, progress, create, report.

### Phase 4 Checklist
- [ ] Curated daily challenge appears and is joinable.
- [ ] Users can create/join community challenges; reports hide abusive ones.
- [ ] Completing a challenge awards points (idempotent) and notifies.

---

## 📊 Phase 5 — Leaderboard (Composite Scoring)

**Goal:** a real Global leaderboard with all-time + rolling boards.

### Deliverables
- [ ] Supabase `leaderboard_scores` + indexes.
- [ ] `compute-leaderboard` scheduled function implementing the **composite = avg(streak_norm, volume_norm, points_norm)** contract (percentile normalization) for `all_time` / `weekly` / `monthly` **seasons** (since `season_start`, not rolling) — see `04-BACKEND.md`.
- [ ] **Seasons:** `finalize-season` job at weekly (Mon) + monthly (1st) boundaries → write `season_winners`, "season ended" push, advance `season_start`; fixed TZ (UTC). Feed winners to achievements/earned skins.
- [ ] **Friends scope:** `leaderboard_friends(board)` RPC ranking the viewer's mutual-follow friends by composite (depends on Phase 2 `friends` view).
- [ ] **Rivals scope:** `rival_pods` / `rival_pod_members` + `assign-rivals` weekly matching (similar composite + experience + recent volume); `leaderboard_rivals(board)` RPC ranks the caller's pod. Weekly pod reset aligns with the weekly season.
- [ ] Client: replace mock rows with a Riverpod provider reading top-N + own rank; **scope switch (Global / Friends / Rivals)** + board switch (All-time / Weekly / Monthly); **reset countdown** + last-winner banner; offline cache (`LeaderboardCache`, all scopes).
- [ ] Row tap → public profile.

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
