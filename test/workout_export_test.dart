import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/workout_export.dart';

void main() {
  group('csvEscape', () {
    test('leaves plain cells untouched', () {
      expect(csvEscape('bench press'), 'bench press');
    });

    test('quotes commas, doubles quotes, wraps newlines', () {
      expect(csvEscape('push, pull'), '"push, pull"');
      expect(csvEscape('the "big" lift'), '"the ""big"" lift"');
      expect(csvEscape('line1\nline2'), '"line1\nline2"');
    });
  });

  group('buildWorkoutCsv', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('returns null on an empty database', () async {
      expect(await buildWorkoutCsv(db, WeightUnit.kg), isNull);
    });

    test('emits one row per set with joined names, unit conversion and '
        'escaping', () async {
      final scheduleId = await db.into(db.schedules).insert(
            SchedulesCompanion.insert(name: 'Push, Day'),
          );
      await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              exerciseId: 'bench01',
              name: 'Bench "Press"',
            ),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              scheduleId: Value(scheduleId),
              startedAt: DateTime(2026, 7, 14, 18, 30),
            ),
          );
      final seId = await db.into(db.sessionExercises).insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: 'bench01',
              orderIndex: 0,
            ),
          );
      // Exercise not in the catalogue → falls back to the raw id.
      final seOrphan = await db.into(db.sessionExercises).insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: 'ghost99',
              orderIndex: 1,
            ),
          );
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionExerciseId: seId,
              setIndex: 0,
              weight: const Value(100),
              reps: const Value(5),
              isCompleted: const Value(true),
              isDropset: const Value(true),
            ),
          );
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionExerciseId: seOrphan,
              setIndex: 0,
              isWarmup: const Value(true),
            ),
          );

      final csv = await buildWorkoutCsv(db, WeightUnit.lbs);
      expect(csv, isNotNull);

      final lines = csv!.trimRight().split('\r\n');
      expect(lines, hasLength(3)); // header + 2 sets
      expect(
        lines[0],
        'date,workout,exercise,set,weight,unit,reps,completed,warmup,'
        'dropset,failure,rpe,duration_seconds,distance',
      );
      // Schedule/exercise names escaped, 100 kg → 220.46 lbs, set 1-based.
      expect(
        lines[1],
        '2026-07-14,"Push, Day","Bench ""Press""",1,220.46,lbs,5,1,0,1,0,,,',
      );
      // No weight/reps → empty cells; unknown exercise → raw id; warmup flag.
      expect(lines[2], '2026-07-14,"Push, Day",ghost99,1,,lbs,,0,1,0,0,,,');
    });
  });
}
