import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_models.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';

Schedule _schedule() => const Schedule(
  localId: 1,
  syncStatus: 'synced',
  name: 'Push Pull',
  isActive: true,
);

ScheduleDay _day({
  required int id,
  required int dayIndex,
  required String label,
  bool isRestDay = false,
}) => ScheduleDay(
  localId: id,
  syncStatus: 'synced',
  scheduleId: 1,
  dayIndex: dayIndex,
  label: label,
  isRestDay: isRestDay,
);

ScheduledExercise _scheduledExercise({
  required int id,
  required int dayId,
  required String exerciseId,
  required int targetSets,
}) => ScheduledExercise(
  localId: id,
  syncStatus: 'synced',
  scheduleDayId: dayId,
  exerciseId: exerciseId,
  orderIndex: id,
  targetSets: targetSets,
  targetReps: 10,
);

Exercise _exercise({
  required int id,
  required String exerciseId,
  required String name,
  String? muscleGroup,
  String? targetMuscles,
  String? bodyParts,
}) => Exercise(
  localId: id,
  syncStatus: 'synced',
  exerciseId: exerciseId,
  name: name,
  muscleGroup: muscleGroup,
  targetMuscles: targetMuscles,
  bodyParts: bodyParts,
  isCustom: false,
  usageCount: 0,
  isFavorite: false,
);

void main() {
  test('aggregates a current split without losing rest days or rows', () {
    final overview = buildCurrentSplitOverview(
      schedule: _schedule(),
      days: [
        _day(id: 3, dayIndex: 2, label: 'Pull'),
        _day(id: 1, dayIndex: 0, label: 'Push'),
        _day(id: 2, dayIndex: 1, label: 'Rest', isRestDay: true),
      ],
      scheduledExercises: [
        _scheduledExercise(
          id: 1,
          dayId: 1,
          exerciseId: 'bench-press',
          targetSets: 3,
        ),
        _scheduledExercise(
          id: 2,
          dayId: 1,
          exerciseId: 'missing-metadata',
          targetSets: 1,
        ),
        _scheduledExercise(
          id: 3,
          dayId: 3,
          exerciseId: 'lat-pulldown',
          targetSets: 4,
        ),
        _scheduledExercise(
          id: 4,
          dayId: 3,
          exerciseId: 'cycling',
          targetSets: 2,
        ),
      ],
      exercises: [
        _exercise(
          id: 1,
          exerciseId: 'bench-press',
          name: 'Bench press',
          muscleGroup: 'Chest',
        ),
        _exercise(
          id: 2,
          exerciseId: 'lat-pulldown',
          name: 'Lat pulldown',
          targetMuscles: '["lats"]',
          bodyParts: '["back"]',
        ),
        _exercise(
          id: 3,
          exerciseId: 'cycling',
          name: 'Cycling',
          muscleGroup: 'Cardio',
        ),
      ],
    );

    expect(overview.schedule, _schedule());
    expect(overview.days.map((summary) => summary.day.dayIndex), [0, 1, 2]);
    expect(overview.days.map((summary) => summary.day.label), [
      'Push',
      'Rest',
      'Pull',
    ]);
    expect(overview.days.map((summary) => summary.exerciseCount), [2, 0, 2]);
    expect(overview.days.map((summary) => summary.plannedSetCount), [4, 0, 6]);
    expect(overview.days[1].isRestDay, isTrue);
    expect(overview.trainingDayCount, 2);
    expect(overview.restDayCount, 1);
    expect(overview.totalExerciseCount, 4);
    expect(overview.totalPlannedSets, 10);
    expect(overview.plannedMuscleGroups, {'Chest', 'Lats'});
    expect(overview.plannedMuscleGroups.toList(), ['Chest', 'Lats']);
    expect(overview.days[0].muscleGroups, ['Chest']);
    expect(overview.days[1].muscleGroups, isEmpty);
    expect(overview.days[2].muscleGroups, ['Lats']);
    expect(
      overview.anatomyMuscles,
      allOf(
        hasLength(2),
        everyElement(
          isA<MuscleStateInfo>()
              .having((muscle) => muscle.state, 'state', MuscleState.recovered)
              .having(
                (muscle) => muscle.recoveryPercent,
                'recoveryPercent',
                1.0,
              ),
        ),
      ),
    );
  });

  test('returns zero totals for an empty current split', () {
    final overview = buildCurrentSplitOverview(
      schedule: _schedule(),
      days: const [],
      scheduledExercises: const [],
      exercises: const [],
    );

    expect(overview.days, isEmpty);
    expect(overview.trainingDayCount, 0);
    expect(overview.restDayCount, 0);
    expect(overview.totalExerciseCount, 0);
    expect(overview.totalPlannedSets, 0);
    expect(overview.plannedMuscleGroups, isEmpty);
    expect(overview.anatomyMuscles, isEmpty);
  });
}
