# 07 — Setup & Release
## MyGymBro — Dev Environment, Accounts, Build, Release

---

## 1. Prerequisites

| Tool | Notes |
|------|-------|
| Flutter SDK | Dart ^3.7; `flutter doctor` clean |
| Xcode | iOS builds, simulators, signing (macOS) |
| Android Studio / SDK | Android builds, emulator |
| CocoaPods | iOS pods |
| Supabase CLI | Migrations, edge function deploy |
| Deno | Edge function local dev |
| Node (optional) | Tooling |

---

## 2. Accounts & Services

| Service | Status | Used for |
|---------|--------|----------|
| **Supabase** | ✅ project exists (`konzjrklgyuodzrrhwwv`) | Auth, Postgres, Storage, Edge Functions |
| **RevenueCat** | ✅ project exists | Subscriptions + skin IAP |
| **Firebase** | ✅ project exists (`mygymbro-f23d3`) | FCM push, Crashlytics |
| **Apple Developer** | ❌ **NOT YET** — blocks APNs, Live Activities, on-device IAP, App Store | Required before final monetization/notification verification + submission |
| **Google Play Console** | ⏳ deferred (iOS first) | Android release |

> **Action:** create the **Apple Developer account** early — it's the critical-path blocker for several v1 verification steps and for shipping.

---

## 3. Environment Variables (`.env`)

Never commit secrets. Required keys:

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
REVENUECAT_API_KEY_IOS=...
REVENUECAT_API_KEY_ANDROID=...
# Firebase via google-services.json / GoogleService-Info.plist
```

- The app **safe-inits**: placeholder/missing keys → Supabase/RevenueCat clients are null and the app runs offline-only. Fill real values for full functionality.
- Edge function secrets (service role key, FCM credentials, RevenueCat webhook secret) live in Supabase function config, not the app.

---

## 4. First-Run Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift + Riverpod codegen
flutter gen-l10n                                            # localizations (or via build)
```

- Seed assets present: `assets/exercises.json`, `assets/anatomy/`, `assets/skins/`, `assets/audio/`.
- On first launch the app seeds exercises + 3 default programs (Arnold, Bro, PPL).

---

## 5. Supabase

```bash
supabase link --project-ref konzjrklgyuodzrrhwwv
supabase db push                 # apply migrations
supabase functions deploy <name> # deploy edge functions
```

- Migrations live in `supabase/migrations/` (001–004 + new ones per `03-DATABASE.md`).
- Edge functions in `supabase/functions/`.
- `schedule-notifications` and `compute-leaderboard` need **pg_cron** schedules configured.

---

## 6. Run & Debug

```bash
flutter run                      # default device
flutter run -d <deviceId>
flutter analyze                  # very_good_analysis lint
flutter test                     # unit/widget tests (mocktail)
```

- Debug APK builds and runs on Android today.
- iOS device builds + push/Live Activity/IAP testing require the Apple Developer account + provisioning.

---

## 7. Codegen Reminders

Run `build_runner` after changing:
- Drift tables (`app_database.dart`) → regenerates `app_database.g.dart` (and **bump `schemaVersion`** + migration).
- Riverpod `@riverpod` providers.

Run `gen-l10n` after editing any `app_*.arb`.

---

## 8. Build for Release

### iOS
- [ ] Apple Developer account + App ID + capabilities (Push, Live Activities, IAP).
- [ ] Signing/provisioning in Xcode.
- [ ] APNs key uploaded to Firebase.
- [ ] `flutter build ipa`; upload via Xcode/Transporter.
- [ ] App Store Connect entry, subscription products, screenshots, privacy manifest, ATT, age rating.

### Android
- [ ] Play Console entry, signing key.
- [ ] `flutter build appbundle`.
- [ ] Subscription products + RevenueCat mapping.
- [ ] Data safety form, content rating.

---

## 9. Release Checklist (v1)

- [ ] All four locales complete (no English leakage).
- [ ] Paywall gate enforced; trial countdown; restore + delete-account verified on device.
- [ ] RevenueCat products + entitlements live (prod), webhook reachable.
- [ ] FCM push verified on real devices; tone+locale resolved server-side.
- [ ] Leaderboard recomputes on schedule; community + challenges on real data.
- [ ] No DM code/tables remain.
- [ ] Crashlytics receiving events; no critical crashes in smoke tests.
- [ ] Store listings, screenshots, privacy, ratings submitted.
- [ ] CI (`.github/workflows/ci.yml`) green: analyze + test + build.

---

## 10. Known Constraints / Carry-Overs
- Apple Developer account is the top blocker — schedule it now.
- Notification force-kill resilience: v1 = resync on resume (full foreground-service/APNs Live Activity loop deferred).
- Leaderboard scope is **Global only** in v1; following/region/per-challenge boards are future.

---

**End of Setup Document**
