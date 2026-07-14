import 'dart:convert';

import 'package:my_gym_bro/core/services/api_exercise.dart' show ApiExercise;

/// Pure, dependency-free heuristics for classifying exercises into the app's
/// canonical muscle groups and difficulty tiers.
///
/// These were previously private helpers inside `ExerciseLocalService` (which
/// seeded a bundled JSON dataset). Exercises now come from the exercise API,
/// but the mapping rules are unchanged and reused by:
///   • the [ApiExercise] DTO → `ExercisesCompanion` mapping,
///   • the bundled starter set used to seed the default program offline.
///
/// All methods are static and side-effect free so they can be unit-tested and
/// called from isolates without a database or network.
class ExerciseMapping {
  const ExerciseMapping._();

  // ── Muscle group resolution ────────────────────────────────────────────

  /// Maps an exercise's primary target muscle to a gym-standard muscle group.
  ///
  /// Uses the specific `target` ("biceps", "quads", "lats") rather than the
  /// broad `bodyPart` ("upper arms", "upper legs", "back"). A `delts` target is
  /// refined into Front/Side/Rear Delt via [_resolveShoulderSubGroup] using the
  /// exercise name — `MuscleRecoveryService` depends on these sub-groups.
  ///
  /// Canonical groups: Chest, Lats, Upper Back, Lower Back, Traps,
  /// Front Delt, Side Delt, Rear Delt, Shoulders (catch-all),
  /// Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Calves, Core,
  /// Neck, Cardio.
  static String resolveGymMuscleGroup({
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
  static String _resolveShoulderSubGroup(String exerciseName) {
    final n = exerciseName.toLowerCase();

    // ── Rear Delt ────────────────────────────────────────────────────────────
    if (n.contains('rear delt') ||
        n.contains('reverse fly') ||
        n.contains('revers fly') || // common typo in the dataset
        n.contains('rear lateral') ||
        n.contains('rear fly') ||
        n.contains('deltoid rear') ||
        n.contains('external rotation') ||
        n.contains('external shoulder') ||
        n.contains('internal rotation')) {
      return 'Rear Delt';
    }

    // ── Side / Lateral Delt ──────────────────────────────────────────────────
    if (n.contains('lateral raise') ||
        n.contains('upright row') ||
        n.contains('y-raise') ||
        n.contains('iron cross') ||
        n.contains('side lying') ||
        n.contains('t-raise') ||
        n.contains('side press')) {
      return 'Side Delt';
    }

    // ── Front / Anterior Delt ────────────────────────────────────────────────
    if (n.contains('front raise') ||
        n.contains('forward raise') ||
        n.contains('front shoulder raise') ||
        n.contains('overhead press') ||
        n.contains('military press') ||
        n.contains('behind neck') ||
        n.contains('shoulder press') ||
        n.contains('arnold press') ||
        n.contains('push press') ||
        n.contains('thruster') ||
        n.contains('bradford') ||
        n.contains('cuban press') ||
        n.contains('scott press') ||
        n.contains('alternate press') ||
        n.contains('alternating press') ||
        n.contains('alternate shoulder') ||
        n.contains('seesaw press') ||
        n.contains('w-press') ||
        n.contains('anti gravity press') ||
        n.contains('palm in press') ||
        n.contains('palms in press') ||
        n.contains('incline raise') ||
        n.contains('bench seated press')) {
      return 'Front Delt';
    }

    // ── Unclassified → generic Shoulders bucket ──────────────────────────────
    return 'Shoulders';
  }

  /// targetMuscles value (lowercased) → canonical muscle group name.
  /// NOTE: 'delts' is intentionally absent — handled by
  /// [_resolveShoulderSubGroup] inside [resolveGymMuscleGroup].
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

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  // ── Difficulty derivation ──────────────────────────────────────────────

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
  static String resolveDifficulty({
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

  /// Normalises an API-provided difficulty to the app's three tiers, falling
  /// back to the [resolveDifficulty] heuristic when absent/unrecognised.
  static String normaliseDifficulty(
    String? raw, {
    required List<String> equipments,
    required List<String> secondaryMuscles,
    required String name,
  }) {
    final v = raw?.toLowerCase().trim();
    if (v == 'beginner' || v == 'intermediate' || v == 'advanced') return v!;
    return resolveDifficulty(
      equipments: equipments,
      secondaryMuscles: secondaryMuscles,
      name: name,
    );
  }

  // ── JSON helpers ───────────────────────────────────────────────────────

  /// Decodes a JSON-encoded string array column back to a `List<String>`.
  /// Returns an empty list on null/empty/malformed input.
  static List<String> decodeJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } on Object {
      return [];
    }
  }
}
