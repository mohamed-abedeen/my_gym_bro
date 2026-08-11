import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// A scheduled exercise joined with its exercise-library row.
/// [exercise] can be null when the library entry is missing offline.
class DayExercise {
  const DayExercise({required this.scheduled, this.exercise});
  final ScheduledExercise scheduled;
  final Exercise? exercise;
}

/// Exercises of one schedule day, in order, joined with library data.
final dayExercisesProvider = FutureProvider.family<List<DayExercise>, int>((
  ref,
  scheduleDayId,
) async {
  final scheduleDao = ref.watch(scheduleDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);

  final scheduled = await scheduleDao.getExercises(scheduleDayId);
  if (scheduled.isEmpty) return const [];

  final ids = scheduled.map((s) => s.exerciseId).toSet().toList();
  final byId = {
    for (final e in await exerciseDao.findByExerciseIds(ids)) e.exerciseId: e,
  };
  return [
    for (final s in scheduled)
      DayExercise(scheduled: s, exercise: byId[s.exerciseId]),
  ];
});

/// One schedule day by its local id.
final scheduleDayProvider = FutureProvider.family<ScheduleDay?, int>(
  (ref, dayId) => ref.watch(scheduleDaoProvider).getDayById(dayId),
);

/// Progress through the current training cycle (completed sessions modulo
/// plan length), as 0..1.
final scheduleCycleProgressProvider = FutureProvider.family<double, int>((
  ref,
  scheduleId,
) async {
  final scheduleDao = ref.watch(scheduleDaoProvider);
  final sessionDao = ref.watch(sessionDaoProvider);

  final days = await scheduleDao.getDays(scheduleId);
  final trainingDays = days.where((d) => !isRestScheduleDay(d)).length;
  if (trainingDays == 0) return 0;

  final completed = await sessionDao.countBySchedule(scheduleId);
  return (completed % trainingDays) / trainingDays;
});

/// Estimated session length across a schedule's training days, as a
/// (min, max) minutes range — null when no day has exercises yet.
final scheduleSessionMinutesProvider =
    FutureProvider.family<(int, int)?, int>((ref, scheduleId) async {
  final scheduleDao = ref.watch(scheduleDaoProvider);

  final days = await scheduleDao.getDays(scheduleId);
  var lo = 0;
  var hi = 0;
  for (final day in days.where((d) => !isRestScheduleDay(d))) {
    final count = (await scheduleDao.getExercises(day.localId)).length;
    if (count == 0) continue;
    final (mn, mx) = estimateSessionMinutes(count);
    if (lo == 0 || mn < lo) lo = mn;
    if (mx > hi) hi = mx;
  }
  return hi == 0 ? null : (lo, hi);
});

/// The distinct muscle groups of a day's exercises, in exercise order.
List<String> dayMuscleGroups(List<DayExercise> items) {
  final seen = <String>{};
  return [
    for (final item in items)
      if (item.exercise?.muscleGroup case final String m)
        if (m.isNotEmpty && seen.add(m)) m,
  ];
}

/// Rough session length in minutes for a day with [exerciseCount] exercises,
/// as a (min, max) range rounded to 5.
(int, int) estimateSessionMinutes(int exerciseCount) {
  // Floor the low end, round the high end — keeps min strictly below max
  // so tiny days show "5–10 min.", never "10–10 min.".
  final lo = (exerciseCount * 7.5 / 5).floor() * 5;
  final hi = (exerciseCount * 10 / 5).round() * 5;
  return (lo < 5 ? 5 : lo, hi <= lo ? lo + 5 : hi);
}

/// Rough calorie burn for a day with [exerciseCount] exercises,
/// as a (min, max) range rounded to 10.
(int, int) estimateSessionKcal(int exerciseCount) {
  final lo = (exerciseCount * 58 / 10).floor() * 10;
  final hi = (exerciseCount * 83 / 10).round() * 10;
  return (lo < 10 ? 10 : lo, hi <= lo ? lo + 10 : hi);
}
