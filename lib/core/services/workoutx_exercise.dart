import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'exercise_mapping.dart';

/// Data-transfer object for a single exercise as returned by the WorkoutX API.
///
/// The API uses singular string fields (`bodyPart`, `target`, `equipment`)
/// whereas the local [Exercises] table stores JSON-encoded arrays
/// (`bodyParts`, `targetMuscles`, `equipments`) to stay compatible with the
/// previous ExerciseDB-shaped data. [toCompanion] bridges the two and derives
/// `muscleGroup` / `difficulty` via [ExerciseMapping].
class WorkoutXExercise {
  final String id;
  final String name;
  final String? bodyPart;
  final String? equipment;
  final String? target;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? gifUrl;
  final String? difficulty;

  const WorkoutXExercise({
    required this.id,
    required this.name,
    this.bodyPart,
    this.equipment,
    this.target,
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.gifUrl,
    this.difficulty,
  });

  factory WorkoutXExercise.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : const [];

    return WorkoutXExercise(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      bodyPart: json['bodyPart'] as String?,
      equipment: json['equipment'] as String?,
      target: json['target'] as String?,
      secondaryMuscles: strList(json['secondaryMuscles']),
      instructions: strList(json['instructions']),
      gifUrl: json['gifUrl'] as String?,
      difficulty: json['difficulty'] as String?,
    );
  }

  /// Equipment as a single-element list (or empty), for heuristics + storage.
  List<String> get equipments =>
      (equipment != null && equipment!.isNotEmpty) ? [equipment!] : const [];

  /// Maps to an [ExercisesCompanion] ready for upsert into the local cache.
  ExercisesCompanion toCompanion() {
    final bodyParts =
        (bodyPart != null && bodyPart!.isNotEmpty) ? [bodyPart!] : <String>[];
    final targets =
        (target != null && target!.isNotEmpty) ? [target!] : <String>[];

    final muscleGroup = ExerciseMapping.resolveGymMuscleGroup(
      target: target,
      bodyPart: bodyPart,
    );

    final resolvedDifficulty = ExerciseMapping.normaliseDifficulty(
      difficulty,
      equipments: equipments,
      secondaryMuscles: secondaryMuscles,
      name: name,
    );

    return ExercisesCompanion(
      exerciseId: Value(id),
      name: Value(name),
      bodyParts: Value(jsonEncode(bodyParts)),
      targetMuscles: Value(jsonEncode(targets)),
      secondaryMuscles: Value(jsonEncode(secondaryMuscles)),
      equipments: Value(jsonEncode(equipments)),
      gifUrl: Value(gifUrl),
      instructions: Value(jsonEncode(instructions)),
      muscleGroup: Value(muscleGroup),
      difficulty: Value(resolvedDifficulty),
      isCustom: const Value(false),
      updatedAt: Value(DateTime.now()),
    );
  }
}
