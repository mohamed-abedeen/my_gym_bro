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

/// Whether to receive push notifications for community activity.
final communityNotificationsEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) => _BoolPrefNotifier(
    key: 'setting_community_notifications_enabled',
    defaultValue: true,
  ),
);
