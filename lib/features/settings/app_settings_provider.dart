import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';

/// Settings not backed by the UserProfile table — stored locally via
/// SecureStorage so they persist across launches without a DB migration.
///
/// Each toggle has its own [StateNotifierProvider] exposing a bool.
///
/// Reads are asynchronous on first launch; until the value is loaded from
/// storage we optimistically use the default.

class _BoolPrefNotifier extends StateNotifier<bool> {
  _BoolPrefNotifier({required this.key, required bool defaultValue})
      : super(defaultValue) {
    _load();
  }

  final String key;

  Future<void> _load() async {
    final raw = await SecureStorage().read(key);
    if (raw == 'true') state = true;
    if (raw == 'false') state = false;
  }

  Future<void> set(bool value) async {
    state = value;
    await SecureStorage().write(key, value.toString());
  }

  Future<void> toggle() => set(!state);
}

class _DoublePrefNotifier extends StateNotifier<double?> {
  _DoublePrefNotifier({required this.key}) : super(null) {
    _load();
  }

  final String key;

  Future<void> _load() async {
    final raw = await SecureStorage().read(key);
    final v = raw == null ? null : double.tryParse(raw);
    if (v != null) state = v;
  }

  Future<void> set(double? value) async {
    state = value;
    if (value == null) {
      await SecureStorage().delete(key);
    } else {
      await SecureStorage().write(key, value.toString());
    }
  }
}

// ponytail: calorie goal + body fat live in SecureStorage for now; move to
// UserProfile (DB + sync + onboarding) when onboarding collects them.

/// Weekly calorie-burn goal (kcal). Null = not set.
final weeklyCalorieGoalProvider =
    StateNotifierProvider<_DoublePrefNotifier, double?>(
  (ref) => _DoublePrefNotifier(key: 'setting_weekly_calorie_goal'),
);

/// Current body fat percentage. Null = not set.
final bodyFatPctProvider =
    StateNotifierProvider<_DoublePrefNotifier, double?>(
  (ref) => _DoublePrefNotifier(key: 'setting_body_fat_pct'),
);

/// Body fat percentage the first time the user ever entered it — the
/// baseline for the "dropped X% body fat" stat. Written once by the
/// body-fat settings sheet, never edited from the UI.
final bodyFatStartPctProvider =
    StateNotifierProvider<_DoublePrefNotifier, double?>(
  (ref) => _DoublePrefNotifier(key: 'setting_body_fat_start_pct'),
);

/// Whether to fire the daily training-reminder local notification.
final trainingRemindersEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) => _BoolPrefNotifier(
    key: 'setting_training_reminders_enabled',
    defaultValue: true,
  ),
);

/// Whether the rest-timer plays a sound when it completes.
final restTimerSoundEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) => _BoolPrefNotifier(
    key: 'setting_rest_timer_sound_enabled',
    defaultValue: true,
  ),
);

/// Whether the rest-timer vibrates when it completes.
final restTimerVibrationEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) => _BoolPrefNotifier(
    key: 'setting_rest_timer_vibration_enabled',
    defaultValue: true,
  ),
);

/// Whether to receive push notifications for community activity.
final communityNotificationsEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) => _BoolPrefNotifier(
    key: 'setting_community_notifications_enabled',
    defaultValue: true,
  ),
);
