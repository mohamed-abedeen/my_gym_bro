import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/services/api_exercise.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';

/// Which muscles a finished session marks as trained. Regression for a chest
/// day (fly, chest press, shoulder press, lateral raise, pushdown) painting
/// Upper Back + Traps on the workout hero and then blocking Pull Day as
/// "Upper Back recovering": the dataset lists `upper back` / `traps` as
/// secondaries of the presses and raises.
void main() {
  late AppDatabase db;
  late MuscleRecoveryService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = MuscleRecoveryService(SessionDao(db), ExerciseDao(db));
  });

  tearDown(() => db.close());

  /// Seeds an exercise the way the API sync does (muscleGroup resolved by
  /// [ApiExercise.toCompanion]).
  Future<void> seedApiExercise(
    String id,
    String name, {
    required String target,
    required String bodyPart,
    List<String> secondary = const [],
  }) =>
      db.into(db.exercises).insert(
            ApiExercise(
              id: id,
              name: name,
              bodyParts: [bodyPart],
              targetMuscles: [target],
              secondaryMuscles: secondary,
            ).toCompanion(),
          );

  Future<void> seedSession(
    DateTime finishedAt,
    Map<String, int> setsByExercise,
  ) async {
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            startedAt: finishedAt.subtract(const Duration(hours: 1)),
            finishedAt: Value(finishedAt),
          ),
        );
    var order = 0;
    for (final entry in setsByExercise.entries) {
      final seId = await db.into(db.sessionExercises).insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: entry.key,
              orderIndex: order++,
            ),
          );
      for (var i = 0; i < entry.value; i++) {
        await db.into(db.workoutSets).insert(
              WorkoutSetsCompanion.insert(
                sessionExerciseId: seId,
                setIndex: i,
                weight: const Value(40),
                reps: const Value(10),
                isCompleted: const Value(true),
              ),
            );
      }
    }
  }

  Future<Map<String, MuscleStateInfo>> states() async => {
        for (final s in await service.getAllMuscleStates()) s.muscleGroup: s,
      };

  Future<void> seedChestDayExercises() async {
    await seedApiExercise('fly', 'lever seated fly',
        target: 'pectorals', bodyPart: 'chest', secondary: ['shoulders']);
    await seedApiExercise('press', 'lever chest press',
        target: 'pectorals',
        bodyPart: 'chest',
        secondary: ['triceps', 'shoulders']);
    await seedApiExercise('ohp', 'lever shoulder press',
        target: 'delts',
        bodyPart: 'shoulders',
        secondary: ['triceps', 'upper back']);
    await seedApiExercise('raise', 'lever lateral raise',
        target: 'delts', bodyPart: 'shoulders', secondary: ['traps']);
    await seedApiExercise('pushdown', 'cable triceps pushdown (v-bar)',
        target: 'triceps', bodyPart: 'upper arms', secondary: ['forearms']);
  }

  test('a chest/shoulder/triceps day never marks back muscles as trained',
      () async {
    await seedChestDayExercises();
    await seedSession(
      DateTime.now().subtract(const Duration(hours: 3)),
      {'fly': 4, 'press': 4, 'ohp': 4, 'raise': 4, 'pushdown': 4},
    );

    final s = await states();
    for (final back in ['Upper Back', 'Traps', 'Lats', 'Lower Back']) {
      expect(s[back]!.state, MuscleState.undertrained, reason: back);
      expect(s[back]!.lastTrainedAt, isNull, reason: back);
    }
    for (final worked in ['Chest', 'Front Delt', 'Side Delt', 'Triceps']) {
      expect(s[worked]!.state, MuscleState.recovering, reason: worked);
    }
    // Synergist-only touches don't count either: the presses list generic
    // 'shoulders', which must not light the rear delts up.
    expect(s['Shoulders']!.state, MuscleState.undertrained);
    expect(s['Rear Delt']!.state, MuscleState.undertrained);
  });

  test('chest day does not add back volume to the weekly totals', () async {
    await seedChestDayExercises();
    final now = DateTime.now();
    await seedSession(
      now.subtract(const Duration(hours: 3)),
      {'fly': 4, 'press': 4, 'ohp': 4, 'raise': 4, 'pushdown': 4},
    );

    final totals = await service.getMuscleDoseTotals(
      from: now.subtract(const Duration(days: 1)),
      to: now.add(const Duration(days: 1)),
    );
    expect(totals.keys, isNot(contains('Upper Back')));
    expect(totals.keys, isNot(contains('Traps')));
    expect(totals['Chest'], 8);
  });

  test('secondary credit still tops up a muscle trained directly that day',
      () async {
    await seedApiExercise('row', 'cable seated row',
        target: 'upper back', bodyPart: 'back', secondary: ['biceps']);
    await seedApiExercise('ohp', 'lever shoulder press',
        target: 'delts',
        bodyPart: 'shoulders',
        secondary: ['triceps', 'upper back']);
    final now = DateTime.now();
    await seedSession(
      now.subtract(const Duration(hours: 3)),
      {'row': 4, 'ohp': 4},
    );

    final totals = await service.getMuscleDoseTotals(
      from: now.subtract(const Duration(days: 1)),
      to: now.add(const Duration(days: 1)),
    );
    // 4 direct row sets + 4 × 0.5 from the press.
    expect(totals['Upper Back'], 6);
    final s = await states();
    expect(s['Upper Back']!.state, MuscleState.recovering);
    // Biceps were only a synergist of the row → not trained.
    expect(s['Biceps']!.state, MuscleState.undertrained);
  });
}
