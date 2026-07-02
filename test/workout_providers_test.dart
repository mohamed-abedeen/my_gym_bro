import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

class MockSessionDao extends Mock implements SessionDao {}

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

  setUpAll(() {
    registerFallbackValue(DateTime(2020));
  });

  setUp(() {
    sessionDao = MockSessionDao();
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
  });
}
