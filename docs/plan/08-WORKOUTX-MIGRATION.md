# 08 — WorkoutX Exercise API Migration

**Status:** Planned, not started.
**Audience:** This document is a self-contained implementation brief. It assumes you have access to this Flutter repo **and** the project's Supabase backend, but no prior context on the discussion that produced it.

---

## 1. Goal

Replace the app's exercise data source. Today the app ships ~1,500 ExerciseDB exercises bundled in `assets/exercises.json`, seeded into a local Drift/SQLite table, and hotlinks GIFs from `static.exercisedb.dev`. We are switching to the **WorkoutX REST API** (`https://api.workoutxapp.com/v1`) for three reasons:

1. **Legal/licensing safety** — this is a paid subscription app; WorkoutX grants an explicit commercial license for its GIFs/data, removing the murky-terms risk of the current ExerciseDB hotlinking.
2. **AI workout generator** — WorkoutX exposes `/v1/workout/generate` (Pro+ plan).
3. Forward-looking metadata (similar/alternative exercises, calorie estimates).

> ⚠️ **Reality check, do not skip:** WorkoutX is repackaged ExerciseDB. The *content* is the same (~1,400 vs the current 1,500 exercises). This migration is justified by **licensing + the AI generator**, not by better/more exercises. Don't expect a content upgrade.

### Two explicit product decisions (locked by the product owner)

- **Remove the current bundled exercises entirely.** Drop `assets/exercises.json` and the seed-from-assets flow.
- **Cache only what the user needs offline.** The exercise browser becomes **online** (fetch-on-demand via the proxy). The app **caches into local Drift only the exercises the user has saved into a workout program (and exercises they actually log)** — so they can train offline in the gym without losing their program's exercise data. This respects WorkoutX's ToS, which forbids "cache exercise data in bulk beyond what is needed for your application." Caching the user's own program ≠ bulk caching.

---

## 2. WorkoutX API reference (verified)

- **Base URL:** `https://api.workoutxapp.com/v1`
- **Auth:** HTTP header `X-WorkoutX-Key: wx_...` (server-side only — never ship in the app).
- **Plan needed:** **Pro ($15.99/mo)** — required for multi-filter search and the AI generator. (Free=500 req/mo, Basic=3k, Pro=10k, Ultra=35k.)

### Endpoints
| Endpoint | Purpose |
|---|---|
| `GET /v1/exercises?limit=&offset=` | Paginated list |
| `GET /v1/exercises/exercise/:id` | Single exercise by id |
| `GET /v1/exercises/name/:name` | Partial-name search |
| `GET /v1/exercises/search` | Multi-filter (Basic+) |
| `GET /v1/exercises/bodyPart/:bodyPart` | Filter by body part |
| `GET /v1/exercises/target/:target` | Filter by target muscle |
| `GET /v1/exercises/equipment/:equipment` | Filter by equipment |
| `GET /v1/exercises/bodyPartList` / `targetList` / `equipmentList` | Filter vocabularies |
| `GET /v1/exercises/:id/similar` / `:id/alternatives` / `:id/calories` | Smart endpoints |
| `GET /v1/workout/generate?goal=&level=&split=` | AI generator (Pro+) |

### Exercise object shape (WorkoutX)
```json
{
  "id": "0001",
  "name": "3/4 sit-up",
  "bodyPart": "waist",
  "target": "abs",
  "equipment": "body weight",
  "gifUrl": "https://<supabase-storage>/exercise-gifs/0001.gif",
  "instructions": ["Lie down ...", "Place your hands ..."],
  "secondaryMuscles": ["hip flexors", "lower back"]
}
```

**Critical differences from our current data:**
- WorkoutX uses **singular string** fields (`bodyPart`, `target`, `equipment`); our schema uses **JSON-array** columns (`bodyParts`, `targetMuscles`, `equipments`). → Wrap each singular value in a one-element array on ingest.
- WorkoutX has **no `difficulty`** field. → Not a problem: the app *derives* difficulty locally (see §6).
- WorkoutX **IDs differ** (`0001`) from our current ExerciseDB v1 IDs (`2gPfomN`). → See §7 (migration).

---

## 3. Target architecture

```
Flutter app  ──►  Supabase Edge Function "workoutx" (holds API key, caches)  ──►  api.workoutxapp.com
     │
     └──►  Local Drift "exercises" table = per-user cache (program + logged exercises only)
```

- The app **never** calls WorkoutX directly (key protection). It calls the Edge Function via `supabase.functions.invoke('workoutx', ...)` — the same mechanism already used for `delete-account` ([auth_notifier.dart:300](../../lib/core/auth/auth_notifier.dart#L300)).
- The local `exercises` table stops being a full mirror and becomes a **cache** populated on-save / on-log.

---

## 4. PART A — Supabase backend (Edge Function proxy)

> This is the portion that requires Supabase access. Deliver this first; the Flutter work (Part B) depends on it.

### A1. Store the API key as a secret
```bash
supabase secrets set WORKOUTX_API_KEY=wx_xxxxxxxxxxxx
```
Never commit it; never expose it to the client.

### A2. Edge Function `workoutx`
Create `supabase/functions/workoutx/index.ts`. It forwards a whitelisted set of GET paths to WorkoutX, injecting the key header. Reject any non-whitelisted path. Add short-TTL caching and basic per-user rate limiting.

```ts
// supabase/functions/workoutx/index.ts
import { serve } from "https://deno.land/std/http/server.ts";

const BASE = "https://api.workoutxapp.com/v1";
const KEY = Deno.env.get("WORKOUTX_API_KEY")!;

// Whitelist of allowed upstream paths (prefix match). Everything else 403s.
const ALLOWED = [
  "/exercises", "/exercises/exercise/", "/exercises/name/",
  "/exercises/search", "/exercises/bodyPart/", "/exercises/target/",
  "/exercises/equipment/", "/exercises/bodyPartList",
  "/exercises/targetList", "/exercises/equipmentList",
  "/exercises/", // covers /:id/similar|alternatives|calories
  "/workout/generate",
];

serve(async (req) => {
  // Supabase verifies the caller's JWT automatically when verify_jwt = true.
  const { path, query } = await req.json().catch(() => ({ path: "", query: "" }));
  if (typeof path !== "string" || !ALLOWED.some((p) => path.startsWith(p))) {
    return new Response(JSON.stringify({ error: "forbidden path" }), { status: 403 });
  }
  const url = `${BASE}${path}${query ? `?${query}` : ""}`;
  const upstream = await fetch(url, { headers: { "X-WorkoutX-Key": KEY } });
  const body = await upstream.text();
  return new Response(body, {
    status: upstream.status,
    headers: {
      "content-type": "application/json",
      // Edge cache for list/search responses (tune as needed).
      "cache-control": "public, max-age=86400",
    },
  });
});
```

Deploy:
```bash
supabase functions deploy workoutx
```

Keep `verify_jwt = true` (default) so only authenticated app users can call it — this is the rate-abuse guard.

### A3. (Optional, later) AI generator hardening
`/workout/generate` is the most expensive call. Consider caching generated plans per (goal, level, split) tuple in a Supabase table to stay under the 10k/mo Pro quota.

### A4. Quota monitoring
Add a lightweight counter (a `workoutx_usage` table incremented per call, or log-based) so you can watch monthly request volume against the Pro 10k cap and upgrade to Ultra if needed.

---

## 5. PART B — Flutter client changes

### B1. New API client → `lib/core/services/exercise_api_service.dart`
Thin wrapper over `supabase.functions.invoke('workoutx', body: {path, query})`. Returns parsed `WorkoutXExercise` DTOs. No `http`/`dio` dependency needed — reuse the existing Supabase functions client.

```dart
class ExerciseApiService {
  ExerciseApiService(this._sb);
  final SupabaseClient _sb;

  Future<List<WorkoutXExercise>> list({int limit = 30, int offset = 0}) =>
      _get('/exercises', 'limit=$limit&offset=$offset');

  Future<List<WorkoutXExercise>> searchByName(String name) =>
      _get('/exercises/name/${Uri.encodeComponent(name)}', '');

  Future<List<WorkoutXExercise>> byTarget(String target) =>
      _get('/exercises/target/${Uri.encodeComponent(target)}', '');

  Future<List<WorkoutXExercise>> _get(String path, String query) async {
    final res = await _sb.functions.invoke('workoutx',
        body: {'path': path, 'query': query});
    final data = res.data as List<dynamic>;
    return data.map((e) => WorkoutXExercise.fromJson(e)).toList();
  }
}
```
Register `exerciseApiServiceProvider` alongside the existing providers in [providers.dart](../../lib/core/providers/providers.dart).

### B2. DTO + mapping → `WorkoutXExercise`
Map WorkoutX's singular fields into the existing array-shaped `ExercisesCompanion`. **Reuse the existing local heuristics** for `muscleGroup` and `difficulty` — do not delete them; move/keep `_resolveGymMuscleGroup` and `_resolveDifficulty` (currently private statics in [exercise_local_service.dart](../../lib/core/services/exercise_local_service.dart)) into a shared helper both the seeder-removal and the new mapper can call.

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
  muscleGroup: Value(resolveGymMuscleGroup(
      target: w.target, bodyPart: w.bodyPart, exerciseName: w.name)),
  difficulty: Value(resolveDifficulty(
      equipments: [w.equipment], secondaryMuscles: w.secondaryMuscles, name: w.name)),
  isCustom: const Value(false),
);
```

### B3. Caching strategy (the core of this migration)
Introduce an `ExerciseRepository` that is the single source of truth for the UI:

- **Browse/search** → goes to `ExerciseApiService` (online). Paginated, debounced.
- **Read a known exercise by id** (program/history/active session) → **local-first**: `ExerciseDao.findByExerciseId`; on miss *and* online, fetch from API and cache.
- **Cache-on-save**: whenever an exercise is added to a schedule (`ScheduleDao.addExercise` / wherever `ScheduledExercises` rows are created), `upsert` the full exercise into the local `exercises` table. `ExerciseDao.upsert` already exists ([exercise_dao.dart:64](../../lib/core/database/daos/exercise_dao.dart#L64)).
- **Cache-on-log**: whenever a `SessionExercises` row is created during a workout, upsert the exercise too. This keeps history enrichment + muscle-recovery working offline (`MuscleRecoveryService` and session enrichment read local `exercises` via `findByExerciseIds` — see [workout_providers.dart:268,826](../../lib/features/workout/workout_providers.dart#L268)).

Net effect: the local `exercises` table contains exactly the exercises the user has engaged with — their program + their logged history. Compliant with ToS, and fully offline for the gym.

### B4. Remove the bundled dataset & seeding
- Delete `assets/exercises.json` and its `pubspec.yaml` asset entry.
- In [main.dart](../../lib/main.dart): remove the `seedFromAssets` call (`_backgroundDbInit`, ~line 179). Keep `remapMuscleGroups`/`backfillDifficulty`? No — these operate on bundled data; they become no-ops once the cache is API-fed (mapping happens at ingest in B2). Remove or repurpose.
- In [sign_up_screen.dart](../../lib/features/onboarding/screens/sign_up_screen.dart#L130): remove the two `seedFromAssets` calls.
- `ExerciseLocalService` shrinks to just the shared `resolveGymMuscleGroup` / `resolveDifficulty` helpers (rename to e.g. `ExerciseMapping`).

### B5. Rework the browser/picker UI
- [exercise_browser_screen.dart](../../lib/features/exercises/exercise_browser_screen.dart): replace the "all local rows, recent-25 + A–Z" model with **paginated online lists** + **debounced search** hitting `ExerciseRepository`. Add empty/error/offline states. Filter dropdowns (bodyPart/target/equipment) can be seeded from the `*List` endpoints (cache these vocab lists locally — tiny, allowed).
- [log_bottom_sheet.dart](../../lib/features/workout/log_bottom_sheet.dart) and the exercise detail sheet: these read a *known* exercise → use the local-first repository path (B3), so they work offline for cached exercises.
- GIFs: `cached_network_image` is already used; just point at the new `gifUrl` values. Lazy-load as today.

### B6. Rework `ProgramSeeder`
Good news: [program_seeder.dart](../../lib/core/services/program_seeder.dart) already resolves exercises **by name** (`_id(name)` searches the DB, else creates a custom row — line 34). Update `_id()` to: search local cache → else `ExerciseApiService.searchByName` → cache the best match → else fall back to a custom exercise (as today). This means the default starter program auto-populates from WorkoutX and seeds the cache at the same time. Requires network on first program seed; handle the offline-first-launch case (defer seeding until online, or keep a tiny bundled fallback set of ~10 starter exercises — product decision, see §9).

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
| `instructions` | `instructions` | `jsonEncode(v)` (strip any `Step:n` prefixes if present) |
| `muscleGroup` | — | derive via `resolveGymMuscleGroup` |
| `difficulty` | — | derive via `resolveDifficulty` |
| `isCustom` | — | `false` |
| `usageCount` / `isFavorite` | — | local-only, unchanged |

---

## 7. ID migration for existing installs

WorkoutX IDs (`0001`) ≠ current IDs (`2gPfomN`). Tables holding the string id: **`ScheduledExercises.exerciseId`** (the user's program) and **`SessionExercises.exerciseId`** (history). See [app_database.dart:110,147](../../lib/core/database/app_database.dart#L110).

**Recommended approach — clean wipe (app is pre-launch / no production users):**
- Add a Drift migration (bump `schemaVersion` from 13 → 14) that **deletes all non-custom rows** from `exercises` (`DELETE FROM exercises WHERE is_custom = 0`). The cache repopulates from the API going forward.
- Existing dev/test logs that referenced old IDs will orphan their exercise metadata. Acceptable pre-launch. The active program (`ScheduledExercises`) should be re-seeded via the reworked `ProgramSeeder` (§B6), which re-resolves by name → new IDs.

**Only if there are real users to preserve** (decide before shipping): build a name-based old→new remap (fetch each old exercise's name, `searchByName` on WorkoutX, take best match) and rewrite `exerciseId` in `ScheduledExercises` + `SessionExercises`. Unmatched exercises convert to local custom entries so no history is lost. This is significantly more work — avoid it if the user base is zero.

---

## 8. AI workout generator (optional, after core migration)

- Add `ExerciseApiService.generateWorkout({goal, level, split})` → `/workout/generate`.
- Surface behind the existing paywall (the app already has paywall + RevenueCat wiring).
- Map the returned plan (`order`, `sets`, `reps`, `restSeconds`, nested exercise) into `Schedules` / `ScheduleDays` / `ScheduledExercises`, caching each exercise as it's added.

---

## 9. Open decisions before coding

1. **First-launch offline:** the browser and default-program seeding need network on first run. Options: (a) require connectivity for first launch, (b) ship a tiny ~10-exercise bundled fallback for the starter program only. **Recommend (b)** for a smooth cold start.
2. **WorkoutX plan tier:** confirm **Pro** (needed for AI generator + multi-filter search).
3. **ID migration:** confirm the app has **no production users** so we can use the clean-wipe path (§7). If there are users, budget for the name-remap.
4. **GIF longevity:** WorkoutX GIFs live on their Supabase storage. `cached_network_image` caches them per-device after first view — that's the offline GIF story for cached exercises. Confirm acceptable.

---

## 10. Build order / checklist

1. **[Backend]** Set `WORKOUTX_API_KEY` secret; deploy `workoutx` Edge Function (§4). Smoke-test with a curl-via-invoke.
2. **[Client]** `ExerciseApiService` + `WorkoutXExercise` DTO + mapper, reusing the existing muscle/difficulty heuristics (§B1, B2).
3. **[Client]** `ExerciseRepository` with local-first reads + cache-on-save + cache-on-log (§B3).
4. **[Client]** Remove bundled JSON + all `seedFromAssets` calls; shrink `ExerciseLocalService` to shared helpers (§B4).
5. **[Client]** Rework browser/picker for online paginated + debounced search; offline states (§B5).
6. **[Client]** Rework `ProgramSeeder` to resolve names via API + cache (§B6).
7. **[Client]** Schema v14 migration: wipe non-custom exercises (§7).
8. **[Client]** Re-verify `MuscleRecoveryService` + history enrichment against the cache.
9. **[Optional]** AI generator behind paywall (§8).
10. **Test:** offline gym flow (start a logged program with no network), online browse/search, quota usage, App Store/Play compliance.
```
