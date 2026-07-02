import 'dart:async';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/widget_sync_service.dart';
import 'package:my_gym_bro/features/workout/calorie_service.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_log_repository.dart';

// ── DAOs ──────────────────────────────────────

final sessionDaoProvider = Provider<SessionDao>((ref) {
  return SessionDao(ref.watch(databaseProvider));
});

final exerciseDaoProvider = Provider<ExerciseDao>((ref) {
  return ExerciseDao(ref.watch(databaseProvider));
});

final scheduleDaoProvider = Provider<ScheduleDao>((ref) {
  return ScheduleDao(ref.watch(databaseProvider));
});

final userProfileDaoProvider = Provider<UserProfileDao>((ref) {
  return UserProfileDao(ref.watch(databaseProvider));
});

// ── Repository ────────────────────────────────

final workoutLogRepositoryProvider = Provider<WorkoutLogRepository>((ref) {
  return WorkoutLogRepository(
    sessionDao: ref.watch(sessionDaoProvider),
    exerciseDao: ref.watch(exerciseDaoProvider),
    scheduleDao: ref.watch(scheduleDaoProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

/// Volume per past session for an exercise ID, oldest→newest, up to 10 entries.
final exerciseVolumeHistoryProvider =
    FutureProvider.family<List<double>, String>((ref, exerciseId) {
  return ref.watch(sessionDaoProvider).getVolumeHistoryForExercise(exerciseId);
});

@immutable
class ExerciseVolumeParams {
  const ExerciseVolumeParams(this.exerciseId, {this.from});
  final String exerciseId;
  final DateTime? from;

  @override
  bool operator ==(Object other) =>
      other is ExerciseVolumeParams &&
      other.exerciseId == exerciseId &&
      other.from == from;

  @override
  int get hashCode => Object.hash(exerciseId, from);
}

/// Volume history with dates for a given exercise and optional start date.
final exerciseVolumeWithDatesProvider = FutureProvider.family<
    List<({DateTime date, double volume})>,
    ExerciseVolumeParams>((ref, params) {
  return ref.watch(sessionDaoProvider).getVolumeHistoryWithDates(
        params.exerciseId,
        from: params.from,
      );
});

/// Personal records for a given exercise.
final exercisePersonalRecordsProvider =
    FutureProvider.family<ExercisePersonalRecords, String>(
        (ref, exerciseId) {
  return ref.watch(sessionDaoProvider).getPersonalRecords(exerciseId);
});

/// Session history (with sets) for a given exercise, newest first.
final exerciseSessionHistoryProvider =
    FutureProvider.family<List<ExerciseHistoryEntry>, String>(
        (ref, exerciseId) {
  return ref.watch(sessionDaoProvider).getSessionsForExercise(exerciseId);
});

// ── Schedules ─────────────────────────────────

final activeScheduleProvider = StreamProvider<Schedule?>((ref) {
  return ref.watch(scheduleDaoProvider).watchActive();
});

/// All schedules for the swipeable card.
final allSchedulesProvider = StreamProvider<List<Schedule>>((ref) {
  return ref.watch(scheduleDaoProvider).watchAll();
});

/// Schedule days for a given schedule — reactive stream backed by Drift.
/// Emits a new list automatically whenever a day is inserted, updated, or deleted,
/// so the workout card and share sheet rebuild without manual invalidation.
final scheduleDaysProvider =
    StreamProvider.family<List<ScheduleDay>, int>((ref, scheduleId) {
  return ref.watch(scheduleDaoProvider).watchDays(scheduleId);
});

// ── Workout card persistent state ─────────────

/// Persists the selected schedule ID and page index across tab switches.
class WorkoutCardState {

  const WorkoutCardState({this.selectedScheduleId, this.currentPage = 0});
  final int? selectedScheduleId;
  final int currentPage;

  WorkoutCardState copyWith({int? selectedScheduleId, int? currentPage}) {
    return WorkoutCardState(
      selectedScheduleId: selectedScheduleId ?? this.selectedScheduleId,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

final workoutCardStateProvider =
    StateProvider<WorkoutCardState>((ref) => const WorkoutCardState());

// ── Next training day index ──────────────────

/// Whether a schedule day is a rest day, either by flag or by label.
bool _isRestScheduleDay(ScheduleDay d) =>
    d.isRestDay || (d.label?.toLowerCase().contains('rest') ?? false);

/// Determines which training day page to show based on completed sessions.
///
/// Logic: nextIndex = completedSessions % trainingDays.length
/// Returns 0 if no sessions exist yet (start from the first day).
final nextTrainingDayIndexProvider =
    FutureProvider.family<int, int>((ref, scheduleId) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final scheduleDao = ref.watch(scheduleDaoProvider);

  final days = await scheduleDao.getDays(scheduleId);
  final trainingDays = days.where((d) => !_isRestScheduleDay(d)).toList();
  if (trainingDays.isEmpty) return 0;

  final completedCount = await sessionDao.countBySchedule(scheduleId);
  return completedCount % trainingDays.length;
});

// ── Next session timer ────────────────────────

/// Calculates hours until the next training session is due.
///
/// Logic:
/// 1. Find the last completed session for this schedule.
/// 2. Determine which training day was last and which is next.
/// 3. Walk the schedule cyclically from the last training day to the next,
///    counting the actual rest days in between.
/// 4. gap hours = rest days × 24h from the last session's finish time.
/// 5. If the gap has passed → return 0 (ready to train).
///
/// Returns null if no sessions exist yet.
final nextSessionHoursProvider =
    FutureProvider.family<int?, int>((ref, scheduleId) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final scheduleDao = ref.watch(scheduleDaoProvider);

  // 1. Last completed session for this schedule
  final lastSession = await sessionDao.getLastForSchedule(scheduleId);
  if (lastSession == null) return null; // never trained

  final lastFinished = lastSession.finishedAt ?? lastSession.startedAt;

  // 2. Get the full day list and training days
  final allDays = await scheduleDao.getDays(scheduleId);
  if (allDays.isEmpty) return null;

  final trainingDays = allDays.where((d) => !_isRestScheduleDay(d)).toList();
  if (trainingDays.isEmpty) return null;

  // Figure out which training day was last completed and which is next
  final completedCount = await sessionDao.countBySchedule(scheduleId);
  // The last completed day index (0-based in training days list)
  final lastDayIdx = (completedCount - 1) % trainingDays.length;
  // The next training day index
  final nextDayIdx = completedCount % trainingDays.length;

  // 3. Count actual rest days between the last and next training day
  //    by walking the full allDays list cyclically
  final lastDayIndex = trainingDays[lastDayIdx].dayIndex;
  final nextDayIndex = trainingDays[nextDayIdx].dayIndex;
  final totalDaysInCycle = allDays.length;

  var restDaysBetween = 0;
  var pos = (lastDayIndex + 1) % totalDaysInCycle;
  while (pos != nextDayIndex) {
    final day = allDays.firstWhere((d) => d.dayIndex == pos);
    if (_isRestScheduleDay(day)) {
      restDaysBetween++;
    }
    pos = (pos + 1) % totalDaysInCycle;
  }

  // If no rest days between, the user can train immediately (0h gap)
  if (restDaysBetween == 0) {
    return 0;
  }

  // 4. Calculate remaining hours: rest days × 24h from last finish
  final gapHours = restDaysBetween * 24;
  final nextDue = lastFinished.add(Duration(hours: gapHours));
  final now = DateTime.now();
  final remaining = nextDue.difference(now).inHours;

  return remaining > 0 ? remaining : 0;
});

// ── Recovery-based day readiness ─────────────

/// Recovery status for a specific training day, based on the muscles it targets.
class DayRecoveryStatus {

  const DayRecoveryStatus({this.hoursRemaining, this.bottleneckMuscle});
  /// Hours remaining until the bottleneck muscle is fully recovered.
  /// 0 = all muscles ready. null = never trained (ready to go).
  final int? hoursRemaining;

  /// The muscle group that is the bottleneck (least recovered).
  final String? bottleneckMuscle;

  /// True when all involved muscles are fully recovered.
  bool get isReady => hoursRemaining == null || hoursRemaining! <= 0;
}

/// Computes recovery readiness for a specific schedule day.
///
/// 1. Fetches all exercises assigned to the day.
/// 2. Looks up their muscle groups.
/// 3. Checks each muscle's recovery % via MuscleRecoveryService.
/// 4. Finds the bottleneck (least recovered muscle).
/// 5. Calculates remaining hours until that muscle hits 100%.
final dayRecoveryStatusProvider =
    FutureProvider.family<DayRecoveryStatus, int>((ref, scheduleDayId) async {
  final scheduleDao = ref.watch(scheduleDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final sessionDao = ref.watch(sessionDaoProvider);

  // 1. Get exercises for this training day
  final scheduledExercises = await scheduleDao.getExercises(scheduleDayId);
  if (scheduledExercises.isEmpty) {
    return const DayRecoveryStatus(); // no exercises → ready
  }

  // 2. Look up the actual exercise data to get muscle groups
  final exerciseIds =
      scheduledExercises.map((se) => se.exerciseId).toSet().toList();
  final exercises = await exerciseDao.findByExerciseIds(exerciseIds);

  // Extract unique muscle groups involved in this day
  final muscleGroups = <String>{};
  for (final ex in exercises) {
    if (ex.muscleGroup != null && ex.muscleGroup!.isNotEmpty) {
      muscleGroups.add(ex.muscleGroup!);
    }
  }

  if (muscleGroups.isEmpty) {
    return const DayRecoveryStatus(); // no muscle data → ready
  }

  // 3. Get recovery state for all muscles
  final recoveryService = MuscleRecoveryService(sessionDao, exerciseDao);
  final allStates = await recoveryService.getAllMuscleStates();

  // 4. Find the bottleneck among the muscles used in this day
  String? bottleneck;
  var maxRemainingHours = 0;

  for (final group in muscleGroups) {
    final state = allStates.firstWhere(
      (s) => s.muscleGroup == group,
      orElse: () => MuscleStateInfo(
        muscleGroup: group,
        state: MuscleState.undertrained,
      ),
    );

    // Undertrained or fully recovered → 0 hours remaining
    if (state.state == MuscleState.undertrained ||
        state.state == MuscleState.recovered) {
      continue;
    }

    // Recovering → remaining hours until the dose-adjusted window closes.
    final recoveredAt = state.recoveredAt;
    if (recoveredAt != null) {
      final remaining =
          (recoveredAt.difference(DateTime.now()).inMinutes / 60.0).ceil();

      if (remaining > maxRemainingHours) {
        maxRemainingHours = remaining;
        bottleneck = group;
      }
    }
  }

  if (maxRemainingHours <= 0) {
    return const DayRecoveryStatus(); // all muscles ready
  }

  return DayRecoveryStatus(
    hoursRemaining: maxRemainingHours,
    bottleneckMuscle: bottleneck,
  );
});

// ── User profile ──────────────────────────────

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(userProfileDaoProvider).watchProfile();
});

/// Whole-app paywall gate. True when access must be blocked: the trial window
/// has elapsed, or the subscription is expired. Returns false while the
/// profile is loading or absent (pre-onboarding) so we never lock a user we
/// don't yet know about. This is the single source of truth for gating —
/// the router redirect and the paywall both read it.
final subscriptionLockedProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return false;
  switch (profile.subscriptionStatus) {
    case 'active':
      return false;
    case 'expired':
      return true;
    case 'trial':
      final end = profile.subscriptionExpiresAt;
      return end != null && DateTime.now().isAfter(end);
    default:
      // 'grace_period' or any unknown status → don't lock.
      return false;
  }
});

/// Whole days left in the free trial, rounded up. Null when the user isn't in
/// a trial (active/expired) or there's no known trial window. 0 means the
/// trial has just elapsed.
final trialDaysLeftProvider = Provider<int?>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null || profile.subscriptionStatus != 'trial') return null;
  final end = profile.subscriptionExpiresAt;
  if (end == null) return null;
  final minutes = end.difference(DateTime.now()).inMinutes;
  if (minutes <= 0) return 0;
  return (minutes / (60 * 24)).ceil();
});

/// Gender from user profile — defaults to 'male' if not set.
final userGenderProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.whenOrNull(data: (p) => p?.gender) ?? 'male';
});

// ── Recent sessions (last 3) ──────────────────

final recentSessionsProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(sessionDaoProvider).watchRecent(3);
});

// ── Weekly strip data ─────────────────────────

/// Local midnight on Monday of the week containing [now]. Every "this week"
/// metric in the app (week strip, weekly stats, activity stats, calories)
/// anchors to this so different cards can never disagree about the window.
DateTime _startOfWeek(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday - 1));

class DayData {

  const DayData({
    required this.date,
    required this.abbreviation,
    required this.dayNumber,
    required this.isToday,
    required this.hasSession,
  });
  final DateTime date;
  final String abbreviation;
  final int dayNumber;
  final bool isToday;
  final bool hasSession;
}

final weekStripProvider = FutureProvider.family<List<DayData>, Locale>(
  (ref, locale) async {
    final now = DateTime.now();
    // Monday 00:00 of this week through next Monday 00:00 (exclusive).
    final mondayMidnight = _startOfWeek(now);
    final nextMondayMidnight = mondayMidnight.add(const Duration(days: 7));
    final sessionDao = ref.watch(sessionDaoProvider);

    // Single range query instead of 7 sequential hasSessionOnDate calls.
    final sessions =
        await sessionDao.getInRange(mondayMidnight, nextMondayMidnight);
    final sessionDays = <int>{
      for (final s in sessions)
        DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)
            .millisecondsSinceEpoch,
    };

    return [
      for (var i = 0; i < 7; i++)
        () {
          final date = DateTime(
            mondayMidnight.year,
            mondayMidnight.month,
            mondayMidnight.day + i,
          );
          final abbr = DateFormat.E(locale.languageCode).format(date);
          return DayData(
            date: date,
            abbreviation: abbr.substring(0, abbr.length.clamp(0, 3)),
            dayNumber: date.day,
            isToday: date.year == now.year &&
                date.month == now.month &&
                date.day == now.day,
            hasSession: sessionDays.contains(date.millisecondsSinceEpoch),
          );
        }(),
    ];
  },
);

// ── Weekly stats ──────────────────────────────

/// Epley estimated one-rep max: `weight × (1 + reps/30)`. A single-rep set
/// is its own 1RM. The industry-standard strength measure (Strong, Hevy)
/// — unlike volume-per-session it doesn't reward junk sets and doesn't
/// drop when the user trains heavier for fewer reps.
double epleyOneRepMax(double weight, int reps) =>
    reps <= 1 ? weight : weight * (1 + reps / 30.0);

/// Mean of the best estimated 1RM per exercise across [sessions].
/// Warmup and incomplete sets are excluded. Returns 0 when there is no
/// completed weighted set.
Future<double> _avgBestE1Rm(
  SessionDao sessionDao,
  List<Session> sessions,
) async {
  if (sessions.isEmpty) return 0;

  final sessionExercises = await sessionDao
      .getSessionExercisesForSessions(sessions.map((s) => s.localId).toList());
  if (sessionExercises.isEmpty) return 0;

  final sets = await sessionDao.getSetsForSessionExercises(
    sessionExercises.map((se) => se.localId).toList(),
  );

  final exerciseIdBySeId = {
    for (final se in sessionExercises) se.localId: se.exerciseId,
  };

  final bestPerExercise = <String, double>{};
  for (final s in sets) {
    if (!s.isCompleted || s.isWarmup) continue;
    final weight = s.weight;
    final reps = s.reps;
    if (weight == null || reps == null || weight <= 0 || reps <= 0) continue;
    final exerciseId = exerciseIdBySeId[s.sessionExerciseId];
    if (exerciseId == null) continue;
    final e1rm = epleyOneRepMax(weight, reps);
    if (e1rm > (bestPerExercise[exerciseId] ?? 0)) {
      bestPerExercise[exerciseId] = e1rm;
    }
  }
  if (bestPerExercise.isEmpty) return 0;
  return bestPerExercise.values.reduce((a, b) => a + b) /
      bestPerExercise.length;
}

class WeeklyStats {

  const WeeklyStats({
    this.totalVolume = 0,
    this.totalDurationSeconds = 0,
    this.avgStrength = 0,
    this.volumeTrend,
    this.durationTrend,
    this.strengthTrend,
  });
  final double totalVolume;
  final int totalDurationSeconds;
  final double avgStrength;
  final double? volumeTrend;
  final double? durationTrend;
  final double? strengthTrend;

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

final weeklyStatsProvider = FutureProvider<WeeklyStats>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final now = DateTime.now();
  final weekStart = _startOfWeek(now);
  final weekEnd = weekStart.add(const Duration(days: 7));

  // This week
  final thisWeek = await sessionDao.getInRange(weekStart, weekEnd);

  // Last week for trend calculation
  final lastWeekStart = weekStart.subtract(const Duration(days: 7));
  final lastWeek = await sessionDao.getInRange(lastWeekStart, weekStart);

  double totalVol = 0;
  var totalDur = 0;
  for (final s in thisWeek) {
    totalVol += s.totalVolume ?? 0;
    totalDur += s.durationSeconds ?? 0;
  }

  double lastVol = 0;
  var lastDur = 0;
  for (final s in lastWeek) {
    lastVol += s.totalVolume ?? 0;
    lastDur += s.durationSeconds ?? 0;
  }

  // Strength = mean of the best estimated 1RM per exercise in the window.
  final avgStr = await _avgBestE1Rm(sessionDao, thisWeek);
  final lastAvgStr = await _avgBestE1Rm(sessionDao, lastWeek);

  // Suppress trends when the user hasn't trained yet this week — it's
  // misleading to show "-100%" because they opened the app on Monday.
  // Trends are also suppressed when this week's contribution to a given
  // metric is zero (e.g. a still-empty session): there's nothing to
  // compare yet.
  final hasThisWeek = thisWeek.isNotEmpty;
  return WeeklyStats(
    totalVolume: totalVol,
    totalDurationSeconds: totalDur,
    avgStrength: avgStr,
    volumeTrend: (hasThisWeek && totalVol > 0 && lastVol > 0)
        ? ((totalVol - lastVol) / lastVol * 100)
        : null,
    durationTrend: (hasThisWeek && totalDur > 0 && lastDur > 0)
        ? ((totalDur - lastDur) / lastDur * 100)
        : null,
    strengthTrend: (hasThisWeek && avgStr > 0 && lastAvgStr > 0)
        ? (avgStr - lastAvgStr).roundToDouble()
        : null,
  );
});

// ── Lifetime + activity aggregates (used by the Status bottom sheet) ──

class LifetimeStats {
  const LifetimeStats({
    this.totalVolume = 0,
    this.totalDurationSeconds = 0,
    this.avgStrength = 0,
    this.sessionCount = 0,
  });
  final double totalVolume;
  final int totalDurationSeconds;
  final double avgStrength;
  final int sessionCount;

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// All-time totals across every finished session — used by the Status
/// sheet so the user sees their full history, not just this week.
final lifetimeStatsProvider = FutureProvider<LifetimeStats>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final all = (await sessionDao.getAll())
      .where((s) => s.finishedAt != null)
      .toList(growable: false);
  if (all.isEmpty) return const LifetimeStats();

  double totalVol = 0;
  var totalDur = 0;
  for (final s in all) {
    totalVol += s.totalVolume ?? 0;
    totalDur += s.durationSeconds ?? 0;
  }
  return LifetimeStats(
    totalVolume: totalVol,
    totalDurationSeconds: totalDur,
    avgStrength: await _avgBestE1Rm(sessionDao, all),
    sessionCount: all.length,
  );
});

class ActivityStats {
  const ActivityStats({
    this.todayVolume = 0,
    this.weekVolume = 0,
    this.monthVolume = 0,
    this.todayCalories = 0,
    this.weekCalories = 0,
    this.monthCalories = 0,
  });
  final double todayVolume;
  final double weekVolume;
  final double monthVolume;
  final int todayCalories;
  final int weekCalories;
  final int monthCalories;
}

/// Fallback body weight (kg) when the user hasn't set theirs yet. Picked
/// to roughly match the global adult mean so calorie estimates are
/// directionally right rather than zero. Visible cue to set weight is up
/// to the UI.
const double _kFallbackBodyWeightKg = 70;

/// Legacy flat calorie estimate — kept for sessions with no set-level data
/// and as the reference model in tests. Prefer [CalorieService] via
/// [_sessionCaloriesBatch] everywhere else.
int caloriesForSession(double bodyWeightKg, int durationSeconds) {
  return CalorieService.estimateSessionCalories(
    bodyWeightKg: bodyWeightKg,
    durationSeconds: durationSeconds,
  );
}

/// MET-weighted calories per session (keyed by session localId), computed
/// in three batch queries. Each exercise's completed sets contribute their
/// own duration (cardio) or [CalorieService.assumedSetSeconds] of work at
/// the exercise's MET; the remaining wall-clock time bills at the rest
/// MET. Sessions with no logged sets fall back to the flat model inside
/// [CalorieService.estimateSessionCalories].
Future<Map<int, int>> _sessionCaloriesBatch(
  SessionDao sessionDao,
  ExerciseDao exerciseDao,
  List<Session> sessions, {
  required double bodyWeightKg,
  String? gender,
}) async {
  final finished =
      sessions.where((s) => s.finishedAt != null).toList(growable: false);
  if (finished.isEmpty) return {};

  final sessionExercises = await sessionDao.getSessionExercisesForSessions(
    finished.map((s) => s.localId).toList(),
  );
  final sets = sessionExercises.isEmpty
      ? <WorkoutSet>[]
      : await sessionDao.getSetsForSessionExercises(
          sessionExercises.map((se) => se.localId).toList(),
        );
  final exerciseIds =
      sessionExercises.map((se) => se.exerciseId).toSet().toList();
  final exercises = exerciseIds.isEmpty
      ? <Exercise>[]
      : await exerciseDao.findByExerciseIds(exerciseIds);
  final exerciseMap = {for (final e in exercises) e.exerciseId: e};

  // Active seconds per session exercise from its completed sets.
  final activeSecondsBySeId = <int, int>{};
  for (final s in sets) {
    if (!s.isCompleted) continue;
    activeSecondsBySeId[s.sessionExerciseId] =
        (activeSecondsBySeId[s.sessionExerciseId] ?? 0) +
            (s.durationSeconds ?? CalorieService.assumedSetSeconds);
  }

  final effortsBySessionId = <int, List<ExerciseEffort>>{};
  for (final se in sessionExercises) {
    final activeSeconds = activeSecondsBySeId[se.localId] ?? 0;
    if (activeSeconds == 0) continue;
    final met = CalorieService.metForExercise(
      muscleGroup: exerciseMap[se.exerciseId]?.muscleGroup,
    );
    effortsBySessionId.putIfAbsent(se.sessionId, () => []).add(
          ExerciseEffort(met: met, activeSeconds: activeSeconds),
        );
  }

  return {
    for (final s in finished)
      s.localId: CalorieService.estimateSessionCalories(
        bodyWeightKg: bodyWeightKg,
        durationSeconds: s.durationSeconds ?? 0,
        efforts: effortsBySessionId[s.localId] ?? const [],
        gender: gender,
      ),
  };
}

/// Volume + calories rolled up over today, this week (Monday-anchored, same
/// window as [weeklyStatsProvider]), and this calendar month. Powers the
/// "Body Status" card in the Status sheet.
final activityStatsProvider = FutureProvider<ActivityStats>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final profile = await ref.watch(userProfileProvider.future);
  final bodyWeight =
      profile?.bodyWeightKg ?? _kFallbackBodyWeightKg;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final weekStart = _startOfWeek(now);
  final monthStart = DateTime(now.year, now.month);
  // The week can straddle a month boundary — fetch from the earlier of the
  // two starts so both rollups see every session they need.
  final rangeStart =
      weekStart.isBefore(monthStart) ? weekStart : monthStart;

  final rangeSessions = await sessionDao.getInRange(rangeStart, tomorrow);
  final calories = await _sessionCaloriesBatch(
    sessionDao,
    exerciseDao,
    rangeSessions,
    bodyWeightKg: bodyWeight,
    gender: profile?.gender,
  );

  double todayVol = 0;
  double weekVol = 0;
  double monthVol = 0;
  var todayCal = 0;
  var weekCal = 0;
  var monthCal = 0;
  for (final s in rangeSessions) {
    if (s.finishedAt == null) continue;
    final v = s.totalVolume ?? 0;
    final c = calories[s.localId] ?? 0;
    if (!s.startedAt.isBefore(monthStart)) {
      monthVol += v;
      monthCal += c;
    }
    if (!s.startedAt.isBefore(weekStart)) {
      weekVol += v;
      weekCal += c;
    }
    if (!s.startedAt.isBefore(today)) {
      todayVol += v;
      todayCal += c;
    }
  }
  return ActivityStats(
    todayVolume: todayVol,
    weekVolume: weekVol,
    monthVolume: monthVol,
    todayCalories: todayCal,
    weekCalories: weekCal,
    monthCalories: monthCal,
  );
});

// ── Enriched sessions (with derived workout name) ──

class EnrichedSession {

  const EnrichedSession({
    required this.session,
    required this.workoutName,
    this.exercises = const [],
    this.targetedMuscleGroups = const [],
  });
  final Session session;
  final String workoutName;
  final List<SessionExerciseDetail> exercises;
  final List<String> targetedMuscleGroups;
}

class SessionExerciseDetail {

  const SessionExerciseDetail({
    required this.name,
    required this.exerciseId,
    this.gifUrl,
    this.muscleGroup,
    this.sets = 0,
    this.totalVolume = 0,
    this.startedAt,
    this.setDetails = const [],
  });
  final String name;
  final String exerciseId;
  final String? gifUrl;
  final String? muscleGroup;
  final int sets;
  final double totalVolume;
  final DateTime? startedAt;
  final List<SetDetail> setDetails;
}

/// Individual set data for exercise detail view.
class SetDetail {

  const SetDetail({
    required this.setIndex,
    this.weight,
    this.reps,
    this.isWarmup = false,
    this.isDropset = false,
  });
  final int setIndex;
  final double? weight;
  final int? reps;
  final bool isWarmup;
  final bool isDropset;
}

/// Payload sent across the isolate boundary for enrichment.
class _EnrichInput {
  const _EnrichInput(
    this.sessions,
    this.sessionExercises,
    this.sets,
    this.exercises,
  );
  final List<Session> sessions;
  final List<SessionExercise> sessionExercises;
  final List<WorkoutSet> sets;
  final List<Exercise> exercises;
}

/// Top-level so it can run inside `compute()`. Pure CPU — no DB access.
List<EnrichedSession> _enrichSessionsIsolate(_EnrichInput input) {
  final exerciseMap = {for (final e in input.exercises) e.exerciseId: e};

  final setsBySeId = <int, List<WorkoutSet>>{};
  for (final s in input.sets) {
    setsBySeId.putIfAbsent(s.sessionExerciseId, () => []).add(s);
  }

  final seBySessionId = <int, List<SessionExercise>>{};
  for (final se in input.sessionExercises) {
    seBySessionId.putIfAbsent(se.sessionId, () => []).add(se);
  }

  final enriched = <EnrichedSession>[];
  for (final session in input.sessions) {
    final sessionExercises = seBySessionId[session.localId] ?? [];
    final details = <SessionExerciseDetail>[];
    final muscleGroupCounts = <String, int>{};

    for (final se in sessionExercises) {
      final exercise = exerciseMap[se.exerciseId];
      final sets = setsBySeId[se.localId] ?? [];

      double vol = 0;
      var completedSets = 0;
      for (final s in sets) {
        if (!s.isCompleted) continue;
        completedSets++;
        if (s.weight != null && s.reps != null) {
          vol += s.weight! * s.reps!;
        }
      }

      if (exercise != null) {
        details.add(SessionExerciseDetail(
          name: exercise.name,
          exerciseId: se.exerciseId,
          gifUrl: exercise.gifUrl,
          muscleGroup: exercise.muscleGroup,
          sets: completedSets,
          totalVolume: vol,
          startedAt: se.createdAt,
          setDetails: sets
              .map((s) => SetDetail(
                    setIndex: s.setIndex,
                    weight: s.weight,
                    reps: s.reps,
                    isWarmup: s.isWarmup,
                    isDropset: s.isDropset,
                  ))
              .toList(),
        ));

        final mg = exercise.muscleGroup ?? 'General';
        muscleGroupCounts[mg] = (muscleGroupCounts[mg] ?? 0) + 1;
      }
    }

    String workoutName;
    if (muscleGroupCounts.isNotEmpty) {
      final topMuscle = muscleGroupCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      workoutName = '$topMuscle Day';
    } else {
      workoutName = 'Workout';
    }

    enriched.add(EnrichedSession(
      session: session,
      workoutName: workoutName,
      exercises: details,
      targetedMuscleGroups: muscleGroupCounts.keys.toList(),
    ));
  }

  return enriched;
}

/// Batch-enrich multiple sessions in 3 queries instead of N×M. The DB reads
/// stay on the current isolate (Drift manages its own pool), but the CPU-heavy
/// grouping/rollup work is offloaded via `compute()` so the Workout tab does
/// not jank while opening.
Future<List<EnrichedSession>> _enrichSessionsBatch(
  List<Session> sessions,
  SessionDao sessionDao,
  ExerciseDao exerciseDao,
) async {
  if (sessions.isEmpty) return [];

  // 1) One query: get ALL session exercises for all sessions
  final sessionIds = sessions.map((s) => s.localId).toList();
  final allSessionExercises =
      await sessionDao.getSessionExercisesForSessions(sessionIds);

  // 2) One query: get ALL sets for all session exercises
  final seIds = allSessionExercises.map((se) => se.localId).toList();
  final allSets = seIds.isNotEmpty
      ? await sessionDao.getSetsForSessionExercises(seIds)
      : <WorkoutSet>[];

  // 3) One query: get ALL unique exercises
  final uniqueExerciseIds =
      allSessionExercises.map((se) => se.exerciseId).toSet().toList();
  final exerciseList = uniqueExerciseIds.isNotEmpty
      ? await exerciseDao.findByExerciseIds(uniqueExerciseIds)
      : <Exercise>[];

  return compute(
    _enrichSessionsIsolate,
    _EnrichInput(sessions, allSessionExercises, allSets, exerciseList),
  );
}

final enrichedRecentSessionsProvider =
    FutureProvider<List<EnrichedSession>>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final sessions = await sessionDao.getRecent(3);
  return _enrichSessionsBatch(sessions, sessionDao, exerciseDao);
});

/// All completed sessions enriched (for Log bottom sheet).
final enrichedAllSessionsProvider =
    FutureProvider<List<EnrichedSession>>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final sessions = await sessionDao.getAll();
  final finished = sessions.where((s) => s.finishedAt != null).toList();
  return _enrichSessionsBatch(finished, sessionDao, exerciseDao);
});

// ── Muscle recovery ───────────────────────────

final muscleRecoveryProvider = FutureProvider<List<MuscleStateInfo>>((ref) {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  return MuscleRecoveryService(sessionDao, exerciseDao).getAllMuscleStates();
});

/// Weighted working sets per muscle group this week (Monday-anchored) —
/// primary movers count 1.0 per set, secondary muscles 0.5, mirroring the
/// recovery dose model. Powers the per-muscle weekly volume line in the
/// muscle detail sheet (evidence-based hypertrophy guideline: ~10–20
/// weekly sets per muscle).
final weeklySetsPerMuscleProvider =
    FutureProvider<Map<String, double>>((ref) {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final weekStart = _startOfWeek(DateTime.now());
  return MuscleRecoveryService(sessionDao, exerciseDao).getMuscleDoseTotals(
    from: weekStart,
    to: weekStart.add(const Duration(days: 7)),
  );
});

// ── Consecutive rest days ─────────────────────

/// Number of full calendar days since the last completed workout session.
/// Returns 0 if the user trained today, or if there are no sessions yet.
final consecutiveRestDaysProvider = FutureProvider<int>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final days = await sessionDao.getDistinctSessionDatesDescending(limit: 1);
  if (days.isEmpty) return 0;
  final lastWorkout =
      DateTime(days.first.year, days.first.month, days.first.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Round hours/24 instead of using inDays so a DST transition (a 23h or
  // 25h local day) still counts as one calendar day apart.
  final diff = (today.difference(lastWorkout).inHours / 24).round();
  return diff > 0 ? diff : 0;
});

// ── Home-screen widget sync ──────────────────
//
// A pure side-effect provider. Reading it once at app boot wires up
// listens that mirror `streakProvider` + `muscleRecoveryProvider` into
// the `home_widget` shared storage so the always-on Android AppWidget
// (and the planned iOS WidgetKit widget) reflects the latest state.
//
// Why a provider and not a top-level service: this scopes the listens
// to the ProviderContainer's lifetime, so hot-reload and integration
// tests behave cleanly. The empty `void` return is intentional — call
// sites just need to `ref.read` it to activate the side-effects.
final widgetSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<int>>(streakProvider, (_, next) {
    final days = next.valueOrNull;
    if (days != null) {
      WidgetSyncService.updateStreak(days);
    }
  });

  ref.listen<AsyncValue<List<MuscleStateInfo>>>(muscleRecoveryProvider,
      (_, next) {
    final states = next.valueOrNull;
    if (states == null) return;
    // Pick the highest-priority under-trained muscle group as "next focus".
    // Falls back to the most-recovered if everything is fresh.
    final underTrained = states
        .where((s) => s.state == MuscleState.undertrained)
        .map((s) => s.muscleGroup)
        .where((g) => g != 'Cardio')
        .toList();
    final focus = underTrained.isNotEmpty
        ? underTrained.first
        : states
            .firstWhere(
              (s) => s.state == MuscleState.recovered,
              orElse: () => const MuscleStateInfo(
                muscleGroup: '',
                state: MuscleState.undertrained,
              ),
            )
            .muscleGroup;
    WidgetSyncService.updateNextFocus(
      muscleGroup: focus.isEmpty ? null : focus,
      cta: focus.isEmpty ? 'Tap to open MyGymBro' : 'Open the app to start',
    );
  });
});

// ── Streak count ─────────────────────────────

/// Default gap allowance when the user has no active schedule: one rest day
/// between workouts keeps the streak alive (every-other-day training).
const int _kDefaultStreakGapDays = 1;

/// Upper bound on the gap allowance so a rest-heavy schedule can't make the
/// streak effectively unbreakable.
const int _kMaxStreakGapDays = 3;

/// How many consecutive workout-free calendar days the streak tolerates.
///
/// Schedule-aware: with an active schedule the allowance is the longest run
/// of consecutive rest days in its cycle (checked cyclically, so a cycle
/// ending and starting with rest days counts as one run). Without a schedule
/// — or with a degenerate all-rest schedule — falls back to
/// [_kDefaultStreakGapDays].
int _streakGapAllowance(List<ScheduleDay>? scheduleDays) {
  final days = scheduleDays;
  if (days == null || days.isEmpty) return _kDefaultStreakGapDays;
  if (days.every(_isRestScheduleDay)) return _kDefaultStreakGapDays;

  // Longest cyclic run of consecutive rest days: doubling the list lets a
  // run that wraps around the cycle boundary be counted in one pass.
  var run = 0;
  var maxRun = 0;
  for (final d in [...days, ...days]) {
    if (_isRestScheduleDay(d)) {
      run++;
      if (run > maxRun) maxRun = run;
    } else {
      run = 0;
    }
  }
  return maxRun.clamp(0, days.length).clamp(0, _kMaxStreakGapDays);
}

/// Number of workout days in the current unbroken training chain.
///
/// Unlike a naive consecutive-calendar-day streak, scheduled rest days do
/// not break the chain: a gap between two workout days (or between the last
/// workout and today) is tolerated up to the schedule-derived allowance from
/// [_streakGapAllowance]. The streak counts *training days*, so a Mon/Wed/Fri
/// lifter who never misses a session builds one workout per training day —
/// not a streak that resets to 1 every Tuesday.
final streakProvider = FutureProvider<int>((ref) async {
  // Auto-invalidate at next local midnight so the streak rolls over even
  // when the app stays foregrounded across the day boundary. Re-runs of
  // this provider reschedule the timer.
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final midnightTimer =
      Timer(nextMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(midnightTimer.cancel);

  final sessionDao = ref.watch(sessionDaoProvider);
  // One SQL round-trip: distinct local calendar days (newest first) with at
  // least one completed session. Walking the result list in Dart is
  // O(streak length).
  final days = await sessionDao.getDistinctSessionDatesDescending();
  if (days.isEmpty) return 0;

  // Gap allowance from the active schedule (reactive: streak recomputes
  // when the schedule or its days change).
  final active = await ref.watch(activeScheduleProvider.future);
  final scheduleDays = active == null
      ? null
      : await ref.watch(scheduleDaysProvider(active.localId).future);
  final allowedGap = _streakGapAllowance(scheduleDays);

  // Calendar-day difference at local midnight; round hours/24 so a DST
  // transition (23h/25h day) still counts as one calendar day.
  int dayDiff(DateTime a, DateTime b) =>
      (DateTime(a.year, a.month, a.day)
              .difference(DateTime(b.year, b.month, b.day))
              .inHours /
          24)
          .round();

  // Streak is dead when the workout-free run since the last session already
  // exceeds the allowance. (Today itself never counts against the user —
  // they may simply not have trained *yet*.)
  final today = DateTime(now.year, now.month, now.day);
  final restRunSinceLast = dayDiff(today, days.first) - 1;
  if (restRunSinceLast > allowedGap) return 0;

  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    final restDaysBetween = dayDiff(days[i - 1], days[i]) - 1;
    if (restDaysBetween < 0) continue; // duplicate calendar day
    if (restDaysBetween <= allowedGap) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
});

// ── Weekly streak ────────────────────────────

/// Weekly-streak state: how many consecutive weeks the user has hit their
/// weekly workout target.
class WeeklyStreakData {
  const WeeklyStreakData({
    this.weeks = 0,
    this.target = _kDefaultWeeklyTarget,
    this.thisWeekDays = 0,
  });

  /// Consecutive weeks meeting the target. The current week counts as soon
  /// as it hits the target; an in-progress week never breaks the chain.
  final int weeks;

  /// Workout days per week required to keep the streak.
  final int target;

  /// Distinct workout days so far this week.
  final int thisWeekDays;
}

/// Weekly target for users without an active schedule — three sessions a
/// week is the common baseline programme.
const int _kDefaultWeeklyTarget = 3;

/// Consecutive weeks (Monday-anchored, same window as every other weekly
/// metric) with at least `target` distinct workout days. The target comes
/// from the active schedule's training-day density scaled to a 7-day week,
/// falling back to [_kDefaultWeeklyTarget]. The industry-standard streak
/// (Apple Fitness, Hevy) — tolerant of rest days by construction.
final weeklyStreakProvider = FutureProvider<WeeklyStreakData>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);

  var target = _kDefaultWeeklyTarget;
  final active = await ref.watch(activeScheduleProvider.future);
  if (active != null) {
    final schedDays =
        await ref.watch(scheduleDaysProvider(active.localId).future);
    if (schedDays.isNotEmpty) {
      final trainingDays =
          schedDays.where((d) => !_isRestScheduleDay(d)).length;
      if (trainingDays > 0) {
        target = ((trainingDays / schedDays.length) * 7).round().clamp(1, 7);
      }
    }
  }

  final days = await sessionDao.getDistinctSessionDatesDescending();
  if (days.isEmpty) return WeeklyStreakData(target: target);

  // Distinct workout days per week, keyed by the week's Monday.
  final daysPerWeek = <int, int>{};
  for (final d in days) {
    final key = _startOfWeek(d).millisecondsSinceEpoch;
    daysPerWeek[key] = (daysPerWeek[key] ?? 0) + 1;
  }

  final thisWeekStart = _startOfWeek(DateTime.now());
  final thisWeekDays =
      daysPerWeek[thisWeekStart.millisecondsSinceEpoch] ?? 0;

  var weeks = 0;
  if (thisWeekDays >= target) weeks++;

  var cursor = thisWeekStart;
  while (true) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    if ((daysPerWeek[cursor.millisecondsSinceEpoch] ?? 0) >= target) {
      weeks++;
    } else {
      break;
    }
  }

  return WeeklyStreakData(
    weeks: weeks,
    target: target,
    thisWeekDays: thisWeekDays,
  );
});

// ── Records count ────────────────────────────

class RecordsData {
  const RecordsData({this.count = 0, this.trend});
  final int count;
  final int? trend;
}

final recordsProvider = FutureProvider<RecordsData>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);

  // 1 query: all finished sessions
  final sessions = await sessionDao.getAll();
  final finished = sessions.where((s) => s.finishedAt != null).toList();
  if (finished.isEmpty) return const RecordsData();

  // 1 query: all session-exercises for those sessions
  final sessionIds = finished.map((s) => s.localId).toList();
  final allExercises =
      await sessionDao.getSessionExercisesForSessions(sessionIds);
  if (allExercises.isEmpty) return const RecordsData();

  // 1 query: all sets for those session-exercises
  final exerciseIds = allExercises.map((e) => e.localId).toList();
  final allSets = await sessionDao.getSetsForSessionExercises(exerciseIds);

  // Index: sessionExerciseId → exerciseId
  final exerciseIdBySEId = {
    for (final se in allExercises) se.localId: se.exerciseId,
  };

  // In-memory join: track personal bests per exercise (max volume = weight × reps)
  final personalBests = <String, double>{};
  for (final s in allSets) {
    if (s.isCompleted && s.weight != null && s.reps != null) {
      final vol = s.weight! * s.reps!;
      final exerciseId = exerciseIdBySEId[s.sessionExerciseId];
      if (exerciseId == null) continue;
      final prev = personalBests[exerciseId];
      if (prev == null || vol > prev) {
        personalBests[exerciseId] = vol;
      }
    }
  }

  return RecordsData(count: personalBests.length);
});

// ── Calories estimate ────────────────────────

/// Total calories burned across *this* week's completed sessions (Monday
/// 00:00 through the following Monday 00:00, exclusive — the same window as
/// [weeklyStatsProvider]). Uses the user's real body weight when set,
/// falling back to [_kFallbackBodyWeightKg].
final weeklyCaloriesProvider = FutureProvider<int>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final profile = await ref.watch(userProfileProvider.future);
  final bodyWeight = profile?.bodyWeightKg ?? _kFallbackBodyWeightKg;

  final weekStart = _startOfWeek(DateTime.now());
  final weekEnd = weekStart.add(const Duration(days: 7));

  final thisWeek = await sessionDao.getInRange(weekStart, weekEnd);
  final calories = await _sessionCaloriesBatch(
    sessionDao,
    exerciseDao,
    thisWeek,
    bodyWeightKg: bodyWeight,
    gender: profile?.gender,
  );

  var total = 0;
  for (final c in calories.values) {
    total += c;
  }
  return total;
});
