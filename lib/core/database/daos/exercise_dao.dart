import 'package:drift/drift.dart';

import '../app_database.dart';

part 'exercise_dao.g.dart';

/// Data access object for the [Exercises] table.
@DriftAccessor(tables: [Exercises])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  /// Count all exercises.
  Future<int> count() async {
    final countExp = exercises.localId.count();
    final query = selectOnly(exercises)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp)!;
  }

  /// Get all exercises ordered by name.
  Future<List<Exercise>> getAll() =>
      (select(exercises)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  /// Stream all exercises ordered by name.
  Stream<List<Exercise>> watchAll() =>
      (select(exercises)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// Find exercise by exerciseId string (e.g. "2gPfomN").
  Future<Exercise?> findByExerciseId(String exerciseId) =>
      (select(exercises)..where((t) => t.exerciseId.equals(exerciseId)))
          .getSingleOrNull();

  /// Search exercises by name.
  Future<List<Exercise>> searchByName(String query) => (select(exercises)
        ..where((t) => t.name.like('%$query%'))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  /// Filter exercises by muscle group.
  Future<List<Exercise>> filterByMuscleGroup(String group) =>
      (select(exercises)
            ..where((t) => t.muscleGroup.equals(group))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  /// Bulk insert exercises (for seeding from JSON).
  Future<void> bulkInsert(List<ExercisesCompanion> companions) async {
    await batch((b) {
      b.insertAll(exercises, companions, mode: InsertMode.insertOrIgnore);
    });
  }

  /// Find multiple exercises by their exerciseId strings in one query.
  Future<List<Exercise>> findByExerciseIds(List<String> exerciseIds) =>
      (select(exercises)..where((t) => t.exerciseId.isIn(exerciseIds))).get();

  /// Update the muscleGroup column for a single exercise.
  Future<void> updateMuscleGroup(String exerciseId, String muscleGroup) =>
      (update(exercises)..where((t) => t.exerciseId.equals(exerciseId)))
          .write(ExercisesCompanion(muscleGroup: Value(muscleGroup)));

  /// Insert or update a single exercise.
  Future<int> upsert(ExercisesCompanion companion) =>
      into(exercises).insertOnConflictUpdate(companion);

  /// Update the difficulty column for a single exercise.
  Future<void> updateDifficulty(String exerciseId, String difficulty) =>
      (update(exercises)..where((t) => t.exerciseId.equals(exerciseId)))
          .write(ExercisesCompanion(difficulty: Value(difficulty)));
}
