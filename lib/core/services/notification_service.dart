import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles local rest timer notifications and Firebase Cloud Messaging.
class NotificationService {
  NotificationService._();

  static final _localPlugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'rest_timer';
  static const _channelName = 'Rest Timer';
  static const _channelDesc = 'Alerts when your rest period is complete';

  /// Initialise both local and FCM notification channels.
  static Future<void> initialise(WidgetRef ref) async {
    // ── Local notifications ──
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localPlugin.initialize(initSettings);

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );
      await _localPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // ── Firebase Cloud Messaging ──
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM Token: $token');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(
          title: message.notification?.title ?? 'My Gym Bro',
          body: message.notification?.body ?? '',
        );
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM initialisation failed: $e');
      }
    }
  }

  /// Show a local notification (used for rest timer completion).
  static Future<void> showRestComplete({
    String title = 'Rest complete!',
    String body = 'Time to start your next set.',
  }) async {
    await _showLocalNotification(title: title, body: body);
  }

  /// Schedule a notification after [seconds] delay.
  static Future<void> scheduleRestTimer(int seconds) async {
    // Cancel any existing rest timer
    await _localPlugin.cancel(0);

    // For simplicity, use a delayed local notification
    // In production, use zonedSchedule for precision
    Future.delayed(Duration(seconds: seconds), () {
      showRestComplete();
    });
  }

  /// Cancel the rest timer notification.
  static Future<void> cancelRestTimer() async {
    await _localPlugin.cancel(0);
  }

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
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localPlugin.show(0, title, body, details);
  }
}
