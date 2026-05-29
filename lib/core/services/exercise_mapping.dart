import 'dart:convert';

/// Pure, dependency-free heuristics for classifying exercises into the app's
/// canonical muscle groups and difficulty tiers.
///
/// These were previously private helpers inside `ExerciseLocalService` (which
/// seeded a bundled JSON dataset). Exercises now come from the WorkoutX API,
/// but the mapping rules are unchanged and reused by:
///   • [WorkoutXExercise] → `ExercisesCompanion` mapping,
///   • the bundled starter set used to seed the default program offline,
///   • any future re-classification of cached rows.
///
/// All methods are static and side-effect free so they can be unit-tested and
/// called from isolates without a database or network.
class ExerciseMapping {
  const ExerciseMapping._();

  // ── Muscle group resolution ────────────────────────────────────────────

  /// Maps an exercise's primary target muscle to a gym-standard muscle group.
  ///
  /// Prefers the specific `target` ("biceps", "quads", "lats") over the broad
  /// `bodyPart` ("upper arms", "upper legs", "back"). Falls back to a
  /// title-cased `bodyPart`, then `'Other'`.
  ///
  /// Canonical groups: Chest, Lats, Upper Back, Lower Back, Traps, Shoulders,
  /// Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Calves, Core,
  /// Neck, Cardio.
  static String resolveGymMuscleGroup({
    required String? target,
    required String? bodyPart,
  }) {
    if (target != null) {
      final t = target.toLowerCase().trim();
      final mapped = _targetToMuscleGroup[t];
      if (mapped != null) return mapped;
    }

    if (bodyPart != null && bodyPart.isNotEmpty) {
      return _titleCase(bodyPart);
    }

    return 'Other';
  }

  /// targetMuscles value (lowercased) → canonical muscle group name.
  static const _targetToMuscleGroup = <String, String>{
    // Chest
    'pectorals': 'Chest',
    'serratus anterior': 'Chest',

    // Back
    'lats': 'Lats',
    'upper back': 'Upper Back',
    'spine': 'Lower Back',
    'traps': 'Traps',

    // Shoulders
    'delts': 'Shoulders',

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
    } catch (_) {
      return [];
    }
  }
}
