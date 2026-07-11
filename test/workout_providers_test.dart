import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/features/workout/calorie_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

class MockSessionDao extends Mock implements SessionDao {}

class MockExerciseDao extends Mock implements ExerciseDao {}

/// Builds a finished [Session] for tests. Only the fields the providers
/// under test actually read are meaningful; the rest are filler.
Session _session({
  required int id,
  required DateTime startedAt,
  int durationSeconds = 3600,
  bool finished = true,
}) {
  return Session(
    localId: id,
    syncStatus: 'synced',
    startedAt: startedAt,
    finishedAt: finished ? startedAt.add(const Duration(hours: 1)) : null,
    durationSeconds: durationSeconds,
  );
}

UserProfile _profile({double? bodyWeightKg}) {
  return UserProfile(
    localId: 1,
    syncStatus: 'synced',
    bodyWeightKg: bodyWeightKg,
    weightUnit: 'kg',
    preferredLanguage: 'en',
    subscriptionStatus: 'free',
    defaultRestSeconds: 90,
    notificationTone: 'balanced',
  );
}

Schedule _schedule({int id = 1}) {
  return Schedule(
    localId: id,
    syncStatus: 'synced',
    name: 'Test plan',
    isActive: true,
  );
}

SessionExercise _sessionExercise({
  required int id,
  required int sessionId,
  required String exerciseId,
}) {
  return SessionExercise(
    localId: id,
    syncStatus: 'synced',
    sessionId: sessionId,
    exerciseId: exerciseId,
    orderIndex: 0,
  );
}

WorkoutSet _set({
  required int sessionExerciseId,
  double? weight,
  int? reps,
  bool isWarmup = false,
  bool isCompleted = true,
}) {
  return WorkoutSet(
    localId: 0,
    syncStatus: 'synced',
    sessionExerciseId: sessionExerciseId,
    setIndex: 0,
    weight: weight,
    reps: reps,
    isWarmup: isWarmup,
    isDropset: false,
    isFailure: false,
    isCompleted: isCompleted,
  );
}

/// Builds a schedule-day cycle from a pattern where `true` = rest day.
List<ScheduleDay> _scheduleDays(List<bool> restPattern, {int scheduleId = 1}) {
  return [
    for (var i = 0; i < restPattern.length; i++)
      ScheduleDay(
        localId: i + 1,
        syncStatus: 'synced',
        scheduleId: scheduleId,
        dayIndex: i,
        label: restPattern[i] ? 'Rest' : 'Day ${i + 1}',
        isRestDay: restPattern[i],
      ),
  ];
}

void main() {
  late MockSessionDao sessionDao;
  late MockExerciseDao exerciseDao;

  setUpAll(() {
    registerFallbackValue(DateTime(2020));
  });

  setUp(() {
    sessionDao = MockSessionDao();
    exerciseDao = MockExerciseDao();
    // Default: sessions carry no set-level data, so calorie estimates use
    // the flat fallback model. Tests that exercise the MET model re-stub.
    when(() => sessionDao.getSessionExercisesForSessions(any()))
        .thenAnswer((_) async => []);
    when(() => sessionDao.getSetsForSessionExercises(any()))
        .thenAnswer((_) async => []);
    when(() => exerciseDao.findByExerciseIds(any()))
        .thenAnswer((_) async => []);
  });

  /// Creates a container with the session DAO mocked and, optionally, the
  /// user profile stream and active schedule (with its rest-day cycle)
  /// overridden. With no [scheduleRestPattern] there is no active schedule.
  ProviderContainer makeContainer({
    UserProfile? profile,
    List<bool>? scheduleRestPattern,
  }) {
    final schedule = scheduleRestPattern != null ? _schedule() : null;
    final container = ProviderContainer(
      overrides: [
        sessionDaoProvider.overrideWithValue(sessionDao),
        exerciseDaoProvider.overrideWithValue(exerciseDao),
        activeScheduleProvider.overrideWith((ref) => Stream.value(schedule)),
        if (scheduleRestPattern != null)
          scheduleDaysProvider(schedule!.localId).overrideWith(
            (ref) => Stream.value(_scheduleDays(scheduleRestPattern)),
          ),
        if (profile != null)
          userProfileProvider.overrideWith((ref) => Stream.value(profile)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // Local midnight today, the same anchor the providers use.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // ── streakProvider ──────────────────────────────────────────────────────

  group('streakProvider', () {
    test('counts consecutive daily sessions', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            DateTime(today.year, today.month, today.day - 1),
            DateTime(today.year, today.month, today.day - 2),
          ]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 3);
    });

    test('tolerates single rest days without a schedule', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            // Yesterday missing — a one-day gap is within the default
            // allowance, so the chain continues.
            DateTime(today.year, today.month, today.day - 2),
            DateTime(today.year, today.month, today.day - 3),
          ]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 3);
    });

    test('breaks past the default one-day gap allowance', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            // Two full days missing → gap of 2 > default allowance of 1.
            DateTime(today.year, today.month, today.day - 3),
            DateTime(today.year, today.month, today.day - 4),
          ]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 1);
    });

    test('is dead when the current gap already exceeds the allowance',
        () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            // Last workout 3 days ago → 2 workout-free days behind us.
            DateTime(today.year, today.month, today.day - 3),
            DateTime(today.year, today.month, today.day - 4),
          ]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 0);
    });

    test('schedule with two consecutive rest days widens the allowance',
        () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            // Two rest days between workouts — allowed by this schedule.
            DateTime(today.year, today.month, today.day - 3),
            DateTime(today.year, today.month, today.day - 4),
          ]);

      final container = makeContainer(
        // Train / train / rest / rest / train cycle.
        scheduleRestPattern: [false, false, true, true, false],
      );
      expect(await container.read(streakProvider.future), 3);
    });

    test('daily schedule with no rest days breaks on any missed day',
        () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            // One missed day, but the schedule trains every day.
            DateTime(today.year, today.month, today.day - 2),
          ]);

      final container = makeContainer(
        scheduleRestPattern: [false, false, false],
      );
      expect(await container.read(streakProvider.future), 1);
    });

    test('still counts when today has no session yet', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            DateTime(today.year, today.month, today.day - 1),
            DateTime(today.year, today.month, today.day - 2),
          ]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 2);
    });

    test('deduplicates double sessions on the same day', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            today,
            DateTime(today.year, today.month, today.day - 1),
          ]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 2);
    });

    test('returns 0 with no sessions', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => <DateTime>[]);

      final container = makeContainer();
      expect(await container.read(streakProvider.future), 0);
    });
  });

  // ── consecutiveRestDaysProvider ─────────────────────────────────────────

  group('consecutiveRestDaysProvider', () {
    test('returns 0 when the last workout was today', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [today]);

      final container = makeContainer();
      expect(await container.read(consecutiveRestDaysProvider.future), 0);
    });

    test('counts full days since the last workout', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            DateTime(today.year, today.month, today.day - 3),
          ]);

      final container = makeContainer();
      expect(await container.read(consecutiveRestDaysProvider.future), 3);
    });

    test('returns 0 with no sessions', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => <DateTime>[]);

      final container = makeContainer();
      expect(await container.read(consecutiveRestDaysProvider.future), 0);
    });
  });

  // ── weeklyCaloriesProvider ──────────────────────────────────────────────

  group('weeklyCaloriesProvider', () {
    // Anchor inside this week's range so getInRange would have returned them.
    final thisWeekDay = today;

    test('sums this week calories using the user body weight', () async {
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [
          _session(id: 1, startedAt: thisWeekDay),
          _session(id: 2, startedAt: thisWeekDay, durationSeconds: 1800),
        ],
      );

      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      final result = await container.read(weeklyCaloriesProvider.future);

      // 5 MET * 80kg * (1h + 0.5h) = 600 kcal.
      final expected = caloriesForSession(80, 3600) +
          caloriesForSession(80, 1800);
      expect(result, expected);
      expect(result, 600);
    });

    test('falls back to default body weight when profile weight is null',
        () async {
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [_session(id: 1, startedAt: thisWeekDay)],
      );

      final container = makeContainer(profile: _profile());
      final result = await container.read(weeklyCaloriesProvider.future);

      // Fallback 70kg: 5 MET * 70 * 1h = 350 kcal.
      expect(result, caloriesForSession(70, 3600));
      expect(result, 350);
    });

    test('ignores unfinished sessions', () async {
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [
          _session(id: 1, startedAt: thisWeekDay),
          _session(id: 2, startedAt: thisWeekDay, finished: false),
        ],
      );

      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      final result = await container.read(weeklyCaloriesProvider.future);

      expect(result, caloriesForSession(80, 3600));
    });

    test('returns 0 with no sessions last week', () async {
      when(() => sessionDao.getInRange(any(), any()))
          .thenAnswer((_) async => <Session>[]);

      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      expect(await container.read(weeklyCaloriesProvider.future), 0);
    });

    test('uses the MET model when set-level data exists', () async {
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [_session(id: 1, startedAt: thisWeekDay)],
      );
      when(() => sessionDao.getSessionExercisesForSessions(any()))
          .thenAnswer((_) async => [
                _sessionExercise(id: 10, sessionId: 1, exerciseId: 'squat'),
              ]);
      // 10 completed squat sets → 450s of large-muscle work.
      when(() => sessionDao.getSetsForSessionExercises(any())).thenAnswer(
        (_) async => [
          for (var i = 0; i < 10; i++)
            _set(sessionExerciseId: 10, weight: 100, reps: 5),
        ],
      );
      when(() => exerciseDao.findByExerciseIds(any())).thenAnswer(
        (_) async => [
          const Exercise(
            localId: 1,
            syncStatus: 'synced',
            exerciseId: 'squat',
            name: 'Barbell Squat',
            muscleGroup: 'Quads',
            isCustom: false,
            usageCount: 0,
            isFavorite: false,
          ),
        ],
      );

      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      final result = await container.read(weeklyCaloriesProvider.future);

      // 450s work @ MET 6 + 3150s rest @ MET 2 for an 80kg user.
      final expected = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
        efforts: const [ExerciseEffort(met: 6, activeSeconds: 450)],
      );
      expect(result, expected);
      // Sanity: the dense-work model bills less than flat 5-MET wall-clock.
      expect(result, lessThan(caloriesForSession(80, 3600)));
    });
  });

  // ── weeklyStreakProvider ────────────────────────────────────────────────

  group('weeklyStreakProvider', () {
    // Monday of the current week — the same anchor the provider uses.
    final thisMonday =
        DateTime(today.year, today.month, today.day - (today.weekday - 1));
    DateTime weekDay(int weeksAgo, int offset) => DateTime(
        thisMonday.year, thisMonday.month, thisMonday.day - weeksAgo * 7 + offset);

    test('counts consecutive weeks hitting the default 3-day target',
        () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            // Last week: Mon/Wed/Fri. Two weeks ago: Mon/Tue/Thu.
            weekDay(1, 0), weekDay(1, 2), weekDay(1, 4),
            weekDay(2, 0), weekDay(2, 1), weekDay(2, 3),
          ]);

      final container = makeContainer();
      final data = await container.read(weeklyStreakProvider.future);
      expect(data.target, 3);
      expect(data.weeks, 2);
      // This week has no sessions yet — pending, not broken.
      expect(data.thisWeekDays, 0);
    });

    test('current week joins the streak once the target is met', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            weekDay(0, 0), weekDay(0, 1), weekDay(0, 2),
            weekDay(1, 0), weekDay(1, 2), weekDay(1, 4),
          ]);

      final container = makeContainer();
      final data = await container.read(weeklyStreakProvider.future);
      expect(data.weeks, 2);
      expect(data.thisWeekDays, 3);
    });

    test('a missed week breaks the chain', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            // Last week hit the target, two weeks ago only 1 day,
            // three weeks ago hit it again — chain stops at the gap.
            weekDay(1, 0), weekDay(1, 2), weekDay(1, 4),
            weekDay(2, 0),
            weekDay(3, 0), weekDay(3, 2), weekDay(3, 4),
          ]);

      final container = makeContainer();
      final data = await container.read(weeklyStreakProvider.future);
      expect(data.weeks, 1);
    });

    test('derives the target from the active schedule cycle', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            // Last week: 4 workout days — meets a 4-day target.
            weekDay(1, 0), weekDay(1, 1), weekDay(1, 3), weekDay(1, 4),
          ]);

      final container = makeContainer(
        // 4 training days + 3 rest days in a 7-day cycle → target 4.
        scheduleRestPattern: [
          false, false, true, false, false, true, true,
        ],
      );
      final data = await container.read(weeklyStreakProvider.future);
      expect(data.target, 4);
      expect(data.weeks, 1);
    });

    test('returns zero streak with no sessions', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => <DateTime>[]);

      final container = makeContainer();
      final data = await container.read(weeklyStreakProvider.future);
      expect(data.weeks, 0);
      expect(data.target, 3);
    });
  });

  // ── epleyOneRepMax + weeklyStatsProvider strength ───────────────────────

  group('epleyOneRepMax', () {
    test('single rep is its own 1RM', () {
      expect(epleyOneRepMax(100, 1), 100);
    });

    test('follows the Epley formula for multi-rep sets', () {
      // 100kg × 10 reps → 100 × (1 + 10/30) ≈ 133.3
      expect(epleyOneRepMax(100, 10), closeTo(133.33, 0.01));
    });

    test('heavier low-rep set beats lighter high-rep junk volume', () {
      // 140×3 (e1RM 154) should out-rank 80×15 (e1RM 120): strength went
      // up even though per-set volume went down.
      expect(
        epleyOneRepMax(140, 3),
        greaterThan(epleyOneRepMax(80, 15)),
      );
    });
  });

  group('weeklyStatsProvider strength (e1RM)', () {
    test('averages the best e1RM per exercise, skipping warmups', () async {
      final session = _session(id: 1, startedAt: today);
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (invocation) async {
          // Only this week has data; last week's range returns empty.
          final from = invocation.positionalArguments[0] as DateTime;
          return from.isBefore(today.subtract(const Duration(days: 6)))
              ? <Session>[]
              : [session];
        },
      );
      when(() => sessionDao.getSessionExercisesForSessions(any()))
          .thenAnswer((_) async => [
                _sessionExercise(id: 10, sessionId: 1, exerciseId: 'bench'),
                _sessionExercise(id: 11, sessionId: 1, exerciseId: 'squat'),
              ]);
      when(() => sessionDao.getSetsForSessionExercises(any()))
          .thenAnswer((_) async => [
                // Warmup — must be ignored even though it computes high.
                _set(sessionExerciseId: 10, weight: 200, reps: 10,
                    isWarmup: true),
                // Bench best: 100×5 → 116.67
                _set(sessionExerciseId: 10, weight: 100, reps: 5),
                _set(sessionExerciseId: 10, weight: 90, reps: 8),
                // Squat best: 140×3 → 154
                _set(sessionExerciseId: 11, weight: 140, reps: 3),
                // Incomplete set — ignored.
                _set(sessionExerciseId: 11, weight: 180, reps: 5,
                    isCompleted: false),
              ]);

      final container = makeContainer();
      final stats = await container.read(weeklyStatsProvider.future);

      final expected =
          (epleyOneRepMax(100, 5) + epleyOneRepMax(140, 3)) / 2;
      expect(stats.avgStrength, closeTo(expected, 0.01));
      // Last week empty → no strength trend.
      expect(stats.strengthTrend, isNull);
    });

    test('strength is 0 with no completed weighted sets', () async {
      when(() => sessionDao.getInRange(any(), any()))
          .thenAnswer((_) async => [_session(id: 1, startedAt: today)]);
      when(() => sessionDao.getSessionExercisesForSessions(any()))
          .thenAnswer((_) async => [
                _sessionExercise(id: 10, sessionId: 1, exerciseId: 'run'),
              ]);
      when(() => sessionDao.getSetsForSessionExercises(any()))
          .thenAnswer((_) async => [
                // Cardio set: no weight/reps.
                _set(sessionExerciseId: 10),
              ]);

      final container = makeContainer();
      final stats = await container.read(weeklyStatsProvider.future);
      expect(stats.avgStrength, 0);
    });
  });

  group('LifetimeChartData', () {
    MonthlyTraining month(int m, double volume) => MonthlyTraining(
          month: DateTime(2026, m),
          reps: 0,
          volume: volume,
        );

    test('totalVolume is the last cumulative point', () {
      const data = LifetimeChartData(cumulativeVolume: [100, 250, 400]);
      expect(data.totalVolume, 400);
      expect(const LifetimeChartData().totalVolume, 0);
    });

    test('volumeIncreasePct compares first vs last charted month', () {
      final data = LifetimeChartData(
        monthly: [month(1, 1000), month(2, 2500), month(3, 4500)],
      );
      expect(data.volumeIncreasePct, 350);
    });

    test('volumeIncreasePct is null without two months or a zero start', () {
      expect(const LifetimeChartData().volumeIncreasePct, isNull);
      expect(
        LifetimeChartData(monthly: [month(1, 1000)]).volumeIncreasePct,
        isNull,
      );
      expect(
        LifetimeChartData(monthly: [month(1, 0), month(2, 500)])
            .volumeIncreasePct,
        isNull,
      );
    });
  });

  group('dayReportProvider', () {
    test('aggregates a day: top working weight, per-exercise cals + duration',
        () async {
      // Same session returned for both the selected day and last-week ranges.
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [_session(id: 1, startedAt: today)],
      );
      when(() => sessionDao.getSessionExercisesForSessions(any()))
          .thenAnswer((_) async => [
                _sessionExercise(id: 10, sessionId: 1, exerciseId: 'squat'),
              ]);
      // 3 completed working sets @ 100kg + one heavier warmup that must NOT
      // count toward the top working weight.
      when(() => sessionDao.getSetsForSessionExercises(any())).thenAnswer(
        (_) async => [
          _set(sessionExerciseId: 10, weight: 100, reps: 5),
          _set(sessionExerciseId: 10, weight: 100, reps: 5),
          _set(sessionExerciseId: 10, weight: 100, reps: 5),
          _set(sessionExerciseId: 10, weight: 200, reps: 1, isWarmup: true),
        ],
      );
      when(() => exerciseDao.findByExerciseIds(any())).thenAnswer(
        (_) async => [
          const Exercise(
            localId: 1,
            syncStatus: 'synced',
            exerciseId: 'squat',
            name: 'Barbell Squat',
            muscleGroup: 'Quads', // large muscle → MET 6.0
            isCustom: false,
            usageCount: 0,
            isFavorite: false,
          ),
        ],
      );

      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      final report = await container.read(dayReportProvider(today).future);

      expect(report.hasData, isTrue);
      expect(report.exercises, hasLength(1));
      final ex = report.exercises.single;
      expect(ex.name, 'Barbell Squat');
      // Warmup 200kg excluded; heaviest working set is 100kg.
      expect(ex.topWeightKg, 100);
      // 4 completed sets × 45s assumed each = 180s under load.
      expect(ex.durationSeconds, 180);
      // 6.0 MET × 80kg × 180/3600 h = 24 kcal.
      expect(ex.calories, 24);
      expect(report.totalCalories, 24);
      // Same data stubbed for last week → comparison equals this day.
      expect(ex.lastWeekTopWeightKg, 100);
    });

    test('caps assumed work time at the session duration', () async {
      // 4-minute session with 8 rapid-fire sets: 8 × 45s assumed = 360s of
      // "work", but the session only lasted 240s → scaled to 240s so the
      // report agrees with the weekly calorie stat.
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [_session(id: 1, startedAt: today, durationSeconds: 240)],
      );
      when(() => sessionDao.getSessionExercisesForSessions(any()))
          .thenAnswer((_) async => [
                _sessionExercise(id: 10, sessionId: 1, exerciseId: 'squat'),
              ]);
      when(() => sessionDao.getSetsForSessionExercises(any())).thenAnswer(
        (_) async => List.generate(
          8,
          (_) => _set(sessionExerciseId: 10, weight: 100, reps: 5),
        ),
      );
      when(() => exerciseDao.findByExerciseIds(any())).thenAnswer(
        (_) async => [
          const Exercise(
            localId: 1,
            syncStatus: 'synced',
            exerciseId: 'squat',
            name: 'Barbell Squat',
            muscleGroup: 'Quads', // large muscle → MET 6.0
            isCustom: false,
            usageCount: 0,
            isFavorite: false,
          ),
        ],
      );

      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      final report = await container.read(dayReportProvider(today).future);

      final ex = report.exercises.single;
      // 8 × 45s = 360s scaled by 240/360 → 240s under load, not 360.
      expect(ex.durationSeconds, 240);
      // 6.0 MET × 80kg × 240/3600 h = 32 kcal, not 48.
      expect(ex.calories, 32);
    });

    test('empty day has no exercises', () async {
      when(() => sessionDao.getInRange(any(), any()))
          .thenAnswer((_) async => []);
      final container = makeContainer(profile: _profile(bodyWeightKg: 80));
      final report = await container.read(dayReportProvider(today).future);
      expect(report.hasData, isFalse);
      expect(report.totalCalories, 0);
    });
  });
}
