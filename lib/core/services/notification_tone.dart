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
