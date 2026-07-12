import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';

void main() {
  test('streak milestones fire on start, early momentum, then every 25', () {
    // Day 1 is not a streak; day 2 starts one.
    expect(isStreakMilestone(0), isFalse);
    expect(isStreakMilestone(1), isFalse);
    expect(isStreakMilestone(2), isTrue);
    // Early momentum milestones.
    for (final d in [3, 5, 7, 10, 14, 21, 30]) {
      expect(isStreakMilestone(d), isTrue, reason: 'day $d');
    }
    // In-between days stay quiet.
    for (final d in [4, 6, 8, 13, 22, 29, 31, 40, 49]) {
      expect(isStreakMilestone(d), isFalse, reason: 'day $d');
    }
    // Every 25 past 30.
    for (final d in [50, 75, 100, 125]) {
      expect(isStreakMilestone(d), isTrue, reason: 'day $d');
    }
  });

  test('day 2 reads as a streak start, later days as a count', () {
    expect(
      streakTitleForTone(NotificationTone.balanced, 2),
      'Streak started 🔥',
    );
    expect(
      streakTitleForTone(NotificationTone.balanced, 7),
      'Streak Alert: 7 days 🔥',
    );
    // Kudos title personalizes when a name exists, degrades when not.
    expect(
      workoutKudosTitleForTone(NotificationTone.balanced, 'Mohammed'),
      'Kudos to you, Mohammed 👍',
    );
    expect(
      workoutKudosTitleForTone(NotificationTone.balanced, null),
      'Kudos to you 👍',
    );
  });
}
