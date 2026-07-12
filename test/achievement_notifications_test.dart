import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

ScheduleDay _day({String? label, bool isRestDay = false}) => ScheduleDay(
      localId: 1,
      syncStatus: 'pending',
      scheduleId: 1,
      dayIndex: 0,
      label: label,
      isRestDay: isRestDay,
    );

void main() {
  test('rest days are detected by flag or label in any app language', () {
    expect(isRestScheduleDay(_day(isRestDay: true)), isTrue);
    expect(isRestScheduleDay(_day(label: 'Rest & Recovery')), isTrue);
    expect(isRestScheduleDay(_day(label: 'Ruhetag')), isTrue);
    expect(isRestScheduleDay(_day(label: 'Día de descanso')), isTrue);
    expect(isRestScheduleDay(_day(label: 'Jour de repos')), isTrue);
    expect(isRestScheduleDay(_day(label: 'Leg Day')), isFalse);
    expect(isRestScheduleDay(_day()), isFalse);
  });

  test('volume milestones fire exactly when a session crosses them', () {
    expect(
      crossedVolumeMilestone(total: 100500, sessionVolume: 1000),
      100000,
    );
    // Already past the mark before this session → quiet.
    expect(crossedVolumeMilestone(total: 101500, sessionVolume: 1000), isNull);
    // Crossing two thresholds at once reports the biggest.
    expect(crossedVolumeMilestone(total: 26000, sessionVolume: 20000), 25000);
    // Below the first threshold → nothing.
    expect(crossedVolumeMilestone(total: 9000, sessionVolume: 9000), isNull);
  });

  test('session-count milestones', () {
    expect(isSessionMilestone(10), isTrue);
    expect(isSessionMilestone(11), isFalse);
    expect(isSessionMilestone(100), isTrue);
    expect(isSessionMilestone(1000), isTrue);
  });

  test('streak risk arms only on the last allowed rest day', () {
    // Trained today (restRun -1) → never at risk.
    expect(
      const StreakRisk(streak: 5, restRun: -1, allowedGap: 0).atRiskToday,
      isFalse,
    );
    // Daily streak: first day without a session is the last chance.
    expect(
      const StreakRisk(streak: 5, restRun: 0, allowedGap: 0).atRiskToday,
      isTrue,
    );
    // Schedule allows one rest day: warning waits for the second one.
    expect(
      const StreakRisk(streak: 5, restRun: 0, allowedGap: 1).atRiskToday,
      isFalse,
    );
    expect(
      const StreakRisk(streak: 5, restRun: 1, allowedGap: 1).atRiskToday,
      isTrue,
    );
    // Single-day "streaks" aren't worth a warning.
    expect(
      const StreakRisk(streak: 1, restRun: 0, allowedGap: 0).atRiskToday,
      isFalse,
    );
  });

  test('weekly recap renders the delta only when last week exists', () {
    expect(
      weeklyRecapBodyForTone(
        NotificationTone.balanced,
        sessions: 4,
        volume: '12400 kg',
        deltaPct: 14,
      ),
      '4 sessions · 12400 kg (+14% vs last week).',
    );
    expect(
      weeklyRecapBodyForTone(
        NotificationTone.balanced,
        sessions: 1,
        volume: '900 kg',
      ),
      '1 session · 900 kg this week.',
    );
  });

  test('kudos PR suffix pluralizes', () {
    expect(
      kudosPrSuffixForTone(NotificationTone.balanced, 1),
      ' Including 1 new PR 🏆',
    );
    expect(
      kudosPrSuffixForTone(NotificationTone.balanced, 3),
      ' Including 3 new PRs 🏆',
    );
  });
}
