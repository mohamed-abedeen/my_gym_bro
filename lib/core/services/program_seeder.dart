import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';

/// Seeds the database with 3 ready-to-use training programs:
/// Arnold Split, Bro Split, Push/Pull/Legs.
///
/// Call once at startup (guarded by a check so it doesn't re-seed).
class ProgramSeeder {

  ProgramSeeder(AppDatabase db)
      : _scheduleDao = ScheduleDao(db),
        _exerciseDao = ExerciseDao(db);
  final ScheduleDao _scheduleDao;
  final ExerciseDao _exerciseDao;

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

  /// Returns exerciseId for a given name. Searches the DB first,
  /// creates a custom exercise if not found.
  Future<String> _resolve(String name, {String? muscleGroup}) async {
    final key = name.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;

    // Try exact match first
    final results = await _exerciseDao.searchByName(name);
    for (final e in results) {
      if (e.name.toLowerCase() == key) {
        _cache[key] = e.exerciseId;
        return e.exerciseId;
      }
    }

    // Try partial match — pick the shortest name that contains our term
    if (results.isNotEmpty) {
      results.sort((a, b) => a.name.length.compareTo(b.name.length));
      _cache[key] = results.first.exerciseId;
      return results.first.exerciseId;
    }

    // Create custom exercise
    final customId = 'custom_${key.replaceAll(RegExp('[^a-z0-9]'), '_')}';
    await _exerciseDao.upsert(ExercisesCompanion(
      exerciseId: Value(customId),
      name: Value(name),
      muscleGroup: Value(muscleGroup),
      isCustom: const Value(true),
    ));
    _cache[key] = customId;
    return customId;
  }

  // ─── Known exercise IDs (from exercises.json seed) ────────────────

  // Pre-mapped IDs to avoid DB lookups for known exercises.
  static const _known = <String, String>{
    // Chest
    'Barbell Bench Press': 'EIeI8Vf',
    'Dumbbell Fly': 'yz9nUhF',
    'Barbell Incline Bench Press': '3TZduzM',
    'Cable Cross-Over': '0CXGHya',
    'Chest Dip': '9WTm7dq',
    'Dumbbell Pullover': '9XjtHvS',
    'Dumbbell Incline Bench Press': 'ns0SIbU',
    'Dumbbell Bench Press': 'SpYC0Kp',
    'Barbell Decline Bench Press': 'GrO65fd',
    'Push-Up': 'I4hDWkc',

    // Back
    'Wide Grip Pull-Up': 'Qqi7bko',
    'Pull-Up': 'lBDjFxJ',
    'Lever Reverse T-Bar Row': 'BgljGjd',
    'Cable Seated Row': 'fUBheHs',
    'Barbell Straight Leg Deadlift': 'hrVQWvE',
    'Barbell Bent Over Row': 'eZyBC3j',
    'Barbell Deadlift': 'ila4NZS',
    'Cable Straight Arm Pulldown': 'x69MAlq',
    'Cable Lat Pulldown Full Range of Motion': 'LEprlgG',

    // Legs
    'Barbell Full Squat': 'qXTaZnJ',
    'Sled 45° Leg Press': '2Qh2J1e',
    'Lever Leg Extension': 'my33uHU',
    'Lever Lying Leg Curl': '17lJ1kr',
    'Barbell Lunge': 't8iSghb',
    'Sled Hack Squat': 'Qa55kX1',
    'Lever Seated Calf Raise': 'bOOdeyc',
    'Lever Standing Calf Raise': 'ykUOVze',
    'Lever Seated Leg Curl': 'Zg3XY7P',

    // Shoulders
    'Barbell Seated Overhead Press': 'kTbSH9h',
    'Dumbbell Lateral Raise': 'DsgkuIt',
    'Dumbbell Rear Delt Raise': 'mu5Guxt',
    'Cable Lateral Raise': 'goJ6ezq',
    'Dumbbell Arnold Press': 'Xy4jlWA',
    'Barbell Upright Row': 'UDlhcO8',
    'Dumbbell Seated Shoulder Press': 'znQUdHY',
    'Dumbbell Shrug': 'NJzBsGJ',
    'Barbell Shrug': 'dG7tG5y',
    'Barbell Clean and Press': 'SGY8Zui',

    // Arms
    'Barbell Curl': '25GPyDY',
    'Dumbbell Seated Curl': 'TiaZTxx',
    'Dumbbell Concentration Curl': 'gvsWLQw',
    'Barbell Close-Grip Bench Press': 'J6Dx1Mu',
    'Cable Triceps Pushdown': 'gAwDzB3',
    'Barbell Wrist Curl': '82LxxkW',
    'Barbell Reverse Curl': 'xNrS20v',
    'Wrist Rollerer': 'bd5b860',
    'Barbell Preacher Curl': 'qOgPVf6',
    'Dumbbell Incline Curl': 'ae9UoXQ',
    'Barbell Lying Triceps Extension': 'iZop9xO',
    'Weighted Tricep Dips': 'bZq4bwK',
    'Dumbbell Hammer Curl': 'slDvUAU',
    'Dumbbell Lying Triceps Extension': 'mpKZGWz',
    'Cable Overhead Triceps Extension': '2IxROQ1',

    // Other
    'Barbell Good Morning': 'XlZ4lAC',
    'Reverse Crunch': 'nCU1Ekp',
    'Barbell Standing Overhead Triceps Extension': 'dZl9Q27',
    'Dumbbell Decline Hammer Press': '1qrWgZ2',
  };

  /// Resolve using known map first, then DB search, then create custom.
  Future<String> _id(String name, {String? muscleGroup}) async {
    if (_known.containsKey(name)) {
      _cache[name.toLowerCase()] = _known[name]!;
      return _known[name]!;
    }
    return _resolve(name, muscleGroup: muscleGroup);
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
    const chestBackLegs = _DayDef('Chest, Back & Legs', [
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

    const shouldersArms = _DayDef('Shoulders & Arms', [
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
          _Ex('Pec Dec', 3, 10, 'Chest'),
          _Ex('Push-Up', 3, 10, 'Chest'),
        ]),
        // Tuesday: Legs
        const _DayDef('Leg Day', [
          _Ex('Barbell Full Squat', 3, 10, 'Quads'),
          _Ex('Sled Hack Squat', 3, 10, 'Quads'),
          _Ex('Sled 45° Leg Press', 3, 10, 'Quads'),
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
          _Ex('Reverse Fly Machine', 3, 10, 'Shoulders'),
          _Ex('Dumbbell Shrug', 3, 10, 'Traps'),
        ]),
        // Thursday: Back
        const _DayDef('Back Day', [
          _Ex('Barbell Deadlift', 3, 10, 'Lower Back'),
          _Ex('Cable Lat Pulldown Full Range of Motion', 3, 10, 'Lats'),
          _Ex('Hammer Strength Row', 3, 10, 'Upper Back'),
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
          _Ex('Pull-Up', 5, 5, 'Lats'),
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
          _Ex('Sled 45° Leg Press', 3, 8, 'Quads'),
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

  const _DayDef(this.label, this.exercises) : isRest = false;
  const _DayDef.rest(this.label)
      : exercises = const [],
        isRest = true;
  final String label;
  final List<_Ex> exercises;
  final bool isRest;
}

class _Ex {

  const _Ex(this.name, this.sets, this.reps, [this.muscleGroup]);
  final String name;
  final int sets;
  final int reps;
  final String? muscleGroup;
}
