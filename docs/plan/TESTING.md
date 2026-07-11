# TESTING — Pending Manual Tests

> Running checklist of things implemented but **not yet verified on a device**.
> Claude: when resuming work, remind the user about any unchecked items here.

---

## ⏸️ Deferred until backend/payments are connected
The user has **not** yet:
- created/configured the Supabase project data + auth for testing,
- connected everything in RevenueCat (products, entitlement `premium`, API keys).

So the following are **intentionally postponed** — do NOT push the user to test these until they say Supabase + RevenueCat are ready:
- Sign-up / sign-in (needs Supabase).
- Paywall **gate** engaging on trial expiry (needs a real signed-up profile with a trial window).
- Purchase / Restore completing (needs RevenueCat products + sandbox tester; iOS needs Apple Developer account).
- Cloud sync.

When ready, launch with keys:
```
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon-key> ^
  --dart-define=REVENUECAT_IOS_KEY=<key> --dart-define=REVENUECAT_ANDROID_KEY=<key>
```

---

## Phase 1 — to verify

### Testable now (offline mode, plain `flutter run`)
- [ ] App launches without errors/crash.
- [ ] Community tab: the **chat/DM icon is gone** from the header.
- [ ] Upgrade test: install over a previous build that had DMs → migrates Drift v12→v13 (drops `dm_messages`) without crashing.
- [ ] General regression: Home / Workout / Community tabs, schedule builder, exercise browser all still work.

### Needs Supabase + RevenueCat (deferred)
- [ ] Sign up → lands in app with an active 7-day trial.
- [ ] Settings → subscription row shows **"X days left"** + chevron; tapping opens the paywall.
- [ ] Simulate trial expiry (device clock +8 days, or temporarily set `trialDurationDays = 0` in `lib/shared/app_constants.dart`) → on resume the app is **forced to the paywall**: no close (X) button, back/swipe-back blocked, cannot navigate away.
- [ ] After a valid subscription/restore, the gate **releases** and returns to the app.
- [ ] Settings → **Delete Account** → confirm dialog → completes (needs `delete-account` edge function deployed).
- [ ] Apply `supabase/migrations/005_drop_dm.sql` on deploy (`supabase db push`).

---

## ExerciseDB OSS exercise API — to verify (replaced WorkoutX 2026-07-08)

**No API key needed** (`https://oss.exercisedb.dev/api/v1`, free). ⚠️ OSS dataset is
**non-commercial — testing only**; buy the ExerciseDB.io one-time license before release
(see `08-WORKOUTX-MIGRATION.md` status note).

- [ ] Exercise browser loads exercises (catalogue syncs into Drift incrementally, ~1,500 rows), infinite-scroll fetches more.
- [ ] Search does a **local LIKE over the synced catalogue** (first-ever search may return partial results while the sync catches up — API 429s pause the sync and later calls resume it).
- [ ] Offline: browser shows the offline banner and serves cached rows; app does not error.
- [ ] Caching: an exercise added to a schedule or logged in a session is cached locally (`ensureCached`) and still resolves later offline.
- [ ] GIFs render (public `static.exercisedb.dev` URLs, no auth).
- [ ] Upgrade migration v15→v16 wipes seeded (`is_custom=0`) exercises but **keeps custom ones**; WorkoutX-era ids in old schedules will NOT re-resolve (different id scheme) — fresh install recommended for testing.
- [ ] ProgramSeeder first-launch works offline via `assets/exercises_starter.json` (regenerated with ExerciseDB ids/names).

## ⚠️ REMINDER — Cloud edge-function secrets (set before any function works)

The 6 edge functions are **deployed** to project `konzjrklgyuodzrrhwwv`, but they read env vars that are NOT all auto-injected. Until set, functions that use them fail at runtime.

Exact names the code reads (from `Deno.env.get(...)`):
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — **auto-injected** by Supabase, no action.
- **`SERVICE_ROLE_KEY`** — ⚠️ **MUST set manually.** The code uses this custom name, NOT the auto-injected `SUPABASE_SERVICE_ROLE_KEY`, so it is undefined until you set it. Needed by ALL functions (revenuecat-webhook, verify-subscription, send-push-notification, schedule-notifications, delete-account, notify-social-challenge). Value = Dashboard → Project Settings → API → `service_role` key.
- **`FCM_SERVER_KEY`** — set manually. Needed by send-push-notification, schedule-notifications, notify-social-challenge. Value = Firebase Console → Project Settings → Cloud Messaging server key. (Note: Google deprecated legacy FCM server keys; if it's gone, the functions may need updating to FCM HTTP v1.)
- **`REVENUECAT_WEBHOOK_SECRET`** — set manually. Needed by revenuecat-webhook. Value = the Authorization secret you configure on the RevenueCat webhook.

Set them in one go (single quotes to avoid PowerShell `$` expansion):
```powershell
supabase secrets set SERVICE_ROLE_KEY='...' FCM_SERVER_KEY='...' REVENUECAT_WEBHOOK_SECRET='...'
supabase secrets list   # verify
```

(Consider renaming `SERVICE_ROLE_KEY` → use the auto-injected `SUPABASE_SERVICE_ROLE_KEY` in code to drop one manual secret — a small code change across the 6 functions.)

## Optional dev aid (not yet built)
- A debug-only "Expire trial now" button in Settings to test the gate with one tap instead of changing the clock. Ask the user if they want this.
