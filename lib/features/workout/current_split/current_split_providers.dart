import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_models.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

final currentSplitScheduleIdProvider = StateProvider<int?>((ref) => null);

final scheduleByIdProvider = StreamProvider.family<Schedule?, int>(
  (ref, localId) => ref.watch(scheduleDaoProvider).watchById(localId),
);

final scheduledExercisesForScheduleProvider =
    StreamProvider.family<List<ScheduledExercise>, int>(
      (ref, scheduleId) =>
          ref.watch(scheduleDaoProvider).watchExercisesForSchedule(scheduleId),
    );

final currentSplitOverviewProvider =
    FutureProvider.family<CurrentSplitOverviewData?, int>((
      ref,
      scheduleId,
    ) async {
      final requestedSchedule = await ref.watch(
        scheduleByIdProvider(scheduleId).future,
      );
      final schedule =
          requestedSchedule ?? await ref.watch(activeScheduleProvider.future);
      if (schedule == null) return null;

      final resolvedScheduleId = schedule.localId;
      final days = await ref.watch(
        scheduleDaysProvider(resolvedScheduleId).future,
      );
      final scheduledExercises = await ref.watch(
        scheduledExercisesForScheduleProvider(resolvedScheduleId).future,
      );
      final exerciseIds = scheduledExercises
          .map((scheduledExercise) => scheduledExercise.exerciseId)
          .toSet()
          .toList(growable: false);
      final exercises = exerciseIds.isEmpty
          ? <Exercise>[]
          : await ref.watch(exerciseDaoProvider).findByExerciseIds(exerciseIds);

      return buildCurrentSplitOverview(
        schedule: schedule,
        days: days,
        scheduledExercises: scheduledExercises,
        exercises: exercises,
      );
    });
