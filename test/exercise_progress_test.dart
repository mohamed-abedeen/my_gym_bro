import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/features/workout/exercise_progress.dart';

/// Progress-chart data layer (§6.3): per-session points from an exercise's
/// history, and the most-logged exercise picker query.
void main() {
  late AppDatabase db;
  late SessionDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = SessionDao(db);
  });

  tearDown(() => db.close());

  Future<void> seedExercise(String id, String name) =>
      db.into(db.exercises).insert(
            ExercisesCompanion.insert(exerciseId: id, name: name),
          );

  /// One session containing [exerciseId] with the given (weight, reps) sets.
  Future<void> seedWorkout({
    required String exerciseId,
    required DateTime startedAt,
    List<(double?, int?)> sets = const [(100, 5)],
    bool finished = true,
  }) async {
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            startedAt: startedAt,
            finishedAt: Value(
              finished ? startedAt.add(const Duration(hours: 1)) : null,
            ),
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

  group('buildProgressPoints', () {
    test('computes volume, top set and Epley e1RM per session, oldest first',
        () async {
      await seedExercise('ex1', 'Bench Press');
      final day1 = DateTime(2026, 8, 1, 10);
      final day2 = DateTime(2026, 8, 8, 10);
      await seedWorkout(
        exerciseId: 'ex1',
        startedAt: day1,
        sets: const [(100, 5), (110, 3)],
      );
      await seedWorkout(
        exerciseId: 'ex1',
        startedAt: day2,
        sets: const [(105, 5)],
      );

      final points =
          buildProgressPoints(await dao.getSessionsForExercise('ex1'));

      expect(points, hasLength(2));
      expect(points.first.date, day1);
      expect(points.last.date, day2);

      // day1: volume 100*5 + 110*3 = 830, top 110, e1rm = best of
      // 100*(1+5/30)=116.67 and 110*(1+3/30)=121.
      expect(points.first.volume, 830);
      expect(points.first.topSetWeight, 110);
      expect(points.first.e1rm, closeTo(121, 0.01));

      expect(points.last.volume, 525);
      expect(points.last.topSetWeight, 105);
      expect(points.last.e1rm, closeTo(105 * (1 + 5 / 30), 0.01));
    });

    test('ignores incomplete data rows and skips unusable sessions', () async {
      await seedExercise('ex1', 'Bench Press');
      await seedWorkout(
        exerciseId: 'ex1',
        startedAt: DateTime(2026, 8),
        sets: const [(100, 5), (null, 8), (80, null)],
      );
      // A session where nothing was actually logged: no chart point at all.
      await seedWorkout(
        exerciseId: 'ex1',
        startedAt: DateTime(2026, 8, 8),
        sets: const [(null, null)],
      );

      final points =
          buildProgressPoints(await dao.getSessionsForExercise('ex1'));

      expect(points, hasLength(1));
      expect(points.single.volume, 500);
      expect(points.single.topSetWeight, 100);
    });
  });

  group('getMostLoggedExercises', () {
    test('returns only exercises with enough finished sessions, most first',
        () async {
      await seedExercise('ex1', 'Bench Press');
      await seedExercise('ex2', 'Squat');
      await seedExercise('ex3', 'Deadlift');

      for (var i = 0; i < 3; i++) {
        await seedWorkout(
          exerciseId: 'ex1',
          startedAt: DateTime(2026, 8, 1 + i),
        );
      }
      for (var i = 0; i < 2; i++) {
        await seedWorkout(
          exerciseId: 'ex2',
          startedAt: DateTime(2026, 8, 1 + i),
        );
      }
      // One finished + one unfinished session → below the 2-session bar.
      await seedWorkout(exerciseId: 'ex3', startedAt: DateTime(2026, 8));
      await seedWorkout(
        exerciseId: 'ex3',
        startedAt: DateTime(2026, 8, 2),
        finished: false,
      );

      final list = await dao.getMostLoggedExercises();

      expect(list.map((e) => e.exerciseId), ['ex1', 'ex2']);
      expect(list.first.name, 'Bench Press');
      expect(list.first.sessions, 3);
      expect(list.last.sessions, 2);
    });
  });
}
