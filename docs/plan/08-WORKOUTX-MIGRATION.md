# 08 — WorkoutX Exercise API Migration

> **⚠️ SUPERSEDED (2026-07-08).** WorkoutX was implemented, then dropped: its metered
> plans (500 req/mo free; paid tiers still request-capped) fight the offline-first
> architecture and cost more over time than owning the data. Current state:
> - **Testing:** the app now uses the **ExerciseDB OSS v1 API** (`oss.exercisedb.dev`,
>   free, no key, ~1,500 exercises). Its license is **non-commercial** — fine for
>   development/testing, NOT for release.
> - **Deployment plan:** buy the **ExerciseDB.io one-time dataset license**
>   (Mobile tier $299 — 1,394 exercises + GIFs, perpetual, commercial, offline
>   bundling + self-hosting allowed) and swap the data source before launch.
> The rest of this doc is kept for the WorkoutX research/appendices only.

**Status:** Superseded — see banner above.
**Audience:** Self-contained implementation brief. Assumes access to this Flutter repo
and the project's Supabase backend, but no prior context.
**Chosen path:** WorkoutX **Ultra API plan** ($24.99/mo), **direct client → WorkoutX**
calls (NO backend proxy — see §4). AI generator deferred to a later version.

> ⚠️ This supersedes any earlier draft of this doc that described a Supabase Edge
> Function proxy. **WorkoutX explicitly forbids server-side proxying/caching on standard
> plans** (see Appendix A). Do not build a proxy.

---

## 1. Goal

Replace the app's exercise data source. Today the app ships ~1,500 ExerciseDB exercises
bundled in `assets/exercises.json`, seeded into a local Drift/SQLite table, with GIFs
hotlinked from `static.exercisedb.dev`. We are switching to the **WorkoutX REST API**
(`https://api.workoutxapp.com/v1`) on the **Ultra plan** for:

1. **Legal/licensing safety** — paid app; Ultra includes full commercial rights for GIFs
   + exercise data inside a subscription app (confirmed in writing — Appendix A).
2. Cleaner, owned exercise infrastructure with forward-looking metadata.

The AI workout generator (`/v1/workout/generate`) is **nice-to-have, deferred** — build
code switch-ready but do not depend on it for v1.

> Note: WorkoutX is repackaged ExerciseDB; content is comparable (~1,400 exercises), not
> a content upgrade. The justification is **licensing**, not more/better exercises.

---

## 2. Locked product decisions (do not deviate)

1. **Remove the bundled exercises entirely** — delete `assets/exercises.json`, its
   `pubspec.yaml` entry, and every `seedFromAssets()` call.
2. **Browser is ONLINE** (fetch-on-demand via the API), paginated + debounced.
3. **Local Drift `exercises` table becomes a per-user CACHE**, populated:
   - **cache-on-save** — when an exercise is added to a program (`ScheduledExercises`).
   - **cache-on-log** — when an exercise is logged in a session (`SessionExercises`).
   This is exactly what WorkoutX permits ("client-side caching... no restrictions" —
   Appendix A) and gives the user full **offline access to their program in the gym**.
4. **No backend proxy** — the app calls `api.workoutxapp.com` directly (Appendix A).

---

## 3. WorkoutX API reference (verified)

- **Base URL:** `https://api.workoutxapp.com/v1`
- **Auth:** HTTP header `X-WorkoutX-Key: wx_...`
- **Production plan:** **Ultra** ($24.99/mo, 35k req/mo, ~600 req/min).
- **Testing plan:** a **Free** key will be provided (see §9 for its limits).

### Endpoints
| Endpoint | Purpose | Min plan |
|---|---|---|
| `GET /v1/exercises?limit=&offset=` | Paginated list | Free |
| `GET /v1/exercises/exercise/:id` | Single by id | Free |
| `GET /v1/exercises/name/:name` | Partial-name search | Free |
| `GET /v1/exercises/bodyPart/:bodyPart` | Filter by body part | Free |
| `GET /v1/exercises/target/:target` | Filter by target muscle | Free |
| `GET /v1/exercises/equipment/:equipment` | Filter by equipment | Free |
| `GET /v1/exercises/bodyPartList` / `targetList` / `equipmentList` | Filter vocab | Free |
| `GET /v1/exercises/search` | Multi-filter | **Basic+** |
| `GET /v1/exercises/:id/similar` / `:id/alternatives` / `:id/calories` | Smart | check tier |
| `GET /v1/workout/generate?goal=&level=&split=` | AI generator | **Pro+** |

### Exercise object shape (WorkoutX)
```json
{
  "id": "0001",
  "name": "3/4 sit-up",
  "bodyPart": "waist",
  "target": "abs",
  "equipment": "body weight",
  "gifUrl": "https://<workoutx-storage>/exercise-gifs/0001.gif",
  "instructions": ["Lie down ...", "Place your hands ..."],
  "secondaryMuscles": ["hip flexors", "lower back"]
}
```

**Differences from our current data:**
- WorkoutX uses **singular string** fields (`bodyPart`/`target`/`equipment`); our schema
  uses **JSON-array** columns (`bodyParts`/`targetMuscles`/`equipments`) → wrap in
  one-element arrays on ingest.
- WorkoutX has **no `difficulty`** → not a problem, we derive it locally (§7).
- WorkoutX **IDs differ** (`0001`) from current ExerciseDB v1 IDs (`2gPfomN`) → §8.

---

## 4. Architecture — direct client, NO proxy

```
Flutter app ──HTTPS, X-WorkoutX-Key──► api.workoutxapp.com/v1
     │
     └──► Local Drift "exercises" table  =  per-user cache (program + logged exercises)
     └──► cached_network_image           =  per-device GIF cache (offline after first view)
```

- The app calls WorkoutX **directly**. No Supabase involvement for exercises. (Supabase
  stays as-is for profile/workout-log sync — unchanged by this migration.)
- Add an HTTP client. `http` is already available transitively via `supabase_flutter`;
  declare it explicitly in `pubspec.yaml` (`http: ^1.2.0`) or use `dio` if preferred.

### 4.1 API key management & security (READ — this is the main risk)
Because proxying is forbidden, the API key lives in the client binary. It is therefore
**extractable by a determined attacker** — this is WorkoutX's sanctioned model, mitigated
by their per-account rate limiting. Minimize exposure:

- **Never hardcode the key in source / never commit it.** Inject at build time:
  `flutter build --dart-define=WORKOUTX_API_KEY=wx_...` read via
  `const String.fromEnvironment('WORKOUTX_API_KEY')`. This mirrors the existing
  `SUPABASE_URL` / `SUPABASE_ANON_KEY` pattern in [main.dart](../../lib/main.dart#L76).
- Enable Dart obfuscation for release builds:
  `flutter build appbundle --obfuscate --split-debug-info=build/symbols`.
- Use **separate keys** for dev (the free key) and prod (Ultra) via different
  `--dart-define` values per build flavor.
- Monitor usage in the WorkoutX dashboard; rotate the key if it leaks.
- Document this residual risk in the security section of the project plan so it's a known,
  accepted trade-off (and revisit the **Data Pack $699 one-time** option — Appendix A — if
  key exposure or rate limits ever become a real problem; it eliminates the API entirely).

---

## 5. Client implementation

### 5.1 `ExerciseApiService` → `lib/core/services/exercise_api_service.dart`
Thin `http` wrapper. Sends `X-WorkoutX-Key`. Parses `WorkoutXExercise` DTOs. Handle
non-200s, timeouts, and offline (throw a typed `ExerciseApiException` the UI can catch).

```dart
class ExerciseApiService {
  ExerciseApiService(this._client, this._key);
  final http.Client _client;
  final String _key; // from String.fromEnvironment, injected at app start
  static const _base = 'https://api.workoutxapp.com/v1';

  Future<List<WorkoutXExercise>> list({int limit = 30, int offset = 0}) =>
      _get('/exercises?limit=$limit&offset=$offset');
  Future<List<WorkoutXExercise>> searchByName(String name) =>
      _get('/exercises/name/${Uri.encodeComponent(name)}');
  Future<List<WorkoutXExercise>> byTarget(String target) =>
      _get('/exercises/target/${Uri.encodeComponent(target)}');
  Future<WorkoutXExercise?> byId(String id) async =>
      (await _get('/exercises/exercise/$id')).firstOrNull;

  Future<List<WorkoutXExercise>> _get(String path) async {
    final res = await _client
        .get(Uri.parse('$_base$path'), headers: {'X-WorkoutX-Key': _key})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw ExerciseApiException(res.statusCode, res.body);
    }
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['data'] as List? ?? [body]);
    return list.map((e) => WorkoutXExercise.fromJson(e)).toList();
  }
}
```
Register `exerciseApiServiceProvider` in [providers.dart](../../lib/core/providers/providers.dart),
reading the key from `String.fromEnvironment`.

### 5.2 DTO + mapper → `WorkoutXExercise`
Map singular WorkoutX fields into the array-shaped `ExercisesCompanion`. **Reuse the
existing local heuristics** for `muscleGroup` and `difficulty` — promote
`_resolveGymMuscleGroup` and `_resolveDifficulty` (currently private statics in
[exercise_local_service.dart](../../lib/core/services/exercise_local_service.dart)) into a
shared public helper (e.g. `ExerciseMapping`). Do not reinvent them.

```dart
ExercisesCompanion toCompanion(WorkoutXExercise w) => ExercisesCompanion(
  exerciseId: Value(w.id),
  name: Value(w.name),
  bodyParts: Value(jsonEncode([w.bodyPart])),
  targetMuscles: Value(jsonEncode([w.target])),
  secondaryMuscles: Value(jsonEncode(w.secondaryMuscles)),
  equipments: Value(jsonEncode([w.equipment])),
  gifUrl: Value(w.gifUrl),
  instructions: Value(jsonEncode(w.instructions)),
  muscleGroup: Value(ExerciseMapping.resolveGymMuscleGroup(
      target: w.target, bodyPart: w.bodyPart, exerciseName: w.name)),
  difficulty: Value(ExerciseMapping.resolveDifficulty(
      equipments: [w.equipment], secondaryMuscles: w.secondaryMuscles, name: w.name)),
  isCustom: const Value(false),
);
```

### 5.3 `ExerciseRepository` — single source of truth for the UI
- **Browse / search** → `ExerciseApiService` (online), paginated + debounced.
- **Read a known exercise by id** (program / history / active session) → **local-first**:
  `ExerciseDao.findByExerciseId`; on miss AND online, fetch + cache; on miss AND offline,
  return a graceful placeholder.
- **cache-on-save** → in the flow that creates `ScheduledExercises` rows, `upsert` the
  full exercise into `exercises` (`ExerciseDao.upsert` already exists —
  [exercise_dao.dart:64](../../lib/core/database/daos/exercise_dao.dart#L64)).
- **cache-on-log** → in the flow that creates `SessionExercises` rows, upsert too. This
  keeps history enrichment + `MuscleRecoveryService` working offline (they read local
  `exercises` via `findByExerciseIds` —
  [workout_providers.dart:268,826](../../lib/features/workout/workout_providers.dart#L268)).
- Cache the small filter-vocab lists (`bodyPartList`/`targetList`/`equipmentList`) locally.

### 5.4 Remove the bundled dataset & seeding
- Delete `assets/exercises.json` + its `pubspec.yaml` asset entry.
- [main.dart](../../lib/main.dart#L179): remove the `seedFromAssets` call in
  `_backgroundDbInit` (~line 179) and the now-pointless `remapMuscleGroups` /
  `backfillDifficulty` calls (~184–185) — mapping now happens at ingest (§5.2).
- [sign_up_screen.dart](../../lib/features/onboarding/screens/sign_up_screen.dart#L130):
  remove both `seedFromAssets` calls (lines 130 & 134).
- Shrink `ExerciseLocalService` to the shared `ExerciseMapping` helpers.

### 5.5 Rework the browser / pickers
- [exercise_browser_screen.dart](../../lib/features/exercises/exercise_browser_screen.dart):
  replace "all local rows / recent-25 + A–Z" with **online paginated lists** + **debounced
  search** via `ExerciseRepository`. Add empty / error / offline states. Seed the filter
  dropdowns from the cached vocab lists.
- [log_bottom_sheet.dart](../../lib/features/workout/log_bottom_sheet.dart) + exercise
  detail sheet: read **known** exercises → local-first path (offline-safe for cached items).
- GIFs: `cached_network_image` already in use; point at the new `gifUrl`s and lazy-load.

### 5.6 Rework `ProgramSeeder`
[program_seeder.dart](../../lib/core/services/program_seeder.dart) already resolves
exercises **by name** (`_id(name)` — line 34). Update `_id()` to: search local cache →
else `ExerciseApiService.searchByName` → cache the best match → else fall back to a custom
exercise (as today). Handle first-launch offline via the bundled fallback (§10.1).

---

## 6. Field mapping reference

| Local Drift column | WorkoutX source | Transform |
|---|---|---|
| `exerciseId` | `id` | direct |
| `name` | `name` | direct |
| `bodyParts` | `bodyPart` | `jsonEncode([v])` |
| `targetMuscles` | `target` | `jsonEncode([v])` |
| `secondaryMuscles` | `secondaryMuscles` | `jsonEncode(v)` |
| `equipments` | `equipment` | `jsonEncode([v])` |
| `gifUrl` | `gifUrl` | direct |
| `instructions` | `instructions` | `jsonEncode(v)` (strip any `Step:n` prefixes) |
| `muscleGroup` | — | derive via `ExerciseMapping.resolveGymMuscleGroup` |
| `difficulty` | — | derive via `ExerciseMapping.resolveDifficulty` |
| `isCustom` | — | `false` |
| `usageCount` / `isFavorite` | — | local-only, unchanged |

---

## 7. (covered above — heuristics reused, not re-derived)

---

## 8. ID migration / schema v14

String-id columns: **`ScheduledExercises.exerciseId`** + **`SessionExercises.exerciseId`**
([app_database.dart:110,147](../../lib/core/database/app_database.dart#L110)).
App is **pre-launch (no production users)** → use the **clean-wipe** path:
- Bump `schemaVersion` 13 → 14 (currently 13 — [app_database.dart:216](../../lib/core/database/app_database.dart#L216)).
- Migration: `DELETE FROM exercises WHERE is_custom = 0;` The cache repopulates from the API.
- Re-seed the active program via the reworked `ProgramSeeder` (re-resolves by name → new IDs).
- Do **not** build the name-based remap (only needed if there are real users).

---

## 9. Free-tier testing constraints (pre-deployment)

A **Free** WorkoutX key will be provided for build/test. Limits:
- **500 requests/month, 30 requests/minute.** Be frugal: don't loop, cache aggressively,
  and prefer fixtures/mocks for repetitive UI testing.
- Free tier excludes `/exercises/search` (Basic+) and `/workout/generate` (Pro+).
- **Build/test against the Free endpoints only** (list, name, target, bodyPart, equipment,
  *List). Design `/search` and the AI generator switch-ready but stubbed/flagged off.
- Production swaps to the Ultra key via `--dart-define`; no code change.

---

## 10. Open decisions

### 10.1 First-launch offline (recommended: bundled fallback)
The browser + default-program seeding need network on first run. Ship a **tiny (~10
exercise) bundled starter set** used ONLY to seed the default program offline; everything
else comes from the API. (Alternative: require connectivity on first launch.)

### 10.2 GIF offline story
`cached_network_image` caches GIFs per-device after first view — that's the offline GIF
path for cached exercises. For guaranteed offline, optionally pre-fetch a program's GIFs
on save. Client caching is explicitly permitted (Appendix A).

---

## 11. Build order / checklist

1. Add `http` to `pubspec.yaml`; wire `WORKOUTX_API_KEY` via `--dart-define` + read in
   `main.dart`; set up obfuscated release build (§4).
2. `ExerciseApiService` + `WorkoutXExercise` DTO + `ExerciseMapping` shared helpers (§5.1–5.2).
3. `ExerciseRepository`: online browse/search + local-first reads + cache-on-save +
   cache-on-log (§5.3).
4. Remove bundled JSON + all `seedFromAssets` calls; shrink `ExerciseLocalService` (§5.4).
5. Rework browser/picker for online paginated + debounced search + offline states (§5.5).
6. Rework `ProgramSeeder` (API-by-name + cache + bundled fallback) (§5.6).
7. Schema v14 clean-wipe migration (§8).
8. Re-verify `MuscleRecoveryService` + history enrichment against the cache.
9. (Deferred) AI generator behind paywall — switch-ready, off for v1.
10. Test: offline gym flow (start + log a saved program with no network); online
    browse/search; free-tier request budget; App Store / Play compliance.

---

## Appendix A — WorkoutX written confirmation (2026, business@workoutxapp.com)

Key points from WorkoutX's emailed reply (retain for App Store review evidence):

- **GIF/media ownership & commercial use:** GIFs and media are **owned by WorkoutX**. All
  paid plans (incl. Ultra) include **full commercial usage rights** — display to paying
  users in a subscription/SaaS mobile app is permitted.
- **Client-side caching:** **Permitted, no restrictions.** App may cache previously viewed
  exercises + GIFs locally for performance and offline access.
- **Backend caching / proxy:** **NOT permitted on standard plans.** "The API is designed
  for direct authenticated client usage, not server-side proxying or re-serving."
- **Data Pack alternative ($699 one-time):** full 1,000+ exercise dataset + all GIFs
  delivered to your backend, lifetime, no API dependency, no rate limits, full commercial
  rights — the sanctioned path if you need backend control / offline-without-API.
- **Attribution:** **None required.**
- **Scaling:** Ultra supports production apps; at very high volume, move to Data Pack or an
  Enterprise agreement (custom limits / SLA / dedicated infra).
