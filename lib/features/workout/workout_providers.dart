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

/// Determines which training day page to show based on completed sessions.
///
/// Logic: nextIndex = completedSessions % trainingDays.length
/// Returns 0 if no sessions exist yet (start from the first day).
final nextTrainingDayIndexProvider =
    FutureProvider.family<int, int>((ref, scheduleId) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  final scheduleDao = ref.watch(scheduleDaoProvider);

  final days = await scheduleDao.getDays(scheduleId);
  final trainingDays = days
      .where((d) =>
          !d.isRestDay &&
          !(d.label?.toLowerCase().contains('rest') ?? false))
      .toList();
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

  final trainingDays = allDays
      .where((d) =>
          !d.isRestDay &&
          !(d.label?.toLowerCase().contains('rest') ?? false))
      .toList();
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
    final isRest = day.isRestDay ||
        (day.label?.toLowerCase().contains('rest') ?? false);
    if (isRest) {
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

    // Recovering → calculate remaining hours
    if (state.lastTrainedAt != null && state.recoveryPercent != null) {
      final recoveryH = MuscleRecoveryService.recoveryHoursFor(group);
      final hoursSince =
          DateTime.now().difference(state.lastTrainedAt!).inMinutes / 60.0;
      final remaining = (recoveryH - hoursSince).ceil();

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
    final mondayMidnight = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
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
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekStart = DateTime(monday.year, monday.month, monday.day);
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

  // Avg strength = total volume / total sets (simplified as volume per session)
  final avgStr = thisWeek.isNotEmpty ? totalVol / thisWeek.length : 0.0;
  final lastAvgStr = lastWeek.isNotEmpty ? lastVol / lastWeek.length : 0.0;

  return WeeklyStats(
    totalVolume: totalVol,
    totalDurationSeconds: totalDur,
    avgStrength: avgStr,
    volumeTrend: lastVol > 0 ? ((totalVol - lastVol) / lastVol * 100) : null,
    durationTrend: lastDur > 0 ? ((totalDur - lastDur) / lastDur * 100) : null,
    strengthTrend:
        lastAvgStr > 0 ? (avgStr - lastAvgStr).roundToDouble() : null,
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
        if (s.weight != null && s.reps != null) {
          vol += s.weight! * s.reps!;
          completedSets++;
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
  final diff = today.difference(lastWorkout).inDays;
  return diff > 0 ? diff : 0;
});

// ── Streak count ─────────────────────────────

final streakProvider = FutureProvider<int>((ref) async {
  final sessionDao = ref.watch(sessionDaoProvider);
  // One SQL round-trip: distinct local calendar days (newest first) with at
  // least one completed session. Replaces the previous 365 sequential
  // hasSessionOnDate() calls that blocked the UI thread every Workout-tab
  // open. Walking the result list in Dart is O(streak length).
  final days = await sessionDao.getDistinctSessionDatesDescending();
  if (days.isEmpty) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daySet = <int>{
    for (final d in days)
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
  };

  var streak = 0;
  for (var i = 0; i <= days.length; i++) {
    final day = today.subtract(Duration(days: i));
    if (daySet.contains(day.millisecondsSinceEpoch)) {
      streak++;
    } else if (i > 0) {
      // Allow today to not have a session yet.
      break;
    }
  }
  return streak;
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
    if (s.weight != null && s.reps != null) {
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

final weeklyCaloriesProvider = FutureProvider<int>((ref) async {
  final stats = await ref.watch(weeklyStatsProvider.future);
  // Rough estimate: ~6 cal per minute of strength training
  final minutes = stats.totalDurationSeconds / 60;
  return (minutes * 6).round();
});
