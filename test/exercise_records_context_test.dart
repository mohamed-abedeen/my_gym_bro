import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';

/// Personal-record context (the set and date behind each PR) and the
/// "vs last month" 1RM baseline shown on the exercise detail screen.
void main() {
  late AppDatabase db;
  late SessionDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = SessionDao(db);
  });

  tearDown(() => db.close());

  Future<void> seedExercise(String id) => db.into(db.exercises).insert(
        ExercisesCompanion.insert(exerciseId: id, name: id),
      );

  /// One finished session containing [exerciseId] with (weight, reps) sets.
  Future<void> seedWorkout({
    required String exerciseId,
    required DateTime startedAt,
    List<(double, int)> sets = const [(100, 5)],
    double? totalVolume,
  }) async {
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            startedAt: startedAt,
            finishedAt: Value(startedAt.add(const Duration(hours: 1))),
            totalVolume: Value(totalVolume),
          ),
        );
    final seId = await db.into(db.sessionExercises).insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            orderIndex: 0,
            createdAt: Value(startedAt),
          ),
        );
    for (var i = 0; i < sets.length; i++) {
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionExerciseId: seId,
              setIndex: i,
              weight: Value(sets[i].$1),
              reps: Value(sets[i].$2),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  group('getPersonalRecords context', () {
    test('returns the set and session date behind each record', () async {
      await seedExercise('bench');
      final aug = DateTime(2026, 8, 28, 10);
      final sep = DateTime(2026, 9, 6, 10);
      await seedWorkout(
        exerciseId: 'bench',
        startedAt: aug,
        sets: const [(100, 8), (90, 10)],
        totalVolume: 4200,
      );
      await seedWorkout(
        exerciseId: 'bench',
        startedAt: sep,
        sets: const [(100, 5), (95, 8)],
        totalVolume: 4180,
      );

      final r = await dao.getPersonalRecords('bench');

      // Heaviest: most reps at the record weight, dated when first achieved.
      expect(r.maxWeight, 100);
      expect(r.maxWeightSet?.weight, 100);
      expect(r.maxWeightSet?.reps, 8);
      expect(r.maxWeightSet?.date, aug);

      // Best set volume: 90 x 10 = 900.
      expect(r.bestSetVolume, 900);
      expect(r.bestSetVolumeSet?.weight, 90);
      expect(r.bestSetVolumeSet?.reps, 10);
      expect(r.bestSetVolumeSet?.date, aug);

      // Epley: 100 x (1 + 8/30) = 133.3 beats 95 x (1 + 8/30) = 120.3.
      expect(r.best1rm, closeTo(133.33, 0.01));
      expect(r.best1rmSet?.weight, 100);
      expect(r.best1rmSet?.reps, 8);
      expect(r.best1rmSet?.date, aug);

      expect(r.bestSessionVolume, 4200);
      expect(r.bestSessionDate, aug);
    });

    test('leaves the context empty when nothing is logged', () async {
      await seedExercise('bench');
      final r = await dao.getPersonalRecords('bench');
      expect(r.maxWeight, isNull);
      expect(r.maxWeightSet, isNull);
      expect(r.best1rmSet, isNull);
      expect(r.bestSetVolumeSet, isNull);
      expect(r.bestSessionDate, isNull);
    });
  });

  group('getBestOneRepMaxBefore', () {
    test('only counts sessions that started strictly before the cutoff',
        () async {
      await seedExercise('bench');
      await seedWorkout(
        exerciseId: 'bench',
        startedAt: DateTime(2026, 7, 10),
        sets: const [(100, 5)],
      );
      await seedWorkout(
        exerciseId: 'bench',
        startedAt: DateTime(2026, 8, 20),
        sets: const [(110, 5)],
      );

      expect(
        await dao.getBestOneRepMaxBefore('bench', DateTime(2026, 8, 8)),
        closeTo(100 * (1 + 5 / 30), 0.01),
      );
      expect(
        await dao.getBestOneRepMaxBefore('bench', DateTime(2026, 9)),
        closeTo(110 * (1 + 5 / 30), 0.01),
      );
      // A session starting exactly at the cutoff is not "before" it.
      expect(
        await dao.getBestOneRepMaxBefore('bench', DateTime(2026, 7, 10)),
        isNull,
      );
    });
  });
}
