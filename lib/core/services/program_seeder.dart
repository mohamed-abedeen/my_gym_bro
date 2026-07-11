import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/services/api_exercise.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';

/// Seeds the database with 3 ready-to-use training programs:
/// Arnold Split, Bro Split, Push/Pull/Legs.
///
/// Exercises are no longer bundled in bulk — they come from the exercise API.
/// [ensureStarterCached] loads a tiny bundled starter set so the default
/// program has rich data even on a first launch with no network; remaining
/// exercises resolve via the API (and get cached) when online, or fall back to
/// loggable custom rows offline.
///
/// Call once at startup (guarded by a check so it doesn't re-seed).
class ProgramSeeder {
  ProgramSeeder(AppDatabase db, this._repo)
      : _scheduleDao = ScheduleDao(db),
        _exerciseDao = ExerciseDao(db);

  final ScheduleDao _scheduleDao;
  final ExerciseDao _exerciseDao;
  final ExerciseRepository _repo;

  /// Loads the bundled starter set (`assets/exercises_starter.json`) into the
  /// local cache. Idempotent — safe to call on every launch. Non-fatal on
  /// failure so startup is never blocked.
  Future<void> ensureStarterCached() async {
    try {
      final raw = await rootBundle.loadString('assets/exercises_starter.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final companions =
          list.map((j) => ApiExercise.fromJson(j).toCompanion()).toList();
      await _exerciseDao.cacheAll(companions);
    } on Object {
      // Non-fatal — the default program still seeds with custom fallbacks.
    }
  }

  /// Returns true if programs were seeded, false if they already exist.
  Future<bool> seedIfNeeded() async {
    final existing = await _scheduleDao.getAll();
    if (existing.isNotEmpty) return false;

    await _seedArnoldSplit();
    await _seedBroSplit();
    await _seedPushPullLegs();
    return true;
  }

  // ─── Exercise lookup / creation ───────────────────────────────────

  final Map<String, String> _cache = {};

  /// Resolves an `exerciseId` for [name]:
  ///   1. local cache — exact match, then shortest partial,
  ///   2. exercise API by name (results are cached as a side effect),
  ///   3. a loggable custom exercise as a last resort (offline / no match).
  Future<String> _id(String name, {String? muscleGroup}) async {
    final key = name.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;

    // 1. Local cache.
    final local = await _exerciseDao.searchByName(name);
    final localExact =
        local.where((e) => e.name.toLowerCase() == key).toList();
    if (localExact.isNotEmpty) {
      return _cache[key] = localExact.first.exerciseId;
    }
    if (local.isNotEmpty) {
      local.sort((a, b) => a.name.length.compareTo(b.name.length));
      return _cache[key] = local.first.exerciseId;
    }

    // 2. Online lookup (repo caches matched rows).
    if (_repo.isOnlineCapable) {
      try {
        final items = (await _repo.searchByName(name)).items;
        final onlineExact =
            items.where((e) => e.name.toLowerCase() == key).toList();
        if (onlineExact.isNotEmpty) {
          return _cache[key] = onlineExact.first.exerciseId;
        }
        if (items.isNotEmpty) {
          items.sort((a, b) => a.name.length.compareTo(b.name.length));
          return _cache[key] = items.first.exerciseId;
        }
      } on Object {
        // fall through to custom
      }
    }

    // 3. Custom fallback.
    final customId = 'custom_${key.replaceAll(RegExp('[^a-z0-9]'), '_')}';
    await _exerciseDao.upsert(ExercisesCompanion(
      exerciseId: Value(customId),
      name: Value(name),
      muscleGroup: Value(muscleGroup),
      isCustom: const Value(true),
    ));
    return _cache[key] = customId;
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
        isRestDay: const Value(false),
      ));

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

  // ═══════════════════════════════════════════════════════════════════
  // 1. Arnold Split (Variation 2 — high volume, 6 days)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seedArnoldSplit() async {
    const chestBackLegs = _DayDef('Chest, Back & Legs', [
      // Chest
      _Ex('Barbell Bench Press', 5, 8, 'Chest'),
      _Ex('Dumbbell Incline Fly', 5, 8, 'Chest'),
      _Ex('Barbell Incline Bench Press', 6, 8, 'Chest'),
      _Ex('Cable Cross-Over', 6, 11, 'Chest'),
      _Ex('Chest Dip', 5, 12, 'Chest'),
      _Ex('Dumbbell Pullover', 5, 11, 'Chest'),
      // Back
      _Ex('Wide Grip Pull-Up', 6, 10, 'Lats'),
      _Ex('Lever Reverse T-Bar Row', 5, 8, 'Lats'),
      _Ex('Cable Seated Row', 6, 8, 'Upper Back'),
      _Ex('Dumbbell One Arm Bent-Over Row', 5, 8, 'Lats'),
      _Ex('Barbell Straight Leg Deadlift', 6, 15, 'Hamstrings'),
      // Legs
      _Ex('Barbell Full Squat', 6, 10, 'Quads'),
      _Ex('Sled 45° Leg Press (Side POV)', 6, 10, 'Quads'),
      _Ex('Lever Leg Extension', 6, 13, 'Quads'),
      _Ex('Lever Lying Leg Curl', 6, 12, 'Hamstrings'),
      _Ex('Barbell Lunge', 5, 15, 'Quads'),
      // Calves
      _Ex('Lever Standing Calf Raise', 10, 10, 'Calves'),
      _Ex('Lever Seated Calf Raise', 8, 15, 'Calves'),
      // Forearms
      _Ex('Barbell Wrist Curl', 4, 10, 'Forearms'),
      _Ex('Dumbbell Standing Reverse Curl', 4, 8, 'Forearms'),
    ]);

    const shouldersArms = _DayDef('Shoulders & Arms', [
      // Biceps
      _Ex('Barbell Curl', 6, 8, 'Biceps'),
      _Ex('Dumbbell Standing Biceps Curl', 6, 8, 'Biceps'),
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
      _Ex('Dumbbell Standing Reverse Curl', 4, 8, 'Forearms'),
    ]);

    await _buildSchedule(
      name: 'Arnold Split',
      isActive: true,
      days: [
        chestBackLegs, // Day 1
        shouldersArms, // Day 2
        chestBackLegs, // Day 3
        shouldersArms, // Day 4
        chestBackLegs, // Day 5
        shouldersArms, // Day 6
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
        const _DayDef('Chest Day', [
          _Ex('Barbell Bench Press', 3, 10, 'Chest'),
          _Ex('Dumbbell Incline Bench Press', 3, 10, 'Chest'),
          _Ex('Dumbbell Decline Hammer Press', 3, 10, 'Chest'),
          _Ex('Cable Decline Fly', 3, 10, 'Chest'),
          _Ex('Incline Push-Up', 3, 10, 'Chest'),
        ]),
        // Tuesday: Legs
        const _DayDef('Leg Day', [
          _Ex('Barbell Full Squat', 3, 10, 'Quads'),
          _Ex('Sled Hack Squat', 3, 10, 'Quads'),
          _Ex('Sled 45° Leg Press (Side POV)', 3, 10, 'Quads'),
          _Ex('Lever Leg Extension', 3, 10, 'Quads'),
          _Ex('Lever Lying Leg Curl', 3, 10, 'Hamstrings'),
          _Ex('Lever Standing Calf Raise', 3, 10, 'Calves'),
        ]),
        // Wednesday: Shoulders
        const _DayDef('Shoulder Day', [
          _Ex('Dumbbell Seated Shoulder Press', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Arnold Press', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Lateral Raise', 3, 10, 'Shoulders'),
          _Ex('Barbell Upright Row', 3, 10, 'Shoulders'),
          _Ex('Lever Seated Reverse Fly', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Shrug', 3, 10, 'Traps'),
        ]),
        // Thursday: Back
        const _DayDef('Back Day', [
          _Ex('Barbell Deadlift', 3, 10, 'Lower Back'),
          _Ex('Cable Lat Pulldown Full Range of Motion', 3, 10, 'Lats'),
          _Ex('Lever Bent-Over Row With V-Bar', 3, 10, 'Upper Back'),
          _Ex('Cable Seated Row', 3, 10, 'Upper Back'),
          _Ex('Cable Straight Arm Pulldown', 3, 10, 'Lats'),
        ]),
        // Friday: Arms
        const _DayDef('Arm Day', [
          _Ex('Barbell Curl', 3, 10, 'Biceps'),
          _Ex('Barbell Preacher Curl', 3, 10, 'Biceps'),
          _Ex('Dumbbell Incline Curl', 3, 10, 'Biceps'),
          _Ex('Weighted Tricep Dips', 3, 10, 'Triceps'),
          _Ex('Barbell Lying Triceps Extension', 3, 10, 'Triceps'),
          _Ex('Cable Triceps Pushdown', 3, 10, 'Triceps'),
        ]),
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
        const _DayDef('Push Day', [
          _Ex('Barbell Seated Overhead Press', 5, 5, 'Shoulders'),
          _Ex('Dumbbell Bench Press', 3, 5, 'Chest'),
          _Ex('Weighted Tricep Dips', 3, 8, 'Triceps'),
          _Ex('Dumbbell Lateral Raise', 3, 8, 'Shoulders'),
          _Ex('Dumbbell Lying Triceps Extension', 3, 8, 'Triceps'),
          _Ex('Cable Triceps Pushdown', 3, 8, 'Triceps'),
        ]),
        // Pull Day
        const _DayDef('Pull Day', [
          _Ex('Pull Up (Neutral Grip)', 5, 5, 'Lats'),
          _Ex('Barbell Bent Over Row', 3, 5, 'Upper Back'),
          _Ex('Lever Reverse T-Bar Row', 3, 8, 'Lats'),
          _Ex('Dumbbell Shrug', 3, 8, 'Traps'),
          _Ex('Barbell Preacher Curl', 3, 8, 'Biceps'),
          _Ex('Dumbbell Hammer Curl', 3, 8, 'Biceps'),
        ]),
        // Leg Day
        const _DayDef('Leg Day', [
          _Ex('Barbell Full Squat', 5, 5, 'Quads'),
          _Ex('Barbell Deadlift', 3, 5, 'Lower Back'),
          _Ex('Sled 45° Leg Press (Side POV)', 3, 8, 'Quads'),
          _Ex('Lever Lying Leg Curl', 3, 8, 'Hamstrings'),
          _Ex('Lever Leg Extension', 3, 8, 'Quads'),
          _Ex('Lever Seated Calf Raise', 3, 8, 'Calves'),
        ]),
      ],
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────

class _DayDef {
  const _DayDef(this.label, this.exercises);
  final String label;
  final List<_Ex> exercises;
}

class _Ex {
  const _Ex(this.name, this.sets, this.reps, [this.muscleGroup]);
  final String name;
  final int sets;
  final int reps;
  final String? muscleGroup;
}
