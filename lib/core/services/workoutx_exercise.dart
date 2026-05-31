import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/exercise_mapping.dart';

/// Data-transfer object for a single exercise as returned by the WorkoutX API.
///
/// The API uses singular string fields (`bodyPart`, `target`, `equipment`)
/// whereas the local [Exercises] table stores JSON-encoded arrays
/// (`bodyParts`, `targetMuscles`, `equipments`) to stay compatible with the
/// previous ExerciseDB-shaped data. [toCompanion] bridges the two and derives
/// `muscleGroup` / `difficulty` via [ExerciseMapping].
class WorkoutXExercise {
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

  final String id;
  final String name;
  final String? bodyPart;
  final String? equipment;
  final String? target;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? gifUrl;
  final String? difficulty;

  /// Equipment as a single-element list (or empty), for heuristics + storage.
  List<String> get equipments =>
      (equipment != null && equipment!.isNotEmpty) ? [equipment!] : const [];

  /// WorkoutX-hosted media (the `/v1/gifs/…` endpoint) is auth-protected and
  /// returns 401 without the key. `CachedNetworkImage` sends no header, so we
  /// make the URL self-authenticating with an `api-key` query param. Non
  /// WorkoutX URLs (or an empty key) are returned unchanged.
  static String? authedGifUrl(String? url, String apiKey) {
    if (url == null || url.isEmpty || apiKey.isEmpty) return url;
    if (!url.contains('api.workoutxapp.com')) return url;
    if (url.contains('api-key=')) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}api-key=$apiKey';
  }

  /// Maps to an [ExercisesCompanion] ready for upsert into the local cache.
  /// [apiKey] is appended to WorkoutX `gifUrl`s so images load without a header.
  ExercisesCompanion toCompanion({String apiKey = ''}) {
    final bodyParts =
        (bodyPart != null && bodyPart!.isNotEmpty) ? [bodyPart!] : <String>[];
    final targets =
        (target != null && target!.isNotEmpty) ? [target!] : <String>[];

    final muscleGroup = ExerciseMapping.resolveGymMuscleGroup(
      target: target,
      bodyPart: bodyPart,
      exerciseName: name,
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
      gifUrl: Value(authedGifUrl(gifUrl, apiKey)),
      instructions: Value(jsonEncode(instructions)),
      muscleGroup: Value(muscleGroup),
      difficulty: Value(resolvedDifficulty),
      isCustom: const Value(false),
      updatedAt: Value(DateTime.now()),
    );
  }
}
