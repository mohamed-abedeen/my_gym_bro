import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../database/daos/exercise_dao.dart';

/// Reads assets/exercises.json from bundle. No network. No API key. Fully offline.
class ExerciseLocalService {
  const ExerciseLocalService._();

  /// Seeds the database with exercises from the bundled JSON asset.
  /// Only call this once, when the exercise count is zero.
  static Future<void> seedFromAssets(AppDatabase db) async {
    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final list = jsonDecode(jsonString) as List;

    final dao = ExerciseDao(db);
    final companions = list.map((e) {
      final rawInstructions =
          (e['instructions'] as List?)?.cast<String>() ?? [];
      final cleaned = rawInstructions
          .map((s) => s.replaceFirst(RegExp(r'^Step:\d+\s*'), '').trim())
          .toList();

      final bodyParts = (e['bodyParts'] as List?)?.cast<String>() ?? [];
      final targets = (e['targetMuscles'] as List?)?.cast<String>() ?? [];

      // Map targetMuscles[0] to a specific, gym-standard muscle group name.
      // Falls back to bodyParts[0] → title-cased if no target match.
      final muscleGroup = _resolveGymMuscleGroup(
        target: targets.isNotEmpty ? targets[0] : null,
        bodyPart: bodyParts.isNotEmpty ? bodyParts[0] : null,
      );

      final equipments =
          (e['equipments'] as List?)?.cast<String>() ?? [];
      final secondaryMuscles =
          (e['secondaryMuscles'] as List?)?.cast<String>() ?? [];

      // Derive difficulty from exercise characteristics
      final difficulty = _resolveDifficulty(
        equipments: equipments,
        secondaryMuscles: secondaryMuscles,
        name: e['name'] as String,
      );

      return ExercisesCompanion(
        exerciseId: Value(e['exerciseId'] as String),
        name: Value(e['name'] as String),
        bodyParts: Value(jsonEncode(bodyParts)),
        targetMuscles: Value(
            jsonEncode((e['targetMuscles'] as List?)?.cast<String>() ?? [])),
        secondaryMuscles: Value(jsonEncode(secondaryMuscles)),
        equipments: Value(jsonEncode(equipments)),
        gifUrl: Value(e['gifUrl'] as String?),
        instructions: Value(jsonEncode(cleaned)),
        muscleGroup: Value(muscleGroup),
        difficulty: Value(difficulty),
        isCustom: const Value(false),
      );
    }).toList();

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
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Maps an exercise's primary target muscle to a gym-standard muscle group.
  ///
  /// Uses `targetMuscles[0]` (specific: "biceps", "quads", "lats") rather than
  /// `bodyParts[0]` (broad: "upper arms", "upper legs", "back").
  ///
  /// Canonical groups: Chest, Lats, Upper Back, Lower Back, Traps, Shoulders,
  /// Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Calves, Core,
  /// Neck, Cardio.
  static String _resolveGymMuscleGroup({
    required String? target,
    required String? bodyPart,
  }) {
    if (target != null) {
      final t = target.toLowerCase().trim();
      final mapped = _targetToMuscleGroup[t];
      if (mapped != null) return mapped;
    }

    // Fallback: title-case the bodyPart
    if (bodyPart != null && bodyPart.isNotEmpty) {
      return _titleCase(bodyPart);
    }

    return 'Other';
  }

  /// targetMuscles value (lowercase from JSON) → canonical muscle group name.
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
