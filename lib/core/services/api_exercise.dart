import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/exercise_mapping.dart';

/// Data-transfer object for a single exercise as returned by the ExerciseDB
/// open-source v1 API (oss.exercisedb.dev).
///
/// The API's array fields (`bodyParts`, `targetMuscles`, `equipments`) match
/// the local [Exercises] table columns one-to-one, so [toCompanion] mostly
/// JSON-encodes them and derives `muscleGroup` / `difficulty` via
/// [ExerciseMapping]. GIFs are hosted on a public CDN — no auth needed.
class ApiExercise {
  const ApiExercise({
    required this.id,
    required this.name,
    this.bodyParts = const [],
    this.equipments = const [],
    this.targetMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.gifUrl,
  });

  factory ApiExercise.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : const [];

    return ApiExercise(
      id: (json['exerciseId'] ?? json['id']).toString(),
      name: (json['name'] ?? '').toString(),
      bodyParts: strList(json['bodyParts']),
      equipments: strList(json['equipments']),
      targetMuscles: strList(json['targetMuscles']),
      secondaryMuscles: strList(json['secondaryMuscles']),
      instructions: strList(json['instructions']),
      gifUrl: json['gifUrl'] as String?,
    );
  }

  final String id;
  final String name;
  final List<String> bodyParts;
  final List<String> equipments;
  final List<String> targetMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? gifUrl;

  /// Maps to an [ExercisesCompanion] ready for upsert into the local cache.
  ExercisesCompanion toCompanion() {
    final muscleGroup = ExerciseMapping.resolveGymMuscleGroup(
      target: targetMuscles.isNotEmpty ? targetMuscles.first : null,
      bodyPart: bodyParts.isNotEmpty ? bodyParts.first : null,
      exerciseName: name,
    );

    final difficulty = ExerciseMapping.resolveDifficulty(
      equipments: equipments,
      secondaryMuscles: secondaryMuscles,
      name: name,
    );

    return ExercisesCompanion(
      exerciseId: Value(id),
      name: Value(name),
      bodyParts: Value(jsonEncode(bodyParts)),
      targetMuscles: Value(jsonEncode(targetMuscles)),
      secondaryMuscles: Value(jsonEncode(secondaryMuscles)),
      equipments: Value(jsonEncode(equipments)),
      gifUrl: Value(gifUrl),
      instructions: Value(jsonEncode(instructions)),
      muscleGroup: Value(muscleGroup),
      difficulty: Value(difficulty),
      isCustom: const Value(false),
      updatedAt: Value(DateTime.now()),
    );
  }
}
