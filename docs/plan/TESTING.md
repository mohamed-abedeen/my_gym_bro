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

## Optional dev aid (not yet built)
- A debug-only "Expire trial now" button in Settings to test the gate with one tap instead of changing the clock. Ask the user if they want this.
