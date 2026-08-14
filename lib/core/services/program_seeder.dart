import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/services/api_exercise.dart';
import 'package:my_gym_bro/core/services/exercise_mapping.dart';
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
/// [buildSchedule] is also used by the pre-made programs screen to install
/// a catalog program on demand.
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
      final companions = list
          .map((j) => ApiExercise.fromJson(j).toCompanion())
          .toList();
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
    final localExact = local.where((e) => e.name.toLowerCase() == key).toList();
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
        final onlineExact = items
            .where((e) => e.name.toLowerCase() == key)
            .toList();
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
    await _exerciseDao.upsert(
      ExercisesCompanion(
        exerciseId: Value(customId),
        name: Value(name),
        muscleGroup: Value(muscleGroup),
        // Equipment is unknowable offline, but difficulty can be derived
        // from the name — without it these rows vanish under any
        // difficulty filter in the browser.
        difficulty: Value(ExerciseMapping.resolveDifficulty(
          equipments: const [],
          secondaryMuscles: const [],
          name: name,
        )),
        isCustom: const Value(true),
      ),
    );
    return _cache[key] = customId;
  }

  // ─── Helper to build a schedule ───────────────────────────────────

  /// Creates a schedule with [days], resolving each exercise name to a real
  /// (or custom-fallback) exercise row. Returns the new schedule's local id.
  Future<int> buildSchedule({
    required String name,
    required bool isActive,
    required List<ProgramDay> days,
  }) async {
    final scheduleId = await _scheduleDao.createSchedule(
      SchedulesCompanion(
        name: Value(name),
        isActive: Value(isActive),
        createdAt: Value(DateTime.now()),
      ),
    );

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final dayId = await _scheduleDao.addDay(
        ScheduleDaysCompanion(
          scheduleId: Value(scheduleId),
          dayIndex: Value(i),
          label: Value(day.label),
          isRestDay: const Value(false),
        ),
      );

      for (var j = 0; j < day.exercises.length; j++) {
        final ex = day.exercises[j];
        final exerciseId = await _id(ex.name, muscleGroup: ex.muscleGroup);
        await _scheduleDao.addExercise(
          ScheduledExercisesCompanion(
            scheduleDayId: Value(dayId),
            exerciseId: Value(exerciseId),
            orderIndex: Value(j),
            targetSets: Value(ex.sets),
            targetReps: Value(ex.reps),
          ),
        );
      }
    }
    return scheduleId;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. Arnold Split (Variation 2 — high volume, 6 days)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seedArnoldSplit() async {
    const chestBackLegs = ProgramDay('Chest, Back & Legs', [
      // Chest
      ProgramExercise('Barbell Bench Press', 5, 8, 'Chest'),
      ProgramExercise('Dumbbell Incline Fly', 5, 8, 'Chest'),
      ProgramExercise('Barbell Incline Bench Press', 6, 8, 'Chest'),
      ProgramExercise('Cable Cross-Over', 6, 11, 'Chest'),
      ProgramExercise('Chest Dip', 5, 12, 'Chest'),
      ProgramExercise('Dumbbell Pullover', 5, 11, 'Chest'),
      // Back
      ProgramExercise('Wide Grip Pull-Up', 6, 10, 'Lats'),
      ProgramExercise('Lever Reverse T-Bar Row', 5, 8, 'Lats'),
      ProgramExercise('Cable Seated Row', 6, 8, 'Upper Back'),
      ProgramExercise('Dumbbell One Arm Bent-Over Row', 5, 8, 'Lats'),
      ProgramExercise('Barbell Straight Leg Deadlift', 6, 15, 'Hamstrings'),
      // Legs
      ProgramExercise('Barbell Full Squat', 6, 10, 'Quads'),
      ProgramExercise('Sled 45° Leg Press (Side POV)', 6, 10, 'Quads'),
      ProgramExercise('Lever Leg Extension', 6, 13, 'Quads'),
      ProgramExercise('Lever Lying Leg Curl', 6, 12, 'Hamstrings'),
      ProgramExercise('Barbell Lunge', 5, 15, 'Quads'),
      // Calves
      ProgramExercise('Lever Standing Calf Raise', 10, 10, 'Calves'),
      ProgramExercise('Lever Seated Calf Raise', 8, 15, 'Calves'),
      // Forearms
      ProgramExercise('Barbell Wrist Curl', 4, 10, 'Forearms'),
      ProgramExercise('Dumbbell Standing Reverse Curl', 4, 8, 'Forearms'),
    ]);

    const shouldersArms = ProgramDay('Shoulders & Arms', [
      // Biceps
      ProgramExercise('Barbell Curl', 6, 8, 'Biceps'),
      ProgramExercise('Dumbbell Standing Biceps Curl', 6, 8, 'Biceps'),
      ProgramExercise('Dumbbell Concentration Curl', 6, 8, 'Biceps'),
      // Triceps
      ProgramExercise('Barbell Close-Grip Bench Press', 6, 8, 'Triceps'),
      ProgramExercise('Cable Triceps Pushdown', 6, 8, 'Triceps'),
      ProgramExercise('Barbell Lying Triceps Extension', 6, 8, 'Triceps'),
      ProgramExercise('Cable Overhead Triceps Extension', 6, 8, 'Triceps'),
      // Shoulders
      ProgramExercise('Barbell Seated Overhead Press', 6, 8, 'Shoulders'),
      ProgramExercise('Dumbbell Lateral Raise', 6, 8, 'Shoulders'),
      ProgramExercise('Dumbbell Rear Delt Raise', 5, 8, 'Shoulders'),
      ProgramExercise('Cable Lateral Raise', 5, 11, 'Shoulders'),
      // Calves
      ProgramExercise('Lever Standing Calf Raise', 10, 10, 'Calves'),
      ProgramExercise('Lever Seated Calf Raise', 8, 15, 'Calves'),
      // Forearms
      ProgramExercise('Barbell Wrist Curl', 4, 10, 'Forearms'),
      ProgramExercise('Dumbbell Standing Reverse Curl', 4, 8, 'Forearms'),
    ]);

    await buildSchedule(
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
    await buildSchedule(
      name: 'Bro Split',
      isActive: false,
      days: [
        // Monday: Chest
        const ProgramDay('Chest Day', [
          ProgramExercise('Barbell Bench Press', 3, 10, 'Chest'),
          ProgramExercise('Dumbbell Incline Bench Press', 3, 10, 'Chest'),
          ProgramExercise('Dumbbell Decline Hammer Press', 3, 10, 'Chest'),
          ProgramExercise('Cable Decline Fly', 3, 10, 'Chest'),
          ProgramExercise('Incline Push-Up', 3, 10, 'Chest'),
        ]),
        // Tuesday: Legs
        const ProgramDay('Leg Day', [
          ProgramExercise('Barbell Full Squat', 3, 10, 'Quads'),
          ProgramExercise('Sled Hack Squat', 3, 10, 'Quads'),
          ProgramExercise('Sled 45° Leg Press (Side POV)', 3, 10, 'Quads'),
          ProgramExercise('Lever Leg Extension', 3, 10, 'Quads'),
          ProgramExercise('Lever Lying Leg Curl', 3, 10, 'Hamstrings'),
          ProgramExercise('Lever Standing Calf Raise', 3, 10, 'Calves'),
        ]),
        // Wednesday: Shoulders
        const ProgramDay('Shoulder Day', [
          ProgramExercise('Dumbbell Seated Shoulder Press', 3, 10, 'Shoulders'),
          ProgramExercise('Dumbbell Arnold Press', 3, 10, 'Shoulders'),
          ProgramExercise('Dumbbell Lateral Raise', 3, 10, 'Shoulders'),
          ProgramExercise('Barbell Upright Row', 3, 10, 'Shoulders'),
          ProgramExercise('Lever Seated Reverse Fly', 3, 10, 'Shoulders'),
          ProgramExercise('Dumbbell Shrug', 3, 10, 'Traps'),
        ]),
        // Thursday: Back
        const ProgramDay('Back Day', [
          ProgramExercise('Barbell Deadlift', 3, 10, 'Lower Back'),
          ProgramExercise(
            'Cable Lat Pulldown Full Range of Motion',
            3,
            10,
            'Lats',
          ),
          ProgramExercise(
            'Lever Bent-Over Row With V-Bar',
            3,
            10,
            'Upper Back',
          ),
          ProgramExercise('Cable Seated Row', 3, 10, 'Upper Back'),
          ProgramExercise('Cable Straight Arm Pulldown', 3, 10, 'Lats'),
        ]),
        // Friday: Arms
        const ProgramDay('Arm Day', [
          ProgramExercise('Barbell Curl', 3, 10, 'Biceps'),
          ProgramExercise('Barbell Preacher Curl', 3, 10, 'Biceps'),
          ProgramExercise('Dumbbell Incline Curl', 3, 10, 'Biceps'),
          ProgramExercise('Weighted Tricep Dips', 3, 10, 'Triceps'),
          ProgramExercise('Barbell Lying Triceps Extension', 3, 10, 'Triceps'),
          ProgramExercise('Cable Triceps Pushdown', 3, 10, 'Triceps'),
        ]),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. Push / Pull / Legs (3-day beginner)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seedPushPullLegs() async {
    await buildSchedule(
      name: 'Push Pull Legs',
      isActive: false,
      days: [
        // Push Day
        const ProgramDay('Push Day', [
          ProgramExercise('Barbell Seated Overhead Press', 5, 5, 'Shoulders'),
          ProgramExercise('Dumbbell Bench Press', 3, 5, 'Chest'),
          ProgramExercise('Weighted Tricep Dips', 3, 8, 'Triceps'),
          ProgramExercise('Dumbbell Lateral Raise', 3, 8, 'Shoulders'),
          ProgramExercise('Dumbbell Lying Triceps Extension', 3, 8, 'Triceps'),
          ProgramExercise('Cable Triceps Pushdown', 3, 8, 'Triceps'),
        ]),
        // Pull Day
        const ProgramDay('Pull Day', [
          ProgramExercise('Pull Up (Neutral Grip)', 5, 5, 'Lats'),
          ProgramExercise('Barbell Bent Over Row', 3, 5, 'Upper Back'),
          ProgramExercise('Lever Reverse T-Bar Row', 3, 8, 'Lats'),
          ProgramExercise('Dumbbell Shrug', 3, 8, 'Traps'),
          ProgramExercise('Barbell Preacher Curl', 3, 8, 'Biceps'),
          ProgramExercise('Dumbbell Hammer Curl', 3, 8, 'Biceps'),
        ]),
        // Leg Day
        const ProgramDay('Leg Day', [
          ProgramExercise('Barbell Full Squat', 5, 5, 'Quads'),
          ProgramExercise('Barbell Deadlift', 3, 5, 'Lower Back'),
          ProgramExercise('Sled 45° Leg Press (Side POV)', 3, 8, 'Quads'),
          ProgramExercise('Lever Lying Leg Curl', 3, 8, 'Hamstrings'),
          ProgramExercise('Lever Leg Extension', 3, 8, 'Quads'),
          ProgramExercise('Lever Seated Calf Raise', 3, 8, 'Calves'),
        ]),
      ],
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────

class ProgramDay {
  const ProgramDay(this.label, this.exercises);
  final String label;
  final List<ProgramExercise> exercises;
}

class ProgramExercise {
  const ProgramExercise(this.name, this.sets, this.reps, [this.muscleGroup]);
  final String name;
  final int sets;
  final int reps;
  final String? muscleGroup;
}
