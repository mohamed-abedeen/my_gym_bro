import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';

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
      break;
    case _kActionSkip:
      timer.cancel();
      timer.onCompleteCallback?.call();
      break;
    case _kActionAdd15:
      timer.addTime(15);
      break;
    case _kActionSub15:
      timer.addTime(-15);
      break;
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

  /// Initialise local notifications and Firebase Cloud Messaging.
  /// Call once from main() before runApp().
  static Future<void> initialise() async {
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
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
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
        importance: Importance.defaultImportance,
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

  /// Schedule a rest-timer notification via a Dart-side delay.
  static Future<void> scheduleRestTimer(
    int seconds, {
    required String title,
    required String body,
  }) async {
    await _localPlugin.cancel(_restTimerId);
    Future.delayed(Duration(seconds: seconds), () {
      showRestComplete(title: title, body: body);
    });
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
    String? tagline,
    String? exerciseImagePath,
  }) async {
    final headline = 'Set $currentSet/$totalSets · $weight × $reps reps';
    final body = tagline == null ? headline : '$headline\n$tagline';

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
      showWhen: true,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      largeIcon: largeIcon,
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _kActionCompleteSet,
          'Complete Set',
          showsUserInterface: false,
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
    String? tagline,
    String? exerciseImagePath,
  }) async {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');

    final headline = nextSet == null
        ? 'Final set complete'
        : 'Next: Set $nextSet/$totalSets ($weight × $reps)';
    final restLine = 'Rest $minutes:$seconds';
    final body = tagline == null
        ? '$headline\n$restLine'
        : '$headline\n$restLine — $tagline';

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
      showWhen: true,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      showProgress: true,
      maxProgress: totalSeconds,
      progress: remaining,
      largeIcon: largeIcon,
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _kActionSkip,
          'Skip',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          _kActionSub15,
          '-15s',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          _kActionAdd15,
          '+15s',
          showsUserInterface: false,
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
      showWhen: true,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
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
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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
