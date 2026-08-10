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

  // Streak-at-risk arming is now a re-run of the streak walk with tomorrow
  // as the reference day — covered by the computeStreak tests in
  // workout_providers_test.dart.

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
