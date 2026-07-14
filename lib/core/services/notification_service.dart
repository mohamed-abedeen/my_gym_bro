import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// Action constants — shared between Android `AndroidNotificationAction.id`
// and the iOS `DarwinNotificationAction.identifier`. Keeping them in one place
// means the cross-platform dispatch in [_handleAction] stays trivial.
// ─────────────────────────────────────────────────────────────────────────────

const String _kActionCompleteSet = 'complete_set';
const String _kActionSkip = 'skip';
const String _kActionAdd15 = 'add15';
const String _kActionSub15 = 'sub15';

/// Payload set on the *body* of the active-session notification. Tapping
/// anywhere outside an action button dispatches this and we deep-link to
/// the active-session screen.
const String _kActionOpenSession = 'open_session';

/// iOS notification category identifier — must be registered at init time
/// AND referenced from [DarwinNotificationDetails.categoryIdentifier] so
/// the actions actually surface on iOS.
const String _kActiveWorkoutCategoryId = 'mgb.activeWorkout';

void _handleAction(String action) {
  // Quick haptic so the user gets immediate physical feedback when an
  // action button is tapped from the notification shade. iOS users feel
  // this on the device that produced the tap; Android users get the same.
  // Fire-and-forget — if the platform channel isn't ready we still process
  // the action.
  HapticFeedback.lightImpact();

  // ── Deep-link tap (notification body, not an action button) ──
  if (action == _kActionOpenSession) {
    final router = globalRouter;
    if (router != null) {
      router.push('/session');
    }
    return;
  }

  final timer = RestTimerService.activeInstance;
  if (timer == null) return;

  switch (action) {
    case _kActionCompleteSet:
      timer.completeSetFromNotification?.call();
    case _kActionSkip:
      timer.cancel();
      timer.onCompleteCallback?.call();
    case _kActionAdd15:
      timer.addTime(15);
    case _kActionSub15:
      timer.addTime(-15);
  }
}

/// Top-level handler for notification action taps.
///
/// Routes action payloads from the active-workout notification to
/// the main isolate via a SendPort.
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  final action = response.actionId ?? response.payload;
  if (action == null) return;

  final sendPort = IsolateNameServer.lookupPortByName('notification_action_port');
  if (sendPort != null) {
    // Send action to the main isolate.
    sendPort.send(action);
  } else {
    // Fallback if we're somehow running in the main isolate and the port isn't set,
    // though realistically this won't work if the main isolate is dead.
    _handleAction(action);
  }
}

class NotificationService {
  NotificationService._();

  static final _localPlugin = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int _restTimerId = 0;
  static const int _workoutReminderId = 1;
  static const int _activeWorkoutId = 2;
  static const int kudosNotificationId = 3;
  static const int streakNotificationId = 4;
  static const int streakRiskNotificationId = 5;
  static const int muscleRecoveredNotificationId = 6;
  static const int weeklyRecapNotificationId = 7;
  static const int scheduledDayNotificationId = 8;
  static const int milestoneNotificationId = 9;

  // Rest timer channel
  static const _channelId = 'rest_timer_silent';
  static const _channelName = 'Rest Timer';
  static const _channelDesc = 'Alerts when your rest period is complete';

  // Workout reminder channel
  static const _workoutChannelId = 'workout_reminder';
  static const _workoutChannelName = 'Workout Reminders';
  static const _workoutChannelDesc =
      'Daily reminders to stay on track with your workouts';

  // Active workout persistent notification channel
  static const _activeWorkoutChannelId = 'workout_active';
  static const _activeWorkoutChannelName = 'MyGymBro Session';
  static const _activeWorkoutChannelDesc =
      'Live status while a workout is in progress';

  // Achievements channel (kudos, streaks, records)
  static const _achievementChannelId = 'achievements';
  static const _achievementChannelName = 'Achievements';
  static const _achievementChannelDesc =
      'Workout kudos, streak alerts, and personal records';

  // ── Active-workout notification look ────────────────────────────────────
  // Brand accent (dark-theme accent) — tints the small icon, app name and
  // action buttons so the ongoing notification reads as MyGymBro at a glance.
  static const Color _kBrandAccent = Color(0xFFF0FF00);

  /// "●●○○" set-progress dots for the current exercise. Empty when the
  /// exercise has an unreasonable number of sets (keeps the line tidy).
  static String _setDots(int done, int total) =>
      total > 0 && total <= 8 && done >= 0 && done <= total
          ? '●' * done + '○' * (total - done)
          : '';

  /// Header shown next to the app name, e.g. "CHEST · LIVE" / "LEGS · REST".
  static String _headerLine(String? muscleGroup, String stateWord) =>
      muscleGroup == null || muscleGroup.isEmpty
          ? stateWord
          : '${muscleGroup.toUpperCase()} · $stateWord';

  /// Initialise local notifications and Firebase Cloud Messaging.
  /// Call once from main() before runApp().
  static Future<void> initialise() async {
    // Timezone database for zonedSchedule. We only schedule relative
    // deadlines ("now + N seconds"), so the default UTC location is
    // sufficient — no need for a platform lookup of the device zone.
    tz_data.initializeTimeZones();

    // ── Setup Isolate Port for Background Actions ────────────────────────────
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping('notification_action_port');
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      'notification_action_port',
    );
    port.listen((message) {
      if (message is String) {
        _handleAction(message);
      }
    });

    // ── Local notifications ──────────────────────────────────────────────────
    // Status-bar small icon: white alpha-mask silhouette of the logo figure
    // (drawable-*/ic_stat_notification.png) — full-color mipmaps render as a
    // gray blob there.
    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    final iosInit = DarwinInitializationSettings(
      notificationCategories: _iosCategories(),
    );
    final initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationResponse,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Request runtime POST_NOTIFICATIONS permission (Android 13+).
      await androidPlugin?.requestNotificationsPermission();

      const restChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: false,
      );
      const workoutChannel = AndroidNotificationChannel(
        _workoutChannelId,
        _workoutChannelName,
        description: _workoutChannelDesc,
      );
      // Low importance so it silently appears in the status bar during a
      // workout without making noise every time it is updated.
      const activeWorkoutChannel = AndroidNotificationChannel(
        _activeWorkoutChannelId,
        _activeWorkoutChannelName,
        description: _activeWorkoutChannelDesc,
        importance: Importance.low,
      );

      await androidPlugin?.createNotificationChannel(restChannel);
      await androidPlugin?.createNotificationChannel(workoutChannel);
      await androidPlugin?.createNotificationChannel(activeWorkoutChannel);
    }

    // ── Firebase Cloud Messaging ─────────────────────────────────────────────
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (kDebugMode) debugPrint('FCM Token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(
          title: message.notification?.title ?? 'My Gym Bro',
          body: message.notification?.body ?? '',
        );
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('FCM initialisation failed: $e');
    }
  }

  // ── iOS category definitions ───────────────────────────────────────────────

  /// iOS doesn't support per-notification action lists the way Android does
  /// — actions are declared upfront via a *category* registered at init.
  /// The notification then references the category by id and iOS draws the
  /// matching actions.
  static List<DarwinNotificationCategory> _iosCategories() {
    return [
      DarwinNotificationCategory(
        _kActiveWorkoutCategoryId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            _kActionCompleteSet,
            'Complete Set',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            },
          ),
          DarwinNotificationAction.plain(_kActionSub15, '-15s'),
          DarwinNotificationAction.plain(_kActionAdd15, '+15s'),
          DarwinNotificationAction.plain(
            _kActionSkip,
            'Skip',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.destructive,
            },
          ),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
    ];
  }

  // ── Rest timer ─────────────────────────────────────────────────────────────

  /// Show a local notification when rest is complete.
  static Future<void> showRestComplete({
    required String title,
    required String body,
  }) async {
    await _showLocalNotification(title: title, body: body);
  }

  /// Schedule the rest-complete notification at an OS level so it fires at
  /// the deadline even when the app is suspended (locked phone mid-rest is
  /// the normal case at the gym — Dart timers stop ticking there).
  ///
  /// Replaces any previously scheduled rest notification. Prefers an exact
  /// alarm on Android and falls back to inexact delivery when the exact-
  /// alarm permission is missing (Android 12+ treats it as user-revocable).
  static Future<void> scheduleRestTimer(
    int seconds, {
    required String title,
    required String body,
  }) async {
    await _localPlugin.cancel(_restTimerId);
    if (seconds <= 0) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: false);
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final deadline =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    try {
      await _localPlugin.zonedSchedule(
        _restTimerId,
        title,
        body,
        deadline,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException {
      // Exact alarms not permitted — deliver inexactly rather than not at
      // all. For a 1–5 minute rest the OS usually lands within seconds.
      try {
        await _localPlugin.zonedSchedule(
          _restTimerId,
          title,
          body,
          deadline,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } on Exception catch (e) {
        if (kDebugMode) debugPrint('scheduleRestTimer failed: $e');
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('scheduleRestTimer failed: $e');
    }
  }

  /// Cancel any pending rest-timer notification.
  static Future<void> cancelRestTimer() async {
    await _localPlugin.cancel(_restTimerId);
  }

  // ── Active workout: set & rest notifications ───────────────────────────────

  /// Show the "active set" notification (State A — no rest timer running).
  ///
  /// Renders with:
  ///   • the live session chronometer in the status bar (anchored to
  ///     [sessionStartedAt] so Android updates the elapsed time on its own)
  ///   • the exercise image as `largeIcon` when [exerciseImagePath] is given
  ///   • the user's tone-aware tagline as the second body line
  ///   • a "Complete Set" action that mirrors the iOS category
  ///   • tap-anywhere-else deep-links to the active-session screen via the
  ///     [_kActionOpenSession] payload.
  static Future<void> showActiveSet({
    required String exerciseName,
    required int currentSet,
    required int totalSets,
    required String weight,
    required int reps,
    required DateTime sessionStartedAt,
    int completedSets = 0,
    String? muscleGroup,
    String? sessionSummary,
    String? tagline,
    String? exerciseImagePath,
  }) async {
    final headline = 'Set $currentSet of $totalSets  ·  $weight × $reps reps';
    final dots = _setDots(completedSets, totalSets);
    final body = [
      headline,
      if (dots.isNotEmpty) dots,
      if (tagline != null) tagline,
    ].join('\n');

    final largeIcon = exerciseImagePath != null
        ? FilePathAndroidBitmap(exerciseImagePath)
        : null;

    final androidDetails = AndroidNotificationDetails(
      _activeWorkoutChannelId,
      _activeWorkoutChannelName,
      channelDescription: _activeWorkoutChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      // Keep the session chronometer visible across all states so the user
      // never loses their running session time when they look at the lock
      // screen / status bar.
      usesChronometer: true,
      when: sessionStartedAt.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      color: _kBrandAccent,
      subText: _headerLine(muscleGroup, 'LIVE'),
      ticker: '$exerciseName — $headline',
      largeIcon: largeIcon,
      styleInformation: BigTextStyleInformation(
        body,
        // Whole-session totals pinned under the expanded card,
        // e.g. "5 sets · 1,240 kg this session".
        summaryText: sessionSummary,
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _kActionCompleteSet,
          '✓ Complete Set',
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentBanner: false,
      categoryIdentifier: _kActiveWorkoutCategoryId,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(
      _activeWorkoutId,
      exerciseName,
      body,
      details,
      // Tap-anywhere payload — actions provide their own actionId, so the
      // body payload only fires when the user taps the notification itself.
      payload: _kActionOpenSession,
    );
  }

  /// Update the rest-timer notification (State B — rest timer running).
  ///
  /// Same chronometer + tap-deep-link guarantees as [showActiveSet]; adds a
  /// progress bar on Android and tone-flavoured copy. If [nextSet] is null
  /// (final set just finished), shows a "Final set complete" line instead
  /// of the nonsensical "0 reps" the old impl produced.
  static Future<void> updateRestTimer({
    required String exerciseName,
    required int? nextSet,
    required int totalSets,
    required String weight,
    required int reps,
    required int remaining,
    required int totalSeconds,
    required DateTime sessionStartedAt,
    int completedSets = 0,
    String? muscleGroup,
    String? sessionSummary,
    String? tagline,
    String? exerciseImagePath,
  }) async {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');

    // Countdown first — it's the collapsed/lock-screen line.
    final restLine = '⏳ Rest $minutes:$seconds';
    final headline = nextSet == null
        ? 'Final set complete — finish strong'
        : 'Up next  ·  Set $nextSet of $totalSets  ·  $weight × $reps reps';
    final dots = _setDots(completedSets, totalSets);
    final body = [
      restLine,
      headline,
      if (dots.isNotEmpty) dots,
      if (tagline != null) tagline,
    ].join('\n');

    final largeIcon = exerciseImagePath != null
        ? FilePathAndroidBitmap(exerciseImagePath)
        : null;

    final androidDetails = AndroidNotificationDetails(
      _activeWorkoutChannelId,
      _activeWorkoutChannelName,
      channelDescription: _activeWorkoutChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      usesChronometer: true,
      when: sessionStartedAt.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      color: _kBrandAccent,
      subText: _headerLine(muscleGroup, 'REST'),
      ticker: '$exerciseName — $restLine',
      showProgress: true,
      maxProgress: totalSeconds,
      progress: remaining,
      largeIcon: largeIcon,
      styleInformation: BigTextStyleInformation(
        body,
        summaryText: sessionSummary,
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _kActionSkip,
          'Skip',
        ),
        const AndroidNotificationAction(
          _kActionSub15,
          '−15s',
        ),
        const AndroidNotificationAction(
          _kActionAdd15,
          '+15s',
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentBanner: false,
      categoryIdentifier: _kActiveWorkoutCategoryId,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(
      _activeWorkoutId,
      exerciseName,
      body,
      details,
      payload: _kActionOpenSession,
    );
  }

  /// Show a persistent ongoing notification for an active workout.
  ///
  /// Used at session start before the first exercise is loaded. Once any
  /// exercise is active, the notifier upgrades to [showActiveSet] which
  /// includes the exercise name + actions.
  static Future<void> showActiveWorkout({
    required String title,
    required String body,
    required DateTime startedAt,
    String? exerciseImagePath,
  }) async {
    final largeIcon = exerciseImagePath != null
        ? FilePathAndroidBitmap(exerciseImagePath)
        : null;

    final androidDetails = AndroidNotificationDetails(
      _activeWorkoutChannelId,
      _activeWorkoutChannelName,
      channelDescription: _activeWorkoutChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      usesChronometer: true,
      when: startedAt.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      color: _kBrandAccent,
      subText: 'LIVE',
      largeIcon: largeIcon,
      styleInformation: BigTextStyleInformation(body),
    );
    const iosDetails = DarwinNotificationDetails(
      presentBanner: false,
      categoryIdentifier: _kActiveWorkoutCategoryId,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(
      _activeWorkoutId,
      title,
      body,
      details,
      payload: _kActionOpenSession,
    );
  }

  /// Cancel the persistent active-workout notification.
  static Future<void> cancelActiveWorkout() async {
    await _localPlugin.cancel(_activeWorkoutId);
  }

  // ── Achievements (kudos / streaks) ─────────────────────────────────────────

  /// One-shot celebration notification (post-workout kudos, streak alert).
  /// Fixed [id]s replace in place instead of stacking.
  static Future<void> showAchievement({
    required int id,
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _achievementChannelId,
        _achievementChannelName,
        channelDescription: _achievementChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        color: _kBrandAccent,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _localPlugin.show(id, title, body, details);
  }

  /// Schedule a one-shot achievement notification for a wall-clock moment
  /// ([when] in device-local time). Replaces any pending one with the same
  /// [id]; [when] in the past or under a minute away is delivered ASAP.
  /// Inexact delivery — none of these are second-critical.
  static Future<void> scheduleAchievementAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await _localPlugin.cancel(id);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _achievementChannelId,
        _achievementChannelName,
        channelDescription: _achievementChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        color: _kBrandAccent,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    // tz.local is pinned to UTC (see initialise) — schedule relative to now.
    final delay = when.difference(DateTime.now());
    final deadline = tz.TZDateTime.now(tz.local)
        .add(delay.isNegative ? const Duration(minutes: 1) : delay);
    try {
      await _localPlugin.zonedSchedule(
        id,
        title,
        body,
        deadline,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('scheduleAchievementAt($id) failed: $e');
    }
  }

  /// Cancel a pending achievement notification by id.
  static Future<void> cancelAchievement(int id) => _localPlugin.cancel(id);

  // ── Workout reminder ───────────────────────────────────────────────────────

  /// Schedule a daily workout reminder.
  static Future<void> scheduleWorkoutReminder({
    required String title,
    required String body,
  }) async {
    await _localPlugin.cancel(_workoutReminderId);

    const androidDetails = AndroidNotificationDetails(
      _workoutChannelId,
      _workoutChannelName,
      channelDescription: _workoutChannelDesc,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.periodicallyShow(
      _workoutReminderId,
      title,
      body,
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancel the daily workout reminder.
  static Future<void> cancelWorkoutReminder() async {
    await _localPlugin.cancel(_workoutReminderId);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(_restTimerId, title, body, details);
  }
}
