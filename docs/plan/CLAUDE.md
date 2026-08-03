# CLAUDE.md — Instructions for Claude Code

> **Read this BEFORE writing any code for MyGymBro.** This file is the contract for how we work on this project.

---

## 🎯 Project Context

You are helping finish and ship **MyGymBro**, a paid, offline-first Flutter fitness app (iOS-first, then Android). The foundation is built; the job now is to replace mock data with real backends, add the social layer, enforce monetization, and polish for the App Store.

**Before building a feature, you MUST:**
1. Read `01-PRD.md` for WHAT to build and the product decisions.
2. Read `02-ARCHITECTURE.md` for HOW the app is wired.
3. Read `03-DATABASE.md` before any schema change (Drift **and** Supabase).
4. Read `04-BACKEND.md` for sync rules and edge-function contracts.
5. Read `05-UI-UX.md` for the design system and i18n rules.
6. Follow `06-IMPLEMENTATION.md` for phase order and the current-state audit.

---

## ⚖️ Core Principles (Non-Negotiable)

### 1. Offline-First, Always
- The app **must work with no network**. Every user action writes to the local Drift DB first, then queues for Supabase sync.
- Never block a UI action on a network round-trip. Optimistic local write → background sync.
- Supabase and RevenueCat clients are **nullable**. Code must degrade gracefully when keys are placeholders or the device is offline.

### 2. Apple App Store & Google Play Compliance
- **Every change must keep the app shippable on both stores.** This is a hard gate.
- No private APIs, no prohibited background behavior, respect ATT/privacy manifests, IAP via RevenueCat only (no external payment links), and a working "Restore Purchases" + "Delete Account" path.
- When a change has store-review implications, call it out explicitly.

### 3. Practical Over Over-Engineered
- This is a solo project shipping ASAP. Prefer the simplest thing that works.
- We have **deliberately removed** biometric lock, SQLCipher, cert pinning, and jailbreak detection. Do not re-add them.
- Don't introduce abstractions, feature flags, or backwards-compat shims for hypothetical futures.

### 4. Localization From Day One
- 4 locales: `en` (source), `de`, `es`, `fr`. Every user-facing string goes through ARB + `gen-l10n`.
- Never hardcode user-facing text. Add the key to `app_en.arb` and all three others (no English left in translated files except where intentional, e.g., tone voice samples).

### 5. Subscription Gating Is Real
- v1 is a **hard paywall after a 7-day trial**. Premium content must be gated behind a single, well-tested entitlement check — never duplicated ad-hoc per screen.

---

## 🏗️ Project Structure

```
lib/
├── app.dart                       # MaterialApp.router, theme, locale wiring
├── main.dart                      # Bootstrap: Drift, Supabase, RevenueCat, Firebase (all safe-init)
├── core/
│   ├── auth/                      # auth_notifier.dart (Supabase auth + RevenueCat login)
│   ├── database/
│   │   ├── app_database.dart      # Drift schema (v12) + .g.dart
│   │   └── daos/                  # One DAO per aggregate
│   ├── providers/                 # Riverpod DI (db, supabase, sync, auth)
│   ├── router/                    # go_router config
│   ├── security/                  # input_sanitiser, secure_storage, safe_logger
│   └── services/                  # sync, subscription_sync, notifications, seeders, widgets
├── features/
│   ├── onboarding/                # Multi-screen intake → Supabase on signup
│   ├── auth/                      # sign in
│   ├── workout/                   # workout tab, active session, rest timer, logs, recovery
│   ├── schedule/                  # schedule/program builder
│   ├── exercises/                 # browser + detail
│   ├── home/                      # dashboard
│   ├── community/                 # feed (+ dm/ → TO BE REMOVED)
│   ├── leaderboard/               # leaderboard + challenges
│   ├── profile/                   # profile screen + providers
│   ├── settings/                  # settings + skins
│   ├── paywall/                   # RevenueCat paywall
│   └── scaffold/                  # bottom-nav shell
├── shared/                        # widgets (glass family), fonts, constants, responsive
└── l10n/                          # app_*.arb + generated localizations

supabase/
├── migrations/                    # 001..00N SQL
└── functions/                     # Deno edge functions

assets/
├── exercises.json                 # Seed catalog
├── anatomy/                       # Per-muscle SVGs (male/female) + base PNGs
├── skins/                         # Skin PNGs (male/female variants)
└── audio/, images/, icons/
```

---

## 🚦 Development Workflow Rules

### Starting a feature
1. **Check the phase** in `06-IMPLEMENTATION.md` — don't jump ahead.
2. **Plan the data layer first**: Drift table/migration + Supabase migration + RLS.
3. **Plan the sync**: how the new rows enqueue and push (see `04-BACKEND.md`).
4. **Build the repository/provider**, then the UI, then wire l10n.
5. **Test the offline path** and the gated/ungated path.

### Editing the Drift schema
1. Edit `lib/core/database/app_database.dart` (add table/column).
2. **Bump `schemaVersion`** and add a `MigrationStrategy` step — never break existing user data.
3. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `.g.dart`.
4. Update `03-DATABASE.md`.

### Editing the Supabase schema
1. Add a new numbered migration in `supabase/migrations/`.
2. Add/keep **RLS policies** for every new table (default: `auth.uid() = user_id`).
3. Gate premium reads with the `has_active_subscription()` helper where appropriate.
4. Update `03-DATABASE.md` and `04-BACKEND.md`.

### Adding a screen/widget
1. Reuse the glass component family (`GlassSurface`, `OcGlassBtn`) — don't invent new chrome.
2. **Per the standing rule:** do **not** bulk-replace existing buttons with `OcGlassBtn` without per-change approval.
3. Handle loading / empty / error states.
4. Add all strings to the 4 ARB files.

---

## 🔒 Monetization Rules

- All purchases go through **RevenueCat** (`purchases_flutter`). Entitlement: premium access.
- Products: `mgb_premium_monthly`, `mgb_premium_annual` (offerings fetched live).
- The **paywall gate** must read a single source of truth: the local `UserProfiles.subscriptionStatus` reconciled by `SubscriptionSyncService` (trial / active / grace_period / expired).
- The RevenueCat webhook (`revenuecat-webhook`) is the server-side truth; `verify-subscription` falls back to the `trial_started_at` window.
- "Restore Purchases" and "Delete Account" must always work (store requirement).

---

## ⚠️ Critical Rules — Never Break

### NEVER
- ❌ Block a user action on the network (breaks offline-first).
- ❌ Hardcode user-facing strings (breaks i18n).
- ❌ Hard-DELETE synced rows — use the `deletedAt` / soft-delete + sync-queue path.
- ❌ Ship a change that would fail Apple/Google review.
- ❌ Re-introduce removed security layers (biometric, SQLCipher, cert pinning, jailbreak).
- ❌ Bulk-swap buttons to `OcGlassBtn` without explicit approval.
- ❌ Duplicate the subscription check ad-hoc per screen.
- ❌ Trust user input — sanitize via `input_sanitiser`, log via `safe_logger` (no PII).

### ALWAYS
- ✅ Write locally first, queue for sync second.
- ✅ Keep Supabase/RevenueCat usage null-safe.
- ✅ Add RLS for every new Supabase table.
- ✅ Add strings to all 4 ARB files.
- ✅ Bump Drift `schemaVersion` + migration on schema change.
- ✅ Tag every notification + motivation message with a **tone** (supportive/balanced/bold/savage).
- ✅ Test recovery-coloring and volume views on the anatomy body for both genders.
- ✅ Handle loading / empty / error states.

---

## 🧪 Testing Strategy

- **Unit tests**: business logic — sync queue resolution, subscription state machine, leaderboard composite scoring, muscle recovery math, tone resolution.
- **Widget tests**: gated vs ungated screens, offline fallbacks, empty states.
- Use `mocktail` for mocks; lint with `very_good_analysis`.
- A feature is not done if it only works online or only in English.

---

## 📋 Definition of Done (per feature)

- [ ] Works fully offline (local write → queued sync).
- [ ] Premium content gated through the single entitlement check.
- [ ] Drift + Supabase schema migrated; RLS in place.
- [ ] All strings in `en`, `de`, `es`, `fr`.
- [ ] Loading / empty / error states handled.
- [ ] Notifications/motivation tagged with tone (if applicable).
- [ ] No store-review blockers introduced.
- [ ] Business logic has tests; `flutter analyze` clean.
- [ ] Relevant plan doc updated.

---

## 🆘 When Stuck or Specs Conflict

1. Don't silently assume — leave a `// TODO(clarify): …` and ask.
2. Pick the most store-compliant, offline-safe default.
3. If docs conflict: `01-PRD.md` wins on WHAT, `02-ARCHITECTURE.md` wins on HOW. Update the others to match.

---

**Current Phase:** Phase 1 — Paywall enforcement + DM removal (see `06-IMPLEMENTATION.md`).
