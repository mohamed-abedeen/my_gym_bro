# my_gym_bro

Paid fitness tracker with a local Drift database, Supabase sync, and a premium UI.
Exercises are served by the **WorkoutX API** (`https://api.workoutxapp.com/v1`) and
cached locally for offline-first reads. A tiny bundled starter set
(`assets/exercises_starter.json`) seeds the default program so the offline gym flow
works on first launch.

## Configuration / secrets

Secrets are injected at build time, never committed. Put them in a local `.env`
(git-ignored) and pass it with `--dart-define-from-file`:

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
REVENUECAT_IOS_KEY=...
REVENUECAT_ANDROID_KEY=...
WORKOUTX_API_KEY=wx_...
```

`WORKOUTX_API_KEY` is read in `lib/main.dart` via
`String.fromEnvironment('WORKOUTX_API_KEY')` and flows to `ExerciseApiService`
through `workoutxApiKeyProvider`. With no key the app still runs fully offline
against the local cache.

## Run (debug)

```
flutter pub get
flutter run --dart-define-from-file=.env
```

## Release build (obfuscated)

Dart obfuscation + split debug symbols keep the API usage and logic opaque in the
shipped binary. Symbols/maps are git-ignored (`app.*.symbols`, `app.*.map.json`).

```
# Android App Bundle
flutter build appbundle --release \
  --dart-define-from-file=.env \
  --obfuscate --split-debug-info=build/symbols

# iOS
flutter build ipa --release \
  --dart-define-from-file=.env \
  --obfuscate --split-debug-info=build/symbols
```

Keep `build/symbols/` for crash de-obfuscation. Android code shrinking is
configured via `android/app/proguard-rules.pro`.

## Tests / analysis

```
flutter analyze
flutter test
```

## WorkoutX free-plan notes

- Browse (`/exercises?offset&limit`) and get-by-id work on the free plan; page
  size is capped at 10, so the browser paginates in small pages.
- Server-side search/filter (`/exercises/search`) requires a paid plan
  (`multiFilter`). On the free plan, search transparently degrades to filtering
  the local cache. Limits: 30 req/min, 500 req/day.
