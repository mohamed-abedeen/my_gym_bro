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

void main() {
  late MockSessionDao sessionDao;

  setUpAll(() {
    registerFallbackValue(DateTime(2020));
  });

  setUp(() {
    sessionDao = MockSessionDao();
  });

  /// Creates a container with the session DAO mocked and, optionally, the
  /// user profile stream overridden.
  ProviderContainer makeContainer({UserProfile? profile}) {
    final container = ProviderContainer(
      overrides: [
        sessionDaoProvider.overrideWithValue(sessionDao),
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

    test('stops at the first gap', () async {
      when(() => sessionDao.getDistinctSessionDatesDescending(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            today,
            // Yesterday missing → streak ends after today.
            DateTime(today.year, today.month, today.day - 2),
            DateTime(today.year, today.month, today.day - 3),
          ]);

      final container = makeContainer();
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
    // Anchor inside last week's range so getInRange would have returned them.
    final lastWeekDay = DateTime(today.year, today.month, today.day - 8);

    test('sums last week calories using the user body weight', () async {
      when(() => sessionDao.getInRange(any(), any())).thenAnswer(
        (_) async => [
          _session(id: 1, startedAt: lastWeekDay),
          _session(id: 2, startedAt: lastWeekDay, durationSeconds: 1800),
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
        (_) async => [_session(id: 1, startedAt: lastWeekDay)],
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
          _session(id: 1, startedAt: lastWeekDay),
          _session(id: 2, startedAt: lastWeekDay, finished: false),
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
