# NEXT-STEPS — Sequenced backlog for the next agent

> Reconciled 2026-06-29 from `STATUS.md` (ground-truth audit), `06-IMPLEMENTATION.md`
> (phase roadmap), the 2026-06-10 security audit, and the glass/nav/colour UI work
> that just merged to `main`. When this doc and the older `06-IMPLEMENTATION` audit
> disagree, **this doc + `STATUS.md` win** (the code is further along than that audit implies).
>
> For full per-phase deliverables and the scoring/season contracts, read `STATUS.md §2`
> and `06-IMPLEMENTATION.md` / `04-BACKEND.md`. This file is the *ordering + the close-out
> and hardening work that isn't yet captured elsewhere*.

---

## Where the app actually is

**✅ Done**
- Phase 1 — paywall gate hardened (`subscriptionLockedProvider` + GoRouter redirect, non-dismissible) + DM subsystem removed.
- Phase 2 — social graph (followers, mutual-follow friends, public profiles).
- Phase 3 — Supabase community feed + posting + likes.
- Drift schema **v15**; migrations made idempotent (`_addColumnIfMissing`/`_hasTable`).
- Full glass system + platform-adaptive nav (iOS native `CNTabBar`, non-iOS frosted Figma pill; refractive only on active-workout chrome). See root `CLAUDE.md`.
- **Light-mode orange accent (#FF7A00) + dark accent #F0FF00 + streak fire pinned orange** — closes plan item 6.4c.

**🔴 Remaining:** Phases 4–8, plus the close-out + hardening in Sprint 0 below.

---

## 🟥 Sprint 0 — Close-out & hardening (do FIRST; launch-blocking)

The shipped phases have loose ends, and the **2026-06-10 security audit** (later than STATUS.md) found new holes.

1. **Security-audit fixes**
   - [ ] **Paywall data bypass** — `subscriptionStatus`/trial columns are client-writable. Lock them with RLS (deny client writes); only the RevenueCat webhook / `verify-subscription` may set them. The *route* gate is hard; the *data* isn't.
   - [ ] **Auth "Skip" bypass** — remove the client path that reaches gated content unauthenticated.
   - [ ] **Push-spam** — rate-limit / validate notification triggers.
2. **Finish Phase 1–3 deferrals**
   - [ ] Community composer **image upload** (currently a no-op) → upload to `community-images/<uid>/…`, set `image_url`. *(Post-card image rendering already exists — asset + `CachedNetworkImage`.)*
   - [ ] **Comment composer** (counts show; no compose yet) and **profile Posts tab** (still mock).
   - [ ] **Live entry point to open another user's public profile + `FollowButton`** — Phase 2 built the data/button, but nothing routes to it (feed rows / leaderboard rows should tap → public profile).
   - [ ] Apply cloud Supabase migrations (**`007`**); fix the **from-scratch migration ordering bug** (`002` refs `exercises`, `003` refs `dm_conversations`).
   - [ ] **On-device verification**: paywall offline-grace + expired-block; Phase 2/3 smoke tests.
3. **Test content**
   - [ ] Replace the 3 throwaway community sample images (`assets/images/sample_post_*.jpg`) with real content, and drop the `kDebugMode` empty-feed fallback in `community_repository.dart`, before launch.

## 🟧 Phase 4 — Challenges (curated + community) + moderation
Supabase `challenges`/`challenge_participants`/`challenge_reports` + RLS; curated daily source (cron/edge); community creation with review; join/progress; completion → `award-challenge-points` → `notify-social-challenge`; moderation (`moderate-challenges`); wire the existing Challenges tab. *(Unblocks the "points" input to the leaderboard.)*

## 🟨 Phase 5 — Leaderboard (composite scoring; Global + Friends + Rivals; seasons)
Depends on Phase 2 (friends) + Phase 4 (points). `leaderboard_scores` + `compute-leaderboard` (**composite = avg(streak_norm, volume_norm, points_norm)**, percentile-normalized, per season — contract in `04-BACKEND.md`); `finalize-season` (weekly Mon / monthly 1st, UTC → winners + push + advance); Friends RPC (mutual-follow); Rivals pods + `assign-rivals` (weekly matching); client provider (top-N + own rank), board switch, reset countdown + winner banner, offline `LeaderboardCache`; row tap → profile. The scope UI (Global/Friends/Rivals) already exists.

## 🟩 Phase 6 — Engagement completion
Anatomy **Volume mode** (Recovery|Volume toggle, both genders); **skins economy** (`skins` catalog + `skin_ownership` + `active_skin_id`; gallery own/earn/buy; RevenueCat one-time `purchase-skin`; `evaluate-earned-skins`); **progress charts** (compare past sessions: volume/top-set/est-1RM); **periodic reports** (`user_reports` + `generate-reports` weekly/monthly + Reports window from Workout→Status); **training calendar** (Home day-strip → month); **share cards** (session-complete image + share/post); **l10n backfill** (~84 keys ×3, de/es/fr); notification **force-kill resync** + reminder-cron verify. *(6.4c light accent is DONE.)*

## 🟦 Phase 7 — Wearables & Health
`health` package + HealthKit entitlement/usage strings (iOS) + Health Connect perms/manifest (Android); Settings connect screen + contextual revocable perms; read HR/energy/bodyweight/external workouts → merge into sessions/status/recovery; add `Sessions` HR/energy fields (Drift + Supabase migration + outbox); write completed sessions back; Apple Watch live HR; must degrade fully when denied.

## ⬜ Phase 8 — Release prep
Apple Developer account (gates APNs/Live Activities/HealthKit/on-device IAP/submission); App Store Connect + Play Console entries + listings/screenshots/privacy manifest/ATT/age rating/Health disclosures; production subscription + skin IAP products; Crashlytics verified; **the test suite** (subscription state machine, sync resolution, leaderboard scoring all scopes, rivals matching, recovery/volume math, tone resolution, report deltas); CI green (analyze + test + build) + signed builds for both stores.

---

## Cross-phase (every task)
- Offline-first: local write → sync outbox; never block a UI action on the network; no hard-deletes (soft-delete + queue).
- RLS + indexes for every new Supabase table.
- Keep all 4 ARB locales in sync; tag every notification/motivation with a tone.
- Single subscription gate as the only entitlement source of truth.
- `flutter analyze` clean; write tests for business logic.
- Follow the glass rules in root `CLAUDE.md` ("make it glassy" = context-dependent).

## Recommended starting point
Do **Sprint 0** first — the three security-audit fixes, then the community image-upload + the public-profile entry point. That turns "looks done" into "actually shippable" before Phases 4–8.
