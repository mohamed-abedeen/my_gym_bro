import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Voice/tone used for all motivational notifications (rest complete,
/// recovery pings, streak nudges). Chosen once during onboarding and
/// adjustable from Settings.
enum NotificationTone {
  /// Gentle, permission-giving language. For users who find harsh
  /// language demotivating.
  supportive,

  /// Neutral, factual default. Safe for everyone.
  balanced,

  /// Direct, confident push. Default for most athletes.
  bold,

  /// All-caps, zero-excuses drill-sergeant energy. Opt-in only.
  savage,
}

extension NotificationToneX on NotificationTone {
  /// Stable wire value stored in SQLite and Supabase.
  String get wireValue {
    switch (this) {
      case NotificationTone.supportive:
        return 'supportive';
      case NotificationTone.balanced:
        return 'balanced';
      case NotificationTone.bold:
        return 'bold';
      case NotificationTone.savage:
        return 'savage';
    }
  }
}

/// Parse a stored string into a [NotificationTone], falling back to
/// [NotificationTone.balanced] for unknown or null values.
NotificationTone notificationToneFromString(String? raw) {
  switch (raw) {
    case 'supportive':
      return NotificationTone.supportive;
    case 'bold':
      return NotificationTone.bold;
    case 'savage':
      return NotificationTone.savage;
    case 'balanced':
    default:
      return NotificationTone.balanced;
  }
}

/// Localized rest-complete notification title for a given tone.
String restCompleteTitleForTone(NotificationTone tone, AppLocalizations l10n) {
  switch (tone) {
    case NotificationTone.supportive:
      return l10n.restCompleteTitleSupportive;
    case NotificationTone.balanced:
      return l10n.restCompleteTitleBalanced;
    case NotificationTone.bold:
      return l10n.restCompleteTitleBold;
    case NotificationTone.savage:
      return l10n.restCompleteTitleSavage;
  }
}

/// Localized rest-complete notification body for a given tone.
String restCompleteBodyForTone(NotificationTone tone, AppLocalizations l10n) {
  switch (tone) {
    case NotificationTone.supportive:
      return l10n.restCompleteBodySupportive;
    case NotificationTone.balanced:
      return l10n.restCompleteBodyBalanced;
    case NotificationTone.bold:
      return l10n.restCompleteBodyBold;
    case NotificationTone.savage:
      return l10n.restCompleteBodySavage;
  }
}

/// Localized human-readable label for the tone (Settings + onboarding).
String toneLabel(NotificationTone tone, AppLocalizations l10n) {
  switch (tone) {
    case NotificationTone.supportive:
      return l10n.toneSupportive;
    case NotificationTone.balanced:
      return l10n.toneBalanced;
    case NotificationTone.bold:
      return l10n.toneBold;
    case NotificationTone.savage:
      return l10n.toneSavage;
  }
}

/// Localized one-line description shown beneath the tone label.
String toneDescription(NotificationTone tone, AppLocalizations l10n) {
  switch (tone) {
    case NotificationTone.supportive:
      return l10n.toneSupportiveDescription;
    case NotificationTone.balanced:
      return l10n.toneBalancedDescription;
    case NotificationTone.bold:
      return l10n.toneBoldDescription;
    case NotificationTone.savage:
      return l10n.toneSavageDescription;
  }
}

/// Pinned English example sentences shown on the picker preview cards.
/// These are deliberately not localized — they showcase the *voice* of
/// each tone, and translating them would dilute the contrast users see
/// when comparing options. The label "Example" above the sentence IS
/// localized via the `notificationToneExampleLabel` key in AppLocalizations.
/// Persist a tone change locally AND enqueue a sync row so the new
/// tone reaches Supabase as soon as the device is online. This is the
/// only profile field that currently sync-queues from the client side
/// — other fields are intentionally local-only until we do a full
/// profile-sync pass. The remote update is keyed by `profile.remoteId`;
/// if the user is unauthenticated (no remote id) we just write locally.
Future<void> saveNotificationTone({
  required AppDatabase db,
  required SyncService syncService,
  required UserProfile profile,
  required NotificationTone tone,
}) async {
  final wire = tone.wireValue;
  await UserProfileDao(db).updateNotificationTone(profile.localId, wire);

  final remoteId = profile.remoteId;
  if (remoteId == null) return;
  await syncService.enqueue(
    table: 'user_profiles',
    rowId: profile.localId,
    operation: 'update',
    payload: {
      'remote_id': remoteId,
      'notification_tone': wire,
    },
  );
}

/// Workout-reminder notification title, escalated by how many rest days have passed.
/// Not localized by design — mirrors the voice-showcase pattern of [toneExampleSentence].
String workoutReminderTitleForRestDays(NotificationTone tone, int restDays) {
  if (restDays >= 3) {
    switch (tone) {
      case NotificationTone.supportive:
        return 'We miss you at the gym';
      case NotificationTone.balanced:
        return 'Time to get back';
      case NotificationTone.bold:
        return 'Get back in the gym';
      case NotificationTone.savage:
        return 'STOP SLACKING';
    }
  }
  switch (tone) {
    case NotificationTone.supportive:
      return 'Ready when you are';
    case NotificationTone.balanced:
      return 'Workout day';
    case NotificationTone.bold:
      return 'Time to train';
    case NotificationTone.savage:
      return 'NO MORE REST';
  }
}

/// Workout-reminder notification body, escalated by how many rest days have passed.
String workoutReminderBodyForRestDays(NotificationTone tone, int restDays) {
  if (restDays >= 3) {
    switch (tone) {
      case NotificationTone.supportive:
        return "It's been $restDays days. Even a short session counts.";
      case NotificationTone.balanced:
        return "You've rested $restDays days. Time to hit the gym.";
      case NotificationTone.bold:
        return '$restDays days off. Get back and crush it.';
      case NotificationTone.savage:
        return '$restDays DAYS?! NO EXCUSES. GYM. NOW.';
    }
  }
  switch (tone) {
    case NotificationTone.supportive:
      return 'Your next session is waiting for you.';
    case NotificationTone.balanced:
      return 'Keep your streak going. Let\'s train.';
    case NotificationTone.bold:
      return 'Your muscles are ready. Let\'s go.';
    case NotificationTone.savage:
      return 'MOVE IT. YOU\'RE WASTING GAINS.';
  }
}

/// Post-workout kudos notification title (Strava-style congrats, fired the
/// moment a session is finished). Unlocalized by design — mirrors the
/// voice-showcase pattern of [workoutReminderTitleForRestDays].
String workoutKudosTitleForTone(NotificationTone tone, String? name) {
  final who = name == null || name.trim().isEmpty ? '' : ', ${name.trim()}';
  switch (tone) {
    case NotificationTone.supportive:
      return 'Kudos to you$who 👏';
    case NotificationTone.balanced:
      return 'Kudos to you$who 👍';
    case NotificationTone.bold:
      return 'Strong work$who 💪';
    case NotificationTone.savage:
      return who.isEmpty
          ? 'DEMOLISHED 💥'
          : '${name!.trim().toUpperCase()}. DEMOLISHED 💥';
  }
}

/// Post-workout kudos body. [stats] is a preformatted
/// "4 sets · 1,240 kg · 52 min" fragment.
String workoutKudosBodyForTone(NotificationTone tone, String stats) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Nice work logging a session. $stats. Check out your stats.';
    case NotificationTone.balanced:
      return 'Workout complete: $stats. Check out your stats.';
    case NotificationTone.bold:
      return '$stats in the bank. Go admire the damage.';
    case NotificationTone.savage:
      return '$stats. AVERAGE IS OVER. AGAIN TOMORROW.';
  }
}

/// Streak days that earn a notification: the day a streak begins (2),
/// early momentum milestones, then every 25 days.
/// ponytail: same-day second session re-fires the same milestone — the
/// fixed notification id makes it replace in place, so it's harmless.
bool isStreakMilestone(int days) =>
    days == 2 ||
    days == 3 ||
    days == 5 ||
    days == 7 ||
    days == 10 ||
    days == 14 ||
    days == 21 ||
    days == 30 ||
    (days > 30 && days % 25 == 0);

/// Streak notification title. Day 2 = "streak started"; later milestones
/// celebrate the count.
String streakTitleForTone(NotificationTone tone, int days) {
  if (days <= 2) {
    switch (tone) {
      case NotificationTone.supportive:
        return "You've started a streak 🔥";
      case NotificationTone.balanced:
        return 'Streak started 🔥';
      case NotificationTone.bold:
        return 'Streak Alert 🔥';
      case NotificationTone.savage:
        return 'STREAK IGNITED 🔥';
    }
  }
  switch (tone) {
    case NotificationTone.supportive:
      return '$days days in a row 🔥';
    case NotificationTone.balanced:
      return 'Streak Alert: $days days 🔥';
    case NotificationTone.bold:
      return '$days straight days 🔥';
    case NotificationTone.savage:
      return '$days DAYS DEEP 🔥';
  }
}

/// Streak notification body.
String streakBodyForTone(NotificationTone tone, int days) {
  if (days <= 2) {
    switch (tone) {
      case NotificationTone.supportive:
        return 'Two workouts back to back — great momentum. Keep showing up!';
      case NotificationTone.balanced:
        return 'Two days in a row. Train again tomorrow to keep it going.';
      case NotificationTone.bold:
        return "Day 2 down. Don't you dare break the chain.";
      case NotificationTone.savage:
        return 'TWO DAYS. BREAK IT AND YOU START FROM ZERO.';
    }
  }
  switch (tone) {
    case NotificationTone.supportive:
      return "You've shown up $days days straight. Be proud of that.";
    case NotificationTone.balanced:
      return '$days consecutive training days. Keep the chain alive.';
    case NotificationTone.bold:
      return '$days days of showing up. Most people quit at 3.';
    case NotificationTone.savage:
      return "$days DAYS. NOBODY IS DOING IT LIKE YOU. DON'T STOP.";
  }
}

/// Appended to the kudos body when the session scored personal records.
String kudosPrSuffixForTone(NotificationTone tone, int count) {
  final prs = count == 1 ? '1 new PR' : '$count new PRs';
  switch (tone) {
    case NotificationTone.supportive:
    case NotificationTone.balanced:
      return ' Including $prs 🏆';
    case NotificationTone.bold:
      return ' $prs. Built different. 🏆';
    case NotificationTone.savage:
      return ' ${prs.toUpperCase()} 🏆';
  }
}

/// Evening streak-at-risk warning title ([days] = current streak length).
String streakRiskTitleForTone(NotificationTone tone, int days) {
  switch (tone) {
    case NotificationTone.supportive:
      return "Don't lose your streak 🔥";
    case NotificationTone.balanced:
      return 'Streak at risk 🔥';
    case NotificationTone.bold:
      return '$days-day streak on the line 🔥';
    case NotificationTone.savage:
      return 'YOUR STREAK IS DYING 🔥';
  }
}

/// Evening streak-at-risk warning body.
String streakRiskBodyForTone(NotificationTone tone, int days) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Your $days-day streak ends at midnight. '
          'Even a short session keeps it alive.';
    case NotificationTone.balanced:
      return 'No workout logged today. '
          'Train before midnight to keep your $days-day streak.';
    case NotificationTone.bold:
      return "$days days of work on the line. Don't let today be the day.";
    case NotificationTone.savage:
      return '$days DAYS ABOUT TO HIT ZERO. MOVE.';
  }
}

/// Muscle-recovered notification title. [muscle] is display-capitalized.
String muscleRecoveredTitleForTone(NotificationTone tone, String muscle) {
  switch (tone) {
    case NotificationTone.supportive:
      return '$muscle recovered 💚';
    case NotificationTone.balanced:
      return '$muscle recovered';
    case NotificationTone.bold:
      return '$muscle recovered. Load it.';
    case NotificationTone.savage:
      return '${muscle.toUpperCase()} READY. NO EXCUSES.';
  }
}

/// Muscle-recovered notification body.
String muscleRecoveredBodyForTone(NotificationTone tone, String muscle) {
  switch (tone) {
    case NotificationTone.supportive:
      return "Whenever you're ready — $muscle is back to full strength.";
    case NotificationTone.balanced:
      return '$muscle is back to 100%. Ready to train.';
    case NotificationTone.bold:
      return 'Fully recovered. Time to hit $muscle again.';
    case NotificationTone.savage:
      return 'RECOVERED MEANS TRAIN. ${muscle.toUpperCase()}. NOW.';
  }
}

/// Weekly recap title (fires Sunday evening).
String weeklyRecapTitleForTone(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Your week in review 📊';
    case NotificationTone.balanced:
      return 'Weekly recap 📊';
    case NotificationTone.bold:
      return "This week's damage 📊";
    case NotificationTone.savage:
      return 'WEEK REPORT 📊';
  }
}

/// Weekly recap body. [volume] is preformatted ("12,400 kg"); [deltaPct] is
/// the volume change vs last week, null when there is no last week.
String weeklyRecapBodyForTone(
  NotificationTone tone, {
  required int sessions,
  required String volume,
  int? deltaPct,
}) {
  final base = '$sessions session${sessions == 1 ? '' : 's'} · $volume';
  if (deltaPct == null) {
    switch (tone) {
      case NotificationTone.supportive:
        return '$base. A week to build on!';
      case NotificationTone.balanced:
        return '$base this week.';
      case NotificationTone.bold:
        return '$base. Now do it again, heavier.';
      case NotificationTone.savage:
        return '${base.toUpperCase()}. THE BASELINE IS SET.';
    }
  }
  final up = deltaPct >= 0;
  switch (tone) {
    case NotificationTone.supportive:
      return up
          ? '$base — $deltaPct% more than last week. Lovely work.'
          : '$base. A lighter week is still a week. Next one is yours.';
    case NotificationTone.balanced:
      return '$base (${up ? '+' : ''}$deltaPct% vs last week).';
    case NotificationTone.bold:
      return up
          ? '$base. Up $deltaPct% on last week. Keep climbing.'
          : '$base. Down ${-deltaPct}% on last week. Fix that.';
    case NotificationTone.savage:
      return up
          ? '${base.toUpperCase()}. +$deltaPct%. MORE.'
          : '${base.toUpperCase()}. DOWN ${-deltaPct}%. UNACCEPTABLE.';
  }
}

/// Scheduled-training-day reminder title ([label] = the day's name,
/// e.g. "Leg Day").
String scheduledDayTitleForTone(NotificationTone tone, String label) {
  switch (tone) {
    case NotificationTone.supportive:
      return '$label today 💪';
    case NotificationTone.balanced:
      return '$label today';
    case NotificationTone.bold:
      return '$label. Show up.';
    case NotificationTone.savage:
      return '${label.toUpperCase()}. NO SKIPPING.';
  }
}

/// Scheduled-training-day reminder body.
String scheduledDayBodyForTone(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Your next session is ready whenever you are.';
    case NotificationTone.balanced:
      return 'Your schedule says today is training day.';
    case NotificationTone.bold:
      return "The plan says train. Plans don't care about moods.";
    case NotificationTone.savage:
      return "THE PROGRAM DOESN'T DO DAYS OFF. GO.";
  }
}

// ── Lifetime milestones ──────────────────────────────────────────────────

/// Lifetime volume milestones, in kg.
/// ponytail: kg thresholds even for lbs users — display converts, the
/// crossing points just land on less-round lbs numbers.
const List<int> volumeMilestonesKg = [
  10000, 25000, 50000, 100000, 250000, 500000,
  1000000, 2500000, 5000000, 10000000,
];

/// The volume milestone this session pushed the lifetime [total] across,
/// or null. [sessionVolume] is the just-finished session's volume.
int? crossedVolumeMilestone({
  required double total,
  required double sessionVolume,
}) {
  for (final m in volumeMilestonesKg.reversed) {
    if (total >= m && total - sessionVolume < m) return m;
  }
  return null;
}

/// Session-count milestones worth a notification.
bool isSessionMilestone(int count) => const {
      10, 25, 50, 100, 150, 200, 300, 400, 500, 750, 1000,
    }.contains(count);

/// Lifetime milestone title.
String milestoneTitleForTone(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Milestone unlocked 🏋️';
    case NotificationTone.balanced:
      return 'Lifetime milestone 🏋️';
    case NotificationTone.bold:
      return 'Big number alert 🏋️';
    case NotificationTone.savage:
      return 'MILESTONE SMASHED 🏋️';
  }
}

/// Milestone body for a lifetime-volume crossing. [volume] preformatted.
String milestoneVolumeBodyForTone(NotificationTone tone, String volume) {
  switch (tone) {
    case NotificationTone.supportive:
      return "You've lifted $volume since day one. Incredible.";
    case NotificationTone.balanced:
      return 'Total weight lifted since day one: $volume.';
    case NotificationTone.bold:
      return '$volume lifted lifetime. Trucks are getting nervous.';
    case NotificationTone.savage:
      return '$volume LIFTED. THE BAR FEARS YOU.';
  }
}

/// Milestone body for a session-count milestone.
String milestoneSessionsBodyForTone(NotificationTone tone, int count) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'That was workout #$count. You keep showing up.';
    case NotificationTone.balanced:
      return 'Workout #$count logged since day one.';
    case NotificationTone.bold:
      return '#$count sessions deep. Momentum is a habit.';
    case NotificationTone.savage:
      return "WORKOUT #$count. MACHINES DON'T STOP.";
  }
}

String toneExampleSentence(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return "Whenever you're ready, your chest is recovered.";
    case NotificationTone.balanced:
      return 'Chest recovered. Ready to train.';
    case NotificationTone.bold:
      return 'Chest recovered. Get back in the gym.';
    case NotificationTone.savage:
      return 'NO EXCUSES. CHEST DAY. NOW.';
  }
}

/// A single tone-flavoured tagline appended to the **active-set** notification
/// body. Kept very short — Android shows ~2 lines before collapsing.
String activeSetTaglineForTone(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return "You've got this. Steady form.";
    case NotificationTone.balanced:
      return 'Lock in. One set at a time.';
    case NotificationTone.bold:
      return 'Own this set.';
    case NotificationTone.savage:
      return 'NO HALF REPS.';
  }
}

/// Tone-flavoured tagline shown alongside the **rest** countdown.
String restCountdownTaglineForTone(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Breathe. Recover.';
    case NotificationTone.balanced:
      return 'Reset. Next set incoming.';
    case NotificationTone.bold:
      return "Don't cool off.";
    case NotificationTone.savage:
      return 'CLOCK IS TICKING.';
  }
}

/// One-liner shown on the *generic* "workout in progress" notification
/// before any exercise has been loaded.
String workoutInProgressBodyForTone(NotificationTone tone) {
  switch (tone) {
    case NotificationTone.supportive:
      return 'Session live. Tap to jump back in.';
    case NotificationTone.balanced:
      return 'Workout in progress. Tap to open.';
    case NotificationTone.bold:
      return 'Session live. Get to work.';
    case NotificationTone.savage:
      return 'SESSION LIVE. STAY ON IT.';
  }
}
