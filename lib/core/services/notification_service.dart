import 'dart:io';
import 'dart:isolate';
import 'dart:ui';


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';

void _handleAction(String action) {
  final timer = RestTimerService.activeInstance;
  if (timer == null) return;

  switch (action) {
    case 'complete_set':
      timer.completeSetFromNotification?.call();
      break;
    case 'skip':
      timer.cancel();
      timer.onCompleteCallback?.call();
      break;
    case 'add15':
      timer.addTime(15);
      break;
    case 'sub15':
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
  static const _activeWorkoutChannelName = 'Active Workout';
  static const _activeWorkoutChannelDesc =
      'Shows your ongoing workout progress';

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
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    const initSettings =
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
  /// Displays the current exercise name as the title, set progress + weight
  /// info as the body, and a "Complete Set" action button.
  static Future<void> showActiveSet({
    required String exerciseName,
    required int currentSet,
    required int totalSets,
    required String weight,
    required int reps,
  }) async {
    final body = 'Set $currentSet/$totalSets · $weight × $reps reps';

    final androidDetails = AndroidNotificationDetails(
      _activeWorkoutChannelId,
      _activeWorkoutChannelName,
      channelDescription: _activeWorkoutChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'complete_set',
          'Complete Set',
          showsUserInterface: false,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentBanner: false,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(
      _activeWorkoutId,
      exerciseName,
      body,
      details,
      payload: 'complete_set',
    );
  }

  /// Update the rest-timer notification (State B — rest timer running).
  ///
  /// Shows the current exercise name as the title, next set info as the body,
  /// a progress bar for remaining rest time, and Skip / -15s / +15s buttons.
  static Future<void> updateRestTimer({
    required String exerciseName,
    required int nextSet,
    required int totalSets,
    required String weight,
    required int reps,
    required int remaining,
    required int totalSeconds,
  }) async {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final body =
        'Next: Set $nextSet/$totalSets ($weight × $reps)\nRest $minutes:$seconds';

    final androidDetails = AndroidNotificationDetails(
      _activeWorkoutChannelId,
      _activeWorkoutChannelName,
      channelDescription: _activeWorkoutChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      showProgress: true,
      maxProgress: totalSeconds,
      progress: remaining,
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'skip',
          'Skip',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'sub15',
          '-15s',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'add15',
          '+15s',
          showsUserInterface: false,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentBanner: false,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(
      _activeWorkoutId,
      exerciseName,
      body,
      details,
      payload: 'skip',
    );
  }

  /// Show a persistent ongoing notification for an active workout.
  ///
  /// On Android the notification uses a chronometer anchored to [startedAt],
  /// so the elapsed-time counter updates live without any Dart-side ticking.
  /// The notification is `ongoing` (non-dismissible) until explicitly cancelled.
  static Future<void> showActiveWorkout({
    required String title,
    required String body,
    required DateTime startedAt,
  }) async {
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
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(_activeWorkoutId, title, body, details);
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
