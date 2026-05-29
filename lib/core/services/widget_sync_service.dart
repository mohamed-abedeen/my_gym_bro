import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes summary data to the always-on home-screen widgets (Android
/// AppWidget + iOS WidgetKit).
///
/// The widgets are pure read-only mirrors of values written here — they
/// never own state. Every call is best-effort: a write failure (no widget
/// installed, OS denied background work, plugin missing) is swallowed
/// silently so app flows never break.
///
/// Data contract — keys are stable across platforms because both the iOS
/// Swift code and the Android Kotlin code key off the same strings:
///
///   `streak_days`       int    — current consecutive-week streak
///   `streak_label`      String — pre-formatted ("5-day streak")
///   `next_focus`        String — muscle group to train next ("Chest")
///   `next_cta`          String — tone-aware short call to action
///   `last_synced_ms`    int    — epoch millis of the most recent push
///
/// The widget shows skeleton placeholders if values are missing — we
/// don't have to seed defaults here.
class WidgetSyncService {
  WidgetSyncService._();

  // Must exactly match the iOS App Group id (set in Xcode Capabilities)
  // and the Android shared-prefs name used by the AppWidgetProvider.
  // Changing this is a breaking change — old widgets will go blank until
  // the user re-adds them.
  static const String _groupId = 'group.com.mygymbro.widgets';
  static const String _iosWidgetName = 'MgbHomeWidget';
  static const String _androidWidgetProvider =
      'com.mygymbro.my_gym_bro.MgbAppWidgetProvider';

  static bool _initialised = false;

  // Localized label builders. Defaults are English; the app overrides
  // these whenever the active locale changes (see app.dart locale listener).
  // We can't access AppLocalizations from background isolates / Riverpod
  // providers without a BuildContext, so callers register localized
  // builders here once.
  static String _labelStart = 'Start a streak';
  static String _labelOne = '1-day streak';
  static String Function(int days) _labelMany = (days) => '$days-day streak';

  /// Update streak label strings/builders from the active locale. Call
  /// from app-level locale change so home-widget pushes stay localized.
  static void setStreakLabels({
    required String start,
    required String oneDay,
    required String Function(int days) manyBuilder,
  }) {
    _labelStart = start;
    _labelOne = oneDay;
    _labelMany = manyBuilder;
  }

  /// One-time setup. Safe to call multiple times.
  static Future<void> ensureInitialised() async {
    if (_initialised) return;
    try {
      await HomeWidget.setAppGroupId(_groupId);
      _initialised = true;
    } on Object catch (e) {
      // Plugin may be unavailable in tests or on unsupported platforms.
      if (kDebugMode) {
        debugPrint('[WidgetSync] init failed: $e');
      }
    }
  }

  /// Push the latest streak count + a formatted label.
  static Future<void> updateStreak(int days) async {
    await _writeAll({
      'streak_days': days,
      'streak_label': _streakLabel(days),
    });
  }

  /// Push the next muscle group the user should train + a tone-aware CTA.
  static Future<void> updateNextFocus({
    required String? muscleGroup,
    required String cta,
  }) async {
    await _writeAll({
      'next_focus': muscleGroup ?? '',
      'next_cta': cta,
    });
  }

  /// One-shot push of everything we know. Use this on session finish so
  /// the widget reflects post-workout state before the next provider tick.
  static Future<void> pushAll({
    required int streakDays,
    String? nextFocusMuscle,
    String? nextCta,
  }) async {
    await _writeAll({
      'streak_days': streakDays,
      'streak_label': _streakLabel(streakDays),
      'next_focus': nextFocusMuscle ?? '',
      'next_cta': nextCta ?? '',
      'last_synced_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── internal ───────────────────────────────────────────────────────

  static Future<void> _writeAll(Map<String, Object?> kv) async {
    await ensureInitialised();
    try {
      for (final entry in kv.entries) {
        await HomeWidget.saveWidgetData<Object?>(entry.key, entry.value);
      }
      await _requestUpdate();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[WidgetSync] write failed: $e');
    }
  }

  /// Tell the OS to redraw the widget(s) now. Cheap — both Android and
  /// iOS coalesce frequent requests into one redraw.
  static Future<void> _requestUpdate() async {
    if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: _iosWidgetName);
    } else if (Platform.isAndroid) {
      await HomeWidget.updateWidget(androidName: _androidWidgetProvider);
    }
  }

  static String _streakLabel(int days) {
    if (days <= 0) return _labelStart;
    if (days == 1) return _labelOne;
    return _labelMany(days);
  }
}
