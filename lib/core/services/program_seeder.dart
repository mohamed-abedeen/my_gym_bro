import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../database/daos/exercise_dao.dart';
import '../database/daos/schedule_dao.dart';
import 'exercise_repository.dart';
import 'workoutx_exercise.dart';

/// Seeds the database with 3 ready-to-use training programs:
/// Arnold Split, Bro Split, Push/Pull/Legs.
///
/// Exercises are resolved by NAME (not hard-coded ids, which used to come from
/// the bundled JSON). Resolution order per name:
///   1. in-memory cache (within this seed run),
///   2. local exercise cache — the bundled starter set + anything already
///      cached (works fully offline),
///   3. the WorkoutX API search-by-name (Pro/Ultra; gated on free), which the
///      repository caches,
///   4. a custom, name-only exercise as a last resort.
///
/// Call once at startup (guarded by a check so it doesn't re-seed).
class ProgramSeeder {
  final ScheduleDao _scheduleDao;
  final ExerciseDao _exerciseDao;
  final ExerciseRepository _repo;

  ProgramSeeder(AppDatabase db, this._repo)
      : _scheduleDao = ScheduleDao(db),
        _exerciseDao = ExerciseDao(db);

  /// Bundled starter dataset: a tiny set of real WorkoutX exercises shipped in
  /// the app so the default program resolves to rich data (gif + muscle group)
  /// even on the very first launch with no network.
  static const _starterAsset = 'assets/exercises_starter.json';

  /// Returns true if programs were seeded, false if they already exist.
  Future<bool> seedIfNeeded() async {
    final existing = await _scheduleDao.getAll();
    if (existing.isNotEmpty) return false;

    // Make sure the bundled starter set is in the cache before resolving names
    // so the default program works offline on first launch.
    await ensureStarterCached();

    await _seedArnoldSplit();
    await _seedBroSplit();
    await _seedPushPullLegs();
    return true;
  }

  /// Loads the bundled starter set into the local cache (idempotent).
  /// Safe to call on every launch; [ExerciseDao.cacheAll] upserts by id.
  Future<void> ensureStarterCached() async {
    try {
      final raw = await rootBundle.loadString(_starterAsset);
      final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>();
      final companions = list
          .map((j) => WorkoutXExercise.fromJson(j).toCompanion())
          .toList();
      await _exerciseDao.cacheAll(companions);
    } catch (_) {
      // Missing/invalid asset must never crash startup — names will simply
      // resolve via the API (online) or fall back to custom exercises.
    }
  }

  // ─── Exercise lookup / creation ───────────────────────────────────

  final Map<String, String> _cache = {};

  String _remember(String key, String id) {
    _cache[key] = id;
    return id;
  }

  /// Picks the best name match: exact (case-insensitive) first, otherwise the
  /// shortest name that contains the term.
  Exercise? _pickByName(List<Exercise> results, String name) {
    if (results.isEmpty) return null;
    final key = name.toLowerCase();
    for (final e in results) {
      if (e.name.toLowerCase() == key) return e;
    }
    final sorted = [...results]
      ..sort((a, b) => a.name.length.compareTo(b.name.length));
    return sorted.first;
  }

  /// Resolves a program exercise name to an exerciseId.
  Future<String> _id(String name, {String? muscleGroup}) async {
    final key = name.toLowerCase();
    final cached = _cache[key];
    if (cached != null) return cached;

    // 2. Local cache (bundled starter + previously cached) — no network.
    final local = _pickByName(await _exerciseDao.searchByName(name), name);
    if (local != null) return _remember(key, local.exerciseId);

    // 3. API search by name (Pro/Ultra). Skipped when no key or known gated.
    if (_repo.isOnlineCapable && !_repo.isSearchPlanGated) {
      try {
        final page = await _repo.searchByName(name, limit: 10);
        final match = _pickByName(page.items, name);
        if (match != null) return _remember(key, match.exerciseId);
      } catch (_) {
        // fall through to custom
      }
    }

    // 4. Custom, name-only fallback.
    final customId = 'custom_${key.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    await _exerciseDao.cacheOne(ExercisesCompanion(
      exerciseId: Value(customId),
      name: Value(name),
      muscleGroup: Value(muscleGroup),
      isCustom: const Value(true),
    ));
    return _remember(key, customId);
  }

  // ─── Helper to build a schedule ───────────────────────────────────

  Future<void> _buildSchedule({
    required String name,
    required bool isActive,
    required List<_DayDef> days,
  }) async {
    final scheduleId = await _scheduleDao.createSchedule(SchedulesCompanion(
      name: Value(name),
      isActive: Value(isActive),
      createdAt: Value(DateTime.now()),
    ));

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final dayId = await _scheduleDao.addDay(ScheduleDaysCompanion(
        scheduleId: Value(scheduleId),
        dayIndex: Value(i),
        label: Value(day.label),
        isRestDay: Value(day.isRest),
      ));

      if (!day.isRest) {
        for (var j = 0; j < day.exercises.length; j++) {
          final ex = day.exercises[j];
          final exerciseId = await _id(ex.name, muscleGroup: ex.muscleGroup);
          await _scheduleDao.addExercise(ScheduledExercisesCompanion(
            scheduleDayId: Value(dayId),
            exerciseId: Value(exerciseId),
            orderIndex: Value(j),
            targetSets: Value(ex.sets),
            targetReps: Value(ex.reps),
          ));
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. Arnold Split (Variation 2 — high volume, 6 days)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seedArnoldSplit() async {
    final chestBackLegs = _DayDef('Chest, Back & Legs', [
      // Chest
      _Ex('Barbell Bench Press', 5, 8, 'Chest'),
      _Ex('Dumbbell Fly', 5, 8, 'Chest'),
      _Ex('Barbell Incline Bench Press', 6, 8, 'Chest'),
      _Ex('Cable Cross-Over', 6, 11, 'Chest'),
      _Ex('Chest Dip', 5, 12, 'Chest'),
      _Ex('Dumbbell Pullover', 5, 11, 'Chest'),
      // Back
      _Ex('Wide Grip Pull-Up', 6, 10, 'Lats'),
      _Ex('Lever Reverse T-Bar Row', 5, 8, 'Lats'),
      _Ex('Cable Seated Row', 6, 8, 'Upper Back'),
      _Ex('One Arm Dumbbell Row', 5, 8, 'Lats'),
      _Ex('Barbell Straight Leg Deadlift', 6, 15, 'Hamstrings'),
      // Legs
      _Ex('Barbell Full Squat', 6, 10, 'Quads'),
      _Ex('Sled 45° Leg Press', 6, 10, 'Quads'),
      _Ex('Lever Leg Extension', 6, 13, 'Quads'),
      _Ex('Lever Lying Leg Curl', 6, 12, 'Hamstrings'),
      _Ex('Barbell Lunge', 5, 15, 'Quads'),
      // Calves
      _Ex('Lever Standing Calf Raise', 10, 10, 'Calves'),
      _Ex('Lever Seated Calf Raise', 8, 15, 'Calves'),
      // Forearms
      _Ex('Barbell Wrist Curl', 4, 10, 'Forearms'),
      _Ex('Barbell Reverse Curl', 4, 8, 'Forearms'),
    ]);

    final shouldersArms = _DayDef('Shoulders & Arms', [
      // Biceps
      _Ex('Barbell Curl', 6, 8, 'Biceps'),
      _Ex('Dumbbell Seated Curl', 6, 8, 'Biceps'),
      _Ex('Dumbbell Concentration Curl', 6, 8, 'Biceps'),
      // Triceps
      _Ex('Barbell Close-Grip Bench Press', 6, 8, 'Triceps'),
      _Ex('Cable Triceps Pushdown', 6, 8, 'Triceps'),
      _Ex('Barbell Lying Triceps Extension', 6, 8, 'Triceps'),
      _Ex('Cable Overhead Triceps Extension', 6, 8, 'Triceps'),
      // Shoulders
      _Ex('Barbell Seated Overhead Press', 6, 8, 'Shoulders'),
      _Ex('Dumbbell Lateral Raise', 6, 8, 'Shoulders'),
      _Ex('Dumbbell Rear Delt Raise', 5, 8, 'Shoulders'),
      _Ex('Cable Lateral Raise', 5, 11, 'Shoulders'),
      // Calves
      _Ex('Lever Standing Calf Raise', 10, 10, 'Calves'),
      _Ex('Lever Seated Calf Raise', 8, 15, 'Calves'),
      // Forearms
      _Ex('Barbell Wrist Curl', 4, 10, 'Forearms'),
      _Ex('Barbell Reverse Curl', 4, 8, 'Forearms'),
    ]);

    await _buildSchedule(
      name: 'Arnold Split',
      isActive: true,
      days: [
        chestBackLegs,           // Day 1
        shouldersArms,           // Day 2
        chestBackLegs,           // Day 3
        shouldersArms,           // Day 4
        chestBackLegs,           // Day 5
        shouldersArms,           // Day 6
        _DayDef.rest('Rest Day'), // Day 7
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. Bro Split (5-day, one body part per day)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seedBroSplit() async {
    await _buildSchedule(
      name: 'Bro Split',
      isActive: false,
      days: [
        // Monday: Chest
        _DayDef('Chest Day', [
          _Ex('Barbell Bench Press', 3, 10, 'Chest'),
          _Ex('Dumbbell Incline Bench Press', 3, 10, 'Chest'),
          _Ex('Dumbbell Decline Hammer Press', 3, 10, 'Chest'),
          _Ex('Pec Dec', 3, 10, 'Chest'),
          _Ex('Push-Up', 3, 10, 'Chest'),
        ]),
        // Tuesday: Legs
        _DayDef('Leg Day', [
          _Ex('Barbell Full Squat', 3, 10, 'Quads'),
          _Ex('Sled Hack Squat', 3, 10, 'Quads'),
          _Ex('Sled 45° Leg Press', 3, 10, 'Quads'),
          _Ex('Lever Leg Extension', 3, 10, 'Quads'),
          _Ex('Lever Lying Leg Curl', 3, 10, 'Hamstrings'),
          _Ex('Lever Standing Calf Raise', 3, 10, 'Calves'),
        ]),
        // Wednesday: Shoulders
        _DayDef('Shoulder Day', [
          _Ex('Dumbbell Seated Shoulder Press', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Arnold Press', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Lateral Raise', 3, 10, 'Shoulders'),
          _Ex('Barbell Upright Row', 3, 10, 'Shoulders'),
          _Ex('Reverse Fly Machine', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Shrug', 3, 10, 'Traps'),
        ]),
        // Thursday: Back
        _DayDef('Back Day', [
          _Ex('Barbell Deadlift', 3, 10, 'Lower Back'),
          _Ex('Cable Lat Pulldown Full Range of Motion', 3, 10, 'Lats'),
          _Ex('Hammer Strength Row', 3, 10, 'Upper Back'),
          _Ex('Cable Seated Row', 3, 10, 'Upper Back'),
          _Ex('Cable Straight Arm Pulldown', 3, 10, 'Lats'),
        ]),
        // Friday: Arms
        _DayDef('Arm Day', [
          _Ex('Barbell Curl', 3, 10, 'Biceps'),
          _Ex('Barbell Preacher Curl', 3, 10, 'Biceps'),
          _Ex('Dumbbell Incline Curl', 3, 10, 'Biceps'),
          _Ex('Weighted Tricep Dips', 3, 10, 'Triceps'),
          _Ex('Barbell Lying Triceps Extension', 3, 10, 'Triceps'),
          _Ex('Cable Triceps Pushdown', 3, 10, 'Triceps'),
        ]),
        // Saturday & Sunday
        _DayDef.rest('Rest Day'),
        _DayDef.rest('Rest Day'),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. Push / Pull / Legs (3-day beginner)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seedPushPullLegs() async {
    await _buildSchedule(
      name: 'Push Pull Legs',
      isActive: false,
      days: [
        // Push Day
        _DayDef('Push Day', [
          _Ex('Barbell Seated Overhead Press', 5, 5, 'Shoulders'),
          _Ex('Dumbbell Bench Press', 3, 5, 'Chest'),
          _Ex('Weighted Tricep Dips', 3, 8, 'Triceps'),
          _Ex('Dumbbell Lateral Raise', 3, 8, 'Shoulders'),
          _Ex('Dumbbell Lying Triceps Extension', 3, 8, 'Triceps'),
          _Ex('Cable Triceps Pushdown', 3, 8, 'Triceps'),
        ]),
        // Pull Day
        _DayDef('Pull Day', [
          _Ex('Pull-Up', 5, 5, 'Lats'),
          _Ex('Barbell Bent Over Row', 3, 5, 'Upper Back'),
          _Ex('Lever Reverse T-Bar Row', 3, 8, 'Lats'),
          _Ex('Dumbbell Shrug', 3, 8, 'Traps'),
          _Ex('Barbell Preacher Curl', 3, 8, 'Biceps'),
          _Ex('Dumbbell Hammer Curl', 3, 8, 'Biceps'),
        ]),
        // Leg Day
        _DayDef('Leg Day', [
          _Ex('Barbell Full Squat', 5, 5, 'Quads'),
          _Ex('Barbell Deadlift', 3, 5, 'Lower Back'),
          _Ex('Sled 45° Leg Press', 3, 8, 'Quads'),
          _Ex('Lever Lying Leg Curl', 3, 8, 'Hamstrings'),
          _Ex('Lever Leg Extension', 3, 8, 'Quads'),
          _Ex('Lever Seated Calf Raise', 3, 8, 'Calves'),
        ]),
        // Rest days
        _DayDef.rest('Rest Day'),
      ],
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────

class _DayDef {
  final String label;
  final List<_Ex> exercises;
  final bool isRest;

  const _DayDef(this.label, this.exercises) : isRest = false;
  const _DayDef.rest(this.label)
      : exercises = const [],
        isRest = true;
}

class _Ex {
  final String name;
  final int sets;
  final int reps;
  final String? muscleGroup;

  const _Ex(this.name, this.sets, this.reps, [this.muscleGroup]);
}
