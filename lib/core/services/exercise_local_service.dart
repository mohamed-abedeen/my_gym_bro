import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';

/// Reads assets/exercises.json from bundle. No network. No API key. Fully offline.
class ExerciseLocalService {
  const ExerciseLocalService._();

  /// Seeds the database with exercises from the bundled JSON asset.
  /// Only call this once, when the exercise count is zero.
  static Future<void> seedFromAssets(AppDatabase db) async {
    final jsonString = await rootBundle.loadString('assets/exercises.json');

    // jsonDecode + all synchronous processing runs in a background isolate so
    // it never blocks the main thread. compute() returns plain Maps which can
    // cross the isolate boundary; we build the Drift companions here.
    final rows = await compute(_parseExerciseJson, jsonString);

    final dao = ExerciseDao(db);
    final companions = rows
        .map(
          (m) => ExercisesCompanion(
            exerciseId: Value(m['exerciseId']! as String),
            name: Value(m['name']! as String),
            bodyParts: Value(m['bodyParts'] as String?),
            targetMuscles: Value(m['targetMuscles'] as String?),
            secondaryMuscles: Value(m['secondaryMuscles'] as String?),
            equipments: Value(m['equipments'] as String?),
            gifUrl: Value(m['gifUrl'] as String?),
            instructions: Value(m['instructions'] as String?),
            muscleGroup: Value(m['muscleGroup'] as String?),
            difficulty: Value(m['difficulty'] as String?),
            isCustom: const Value(false),
          ),
        )
        .toList();

    // Batch insert in chunks of 100
    for (var i = 0; i < companions.length; i += 100) {
      await dao
          .bulkInsert(companions.sublist(i, min(i + 100, companions.length)));
    }
  }

  /// Re-calculates and updates `muscleGroup` for every exercise in the DB.
  /// Call this after schema/mapping changes to fix existing installs.
  static Future<void> remapMuscleGroups(AppDatabase db) async {
    final dao = ExerciseDao(db);
    final allExercises = await dao.getAll();

    for (final exercise in allExercises) {
      // Parse the JSON-encoded arrays back to lists
      final targets = _decodeJsonList(exercise.targetMuscles);
      final bodyParts = _decodeJsonList(exercise.bodyParts);

      final newGroup = _resolveGymMuscleGroup(
        target: targets.isNotEmpty ? targets[0] : null,
        bodyPart: bodyParts.isNotEmpty ? bodyParts[0] : null,
        exerciseName: exercise.name,
      );

      // Only update if different
      if (newGroup != exercise.muscleGroup) {
        await dao.updateMuscleGroup(exercise.exerciseId, newGroup);
      }
    }
  }

  static List<String> _decodeJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } on Object {
      return [];
    }
  }

  /// Maps an exercise's primary target muscle to a gym-standard muscle group.
  ///
  /// Uses `targetMuscles[0]` (specific: "biceps", "quads", "lats") rather than
  /// `bodyParts[0]` (broad: "upper arms", "upper legs", "back").
  ///
  /// Canonical groups: Chest, Lats, Upper Back, Lower Back, Traps,
  /// Front Delt, Side Delt, Rear Delt, Shoulders (catch-all),
  /// Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Calves, Core,
  /// Neck, Cardio.
  static String _resolveGymMuscleGroup({
    required String? target,
    required String? bodyPart,
    String exerciseName = '',
  }) {
    if (target != null) {
      final t = target.toLowerCase().trim();
      // Shoulder target gets refined by exercise name into one of the three
      // deltoid heads (or the generic 'Shoulders' bucket when unclassifiable).
      if (t == 'delts') return _resolveShoulderSubGroup(exerciseName);
      final mapped = _targetToMuscleGroup[t];
      if (mapped != null) return mapped;
    }

    // Fallback: title-case the bodyPart
    if (bodyPart != null && bodyPart.isNotEmpty) {
      return _titleCase(bodyPart);
    }

    return 'Other';
  }

  /// Classifies a shoulder exercise into Front Delt, Side Delt, Rear Delt,
  /// or the generic 'Shoulders' bucket for exercises that don't match any
  /// recognised pattern (Olympic lifts, battling ropes, etc.).
  ///
  /// Priority order:
  ///   1. Rear Delt  — "rear delt", "reverse fly", "rear lateral", rotations
  ///   2. Side Delt  — "lateral raise", "upright row", "t-raise", "side press"
  ///   3. Front Delt — "front raise", press movements, "thruster", "bradford"
  ///   4. Shoulders  — unclassifiable catch-all (still visible under "All Shoulders")
  static String _resolveShoulderSubGroup(String exerciseName) {
    final n = exerciseName.toLowerCase();

    // ── Rear Delt ────────────────────────────────────────────────────────────
    if (n.contains('rear delt') ||
        n.contains('reverse fly') ||
        n.contains('revers fly') || // common typo in the dataset
        n.contains('rear lateral') ||
        n.contains('rear fly') ||
        n.contains('deltoid rear') || // e.g. "dumbbell lying one arm deltoid rear"
        n.contains('external rotation') || // rotator-cuff / posterior chain
        n.contains('external shoulder') || // "external shoulder rotation" word order variant
        n.contains('internal rotation')) {
      return 'Rear Delt';
    }

    // ── Side / Lateral Delt ──────────────────────────────────────────────────
    if (n.contains('lateral raise') ||
        n.contains('upright row') ||
        n.contains('y-raise') ||
        n.contains('iron cross') ||
        n.contains('side lying') ||
        n.contains('t-raise') || // T-raise = lateral plane movement
        n.contains('side press')) { // e.g. "dumbbell alternate side press"
      return 'Side Delt';
    }

    // ── Front / Anterior Delt ────────────────────────────────────────────────
    if (n.contains('front raise') ||
        n.contains('forward raise') ||
        n.contains('front shoulder raise') || // e.g. "cable front shoulder raise"
        n.contains('overhead press') ||
        n.contains('military press') ||
        n.contains('behind neck') || // behind-the-neck press variants
        n.contains('shoulder press') ||
        n.contains('arnold press') ||
        n.contains('push press') ||
        n.contains('thruster') ||
        n.contains('bradford') ||
        n.contains('cuban press') ||
        n.contains('scott press') ||
        n.contains('alternate press') || // e.g. "dumbbell seated alternate press"
        n.contains('alternating press') || // e.g. "kettlebell alternating press"
        n.contains('alternate shoulder') || // e.g. "dumbbell seated alternate shoulder"
        n.contains('seesaw press') || // e.g. "kettlebell seesaw press"
        n.contains('w-press') || // e.g. "dumbbell w-press"
        n.contains('anti gravity press') || // e.g. "ez barbell anti gravity press"
        n.contains('palm in press') || // e.g. "dumbbell standing one arm palm in press"
        n.contains('palms in press') || // e.g. "dumbbell standing palms in press"
        n.contains('incline raise') || // e.g. "dumbbell incline raise"
        n.contains('bench seated press')) { // e.g. "dumbbell bench seated press"
      return 'Front Delt';
    }

    // ── Unclassified → generic Shoulders bucket ──────────────────────────────
    // Includes: Olympic lifts (snatches, jerks, cleans), battling ropes,
    // boxing, carries, and other multi-plane compound movements.
    // These remain visible under "All Shoulders" in the filter.
    return 'Shoulders';
  }

  /// targetMuscles value (lowercase from JSON) → canonical muscle group name.
  /// NOTE: 'delts' is intentionally absent — it is handled by
  /// [_resolveShoulderSubGroup] inside [_resolveGymMuscleGroup].
  static const _targetToMuscleGroup = <String, String>{
    // Chest
    'pectorals': 'Chest',
    'serratus anterior': 'Chest',

    // Back
    'lats': 'Lats',
    'upper back': 'Upper Back',
    'spine': 'Lower Back',
    'traps': 'Traps',

    // Arms
    'biceps': 'Biceps',
    'triceps': 'Triceps',
    'forearms': 'Forearms',

    // Legs
    'quads': 'Quads',
    'hamstrings': 'Hamstrings',
    'glutes': 'Glutes',
    'abductors': 'Glutes', // hip abductors → group with glutes
    'adductors': 'Quads', // inner thigh → group with quads

    // Lower legs
    'calves': 'Calves',

    // Core
    'abs': 'Core',

    // Cardio
    'cardiovascular system': 'Cardio',

    // Neck
    'levator scapulae': 'Neck',
  };

  static String _titleCase(String s) =>
      s.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  // ── Difficulty derivation ─────────────────────────────────────────

  /// Equipment that suggests advanced lifting.
  static const _advancedEquipment = {
    'olympic barbell', 'trap bar', 'smith machine', 'skierg machine',
    'hammer', 'tire',
  };

  /// Equipment typically used by beginners / bodyweight.
  static const _beginnerEquipment = {
    'body weight', 'stability ball', 'roller', 'wheel roller',
    'assisted', 'bosu ball',
  };

  /// Exercise name keywords that indicate advanced compound lifts.
  static const _advancedKeywords = [
    'clean', 'snatch', 'jerk', 'deadlift', 'muscle up', 'pistol',
    'planche', 'handstand', 'dragon flag', 'front lever', 'back lever',
    'turkish get', 'power clean',
  ];

  /// Derives difficulty from exercise characteristics.
  ///
  /// Heuristic:
  /// - **Beginner**: body weight / simple equipment, few secondary muscles
  /// - **Advanced**: olympic/complex equipment, compound keywords, many
  ///   secondary muscles
  /// - **Intermediate**: everything else
  static String _resolveDifficulty({
    required List<String> equipments,
    required List<String> secondaryMuscles,
    required String name,
  }) {
    final nameLower = name.toLowerCase();

    // Check name keywords first (strongest signal)
    for (final kw in _advancedKeywords) {
      if (nameLower.contains(kw)) return 'advanced';
    }

    final hasAdvancedEquip =
        equipments.any((e) => _advancedEquipment.contains(e.toLowerCase()));
    final hasBeginnerEquip =
        equipments.any((e) => _beginnerEquipment.contains(e.toLowerCase()));
    final secondaryCount = secondaryMuscles.length;

    if (hasAdvancedEquip && secondaryCount >= 3) return 'advanced';
    if (hasAdvancedEquip) return 'intermediate';
    if (hasBeginnerEquip && secondaryCount <= 1) return 'beginner';
    if (secondaryCount >= 3) return 'intermediate';
    if (hasBeginnerEquip) return 'beginner';

    return 'intermediate';
  }

  /// Backfills the `difficulty` column for all exercises that don't have one.
  /// Safe to call on every app launch — only updates rows where difficulty is null.
  static Future<void> backfillDifficulty(AppDatabase db) async {
    final dao = ExerciseDao(db);
    final allExercises = await dao.getAll();

    for (final exercise in allExercises) {
      if (exercise.difficulty != null) continue;

      final equipments = _decodeJsonList(exercise.equipments);
      final secondaryMuscles = _decodeJsonList(exercise.secondaryMuscles);

      final difficulty = _resolveDifficulty(
        equipments: equipments,
        secondaryMuscles: secondaryMuscles,
        name: exercise.name,
      );

      await dao.updateDifficulty(exercise.exerciseId, difficulty);
    }
  }
}

// ── Isolate entry point ───────────────────────────────────────────────────
// Must be a top-level function so compute() can send it across the isolate
// boundary. Returns plain Map objects (sendable); Drift companions are built
// back on the main isolate where the DB connection lives.

List<Map<String, Object?>> _parseExerciseJson(String jsonString) {
  final list = jsonDecode(jsonString) as List<dynamic>;
  return list.map((dynamic raw) {
    final e = raw as Map<String, dynamic>;

    final rawInstructions =
        (e['instructions'] as List?)?.cast<String>() ?? [];
    final cleaned = rawInstructions
        .map((s) => s.replaceFirst(RegExp(r'^Step:\d+\s*'), '').trim())
        .toList();

    final bodyParts = (e['bodyParts'] as List?)?.cast<String>() ?? [];
    final targets = (e['targetMuscles'] as List?)?.cast<String>() ?? [];
    final equipments = (e['equipments'] as List?)?.cast<String>() ?? [];
    final secondaryMuscles =
        (e['secondaryMuscles'] as List?)?.cast<String>() ?? [];

    final muscleGroup = ExerciseLocalService._resolveGymMuscleGroup(
      target: targets.isNotEmpty ? targets[0] : null,
      bodyPart: bodyParts.isNotEmpty ? bodyParts[0] : null,
      exerciseName: e['name'] as String,
    );

    final difficulty = ExerciseLocalService._resolveDifficulty(
      equipments: equipments,
      secondaryMuscles: secondaryMuscles,
      name: e['name'] as String,
    );

    return <String, Object?>{
      'exerciseId': e['exerciseId'] as String,
      'name': e['name'] as String,
      'bodyParts': jsonEncode(bodyParts),
      'targetMuscles':
          jsonEncode((e['targetMuscles'] as List?)?.cast<String>() ?? []),
      'secondaryMuscles': jsonEncode(secondaryMuscles),
      'equipments': jsonEncode(equipments),
      'gifUrl': e['gifUrl'] as String?,
      'instructions': jsonEncode(cleaned),
      'muscleGroup': muscleGroup,
      'difficulty': difficulty,
    };
  }).toList();
}
