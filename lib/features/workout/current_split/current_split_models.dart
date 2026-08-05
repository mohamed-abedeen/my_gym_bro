import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/exercise_mapping.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';

class CurrentSplitDaySummary {
  const CurrentSplitDaySummary({
    required this.day,
    required this.exerciseCount,
    required this.plannedSetCount,
    required this.muscleGroups,
  });

  final ScheduleDay day;
  final int exerciseCount;
  final int plannedSetCount;
  final List<String> muscleGroups;

  bool get isRestDay => day.isRestDay;
}

class CurrentSplitOverviewData {
  const CurrentSplitOverviewData({
    required this.schedule,
    required this.days,
    required this.trainingDayCount,
    required this.restDayCount,
    required this.totalExerciseCount,
    required this.totalPlannedSets,
    required this.plannedMuscleGroups,
  });

  final Schedule schedule;
  final List<CurrentSplitDaySummary> days;
  final int trainingDayCount;
  final int restDayCount;
  final int totalExerciseCount;
  final int totalPlannedSets;
  final Set<String> plannedMuscleGroups;

  List<MuscleStateInfo> get anatomyMuscles => plannedMuscleGroups
      .map(
        (group) => MuscleStateInfo(
          muscleGroup: group,
          state: MuscleState.recovered,
          recoveryPercent: 1,
        ),
      )
      .toList(growable: false);
}

CurrentSplitOverviewData buildCurrentSplitOverview({
  required Schedule schedule,
  required List<ScheduleDay> days,
  required List<ScheduledExercise> scheduledExercises,
  required List<Exercise> exercises,
}) {
  final exercisesById = {
    for (final exercise in exercises) exercise.exerciseId: exercise,
  };
  final scheduledByDayId = <int, List<ScheduledExercise>>{};
  for (final scheduledExercise in scheduledExercises) {
    scheduledByDayId
        .putIfAbsent(scheduledExercise.scheduleDayId, () => [])
        .add(scheduledExercise);
  }

  final plannedMuscleGroups = <String>{};
  final summaries = days.toList()
    ..sort((first, second) => first.dayIndex.compareTo(second.dayIndex));
  final daySummaries = summaries
      .map((day) {
        final scheduledForDay = scheduledByDayId[day.localId] ?? const [];
        final muscleGroups = <String>{};
        var plannedSetCount = 0;

        for (final scheduledExercise in scheduledForDay) {
          plannedSetCount += scheduledExercise.targetSets;
          final exercise = exercisesById[scheduledExercise.exerciseId];
          if (exercise == null) continue;

          final group = _resolveMuscleGroup(exercise);
          if (group == null) continue;
          muscleGroups.add(group);
          plannedMuscleGroups.add(group);
        }

        return CurrentSplitDaySummary(
          day: day,
          exerciseCount: scheduledForDay.length,
          plannedSetCount: plannedSetCount,
          muscleGroups: muscleGroups.toList(growable: false),
        );
      })
      .toList(growable: false);

  return CurrentSplitOverviewData(
    schedule: schedule,
    days: daySummaries,
    trainingDayCount: daySummaries.where((day) => !day.isRestDay).length,
    restDayCount: daySummaries.where((day) => day.isRestDay).length,
    totalExerciseCount: scheduledExercises.length,
    totalPlannedSets: scheduledExercises.fold(
      0,
      (total, scheduledExercise) => total + scheduledExercise.targetSets,
    ),
    plannedMuscleGroups: plannedMuscleGroups,
  );
}

String? _resolveMuscleGroup(Exercise exercise) {
  final directGroup = exercise.muscleGroup?.trim();
  final group = directGroup == null || directGroup.isEmpty
      ? ExerciseMapping.resolveGymMuscleGroup(
          target: ExerciseMapping.decodeJsonList(
            exercise.targetMuscles,
          ).firstOrNull,
          bodyPart: ExerciseMapping.decodeJsonList(
            exercise.bodyParts,
          ).firstOrNull,
          exerciseName: exercise.name,
        )
      : directGroup;

  if (group.isEmpty || group == 'Cardio') return null;
  return group;
}
