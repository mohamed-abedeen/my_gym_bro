import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// Plans the ambient achievement notifications that must be scheduled ahead
/// of time: streak-at-risk (tonight 20:00), weekly recap (Sunday 18:00),
/// next scheduled-training-day reminder, and muscle-recovered.
///
/// [refresh] recomputes everything and re-schedules in place (fixed ids).
/// The scaffold calls it on app start and whenever the streak changes —
/// which covers every finished workout and the midnight rollover.
///
/// ponytail: content is frozen at scheduling time. If the app never opens
/// again before a deadline, the weekly recap can undercount sessions logged
/// after the last refresh. Move content to a push backend if that matters.
class AchievementPlanner {
  AchievementPlanner(this._ref);

  final Ref _ref;

  Future<void> refresh() async {
    final profile = _ref.read(userProfileProvider).valueOrNull;
    final tone = notificationToneFromString(profile?.notificationTone);
    final unit = profile?.weightUnit ?? 'kg';

    // Independent best-effort steps — one failing must not kill the rest.
    await _guard(() => _planStreakRisk(tone));
    await _guard(() => _planWeeklyRecap(tone, unit));
    await _guard(() => _planScheduledDay(tone));
    await _guard(() => _planMuscleRecovered(tone));
  }

  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } on Exception {
      // Best-effort: notifications are never worth crashing over.
    }
  }

  /// Warn at 20:00 when today is the streak's last allowed rest day.
  Future<void> _planStreakRisk(NotificationTone tone) async {
    final risk = await _ref.read(streakRiskProvider.future);
    if (!risk.atRiskToday) {
      await NotificationService.cancelAchievement(
        NotificationService.streakRiskNotificationId,
      );
      return;
    }
    final now = DateTime.now();
    var fireAt = DateTime(now.year, now.month, now.day, 20);
    if (now.isAfter(fireAt)) {
      fireAt = now.add(const Duration(minutes: 15));
    }
    // Too late to act on — don't nag at midnight.
    if (fireAt.isAfter(DateTime(now.year, now.month, now.day, 23, 30))) {
      return;
    }
    await NotificationService.scheduleAchievementAt(
      id: NotificationService.streakRiskNotificationId,
      title: streakRiskTitleForTone(tone, risk.streak),
      body: streakRiskBodyForTone(tone, risk.streak),
      when: fireAt,
    );
  }

  /// Sunday 18:00 recap of this week's sessions + volume vs last week.
  Future<void> _planWeeklyRecap(NotificationTone tone, String unit) async {
    final sessions = await _ref.read(sessionDaoProvider).getAll();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));

    var thisWeekSessions = 0;
    double thisWeekVol = 0;
    double lastWeekVol = 0;
    for (final s in sessions) {
      final f = s.finishedAt;
      if (f == null) continue;
      if (!f.isBefore(weekStart)) {
        thisWeekSessions++;
        thisWeekVol += s.totalVolume ?? 0;
      } else if (!f.isBefore(lastWeekStart)) {
        lastWeekVol += s.totalVolume ?? 0;
      }
    }
    if (thisWeekSessions == 0) {
      await NotificationService.cancelAchievement(
        NotificationService.weeklyRecapNotificationId,
      );
      return;
    }

    // Upcoming Sunday 18:00 (or next week's if that already passed).
    var fireAt = weekStart.add(const Duration(days: 6, hours: 18));
    if (now.isAfter(fireAt)) fireAt = fireAt.add(const Duration(days: 7));

    const lbsPerKg = 2.20462;
    final vol = unit == 'lbs' ? thisWeekVol * lbsPerKg : thisWeekVol;
    final deltaPct = lastWeekVol <= 0
        ? null
        : (((thisWeekVol - lastWeekVol) / lastWeekVol) * 100).round();
    await NotificationService.scheduleAchievementAt(
      id: NotificationService.weeklyRecapNotificationId,
      title: weeklyRecapTitleForTone(tone),
      body: weeklyRecapBodyForTone(
        tone,
        sessions: thisWeekSessions,
        volume: '${vol.round()} $unit',
        deltaPct: deltaPct,
      ),
      when: fireAt,
    );
  }

  /// One-shot reminder when the next scheduled training day comes due,
  /// labeled with the day's name ("Leg Day today"). Replaces the generic
  /// daily reminder whenever an active schedule drives the cadence.
  Future<void> _planScheduledDay(NotificationTone tone) async {
    final active = await _ref.read(activeScheduleProvider.future);
    if (active == null) return; // no schedule → generic reminder stays

    final hours =
        await _ref.read(nextSessionHoursProvider(active.localId).future);
    final days = await _ref.read(scheduleDaysProvider(active.localId).future);
    final trainingDays = days.where((d) => !isRestScheduleDay(d)).toList();
    if (hours == null || trainingDays.isEmpty) return;

    // The labeled reminder takes over from the generic daily one.
    await NotificationService.cancelWorkoutReminder();
    if (hours <= 0) return; // already due — nothing to schedule ahead

    final nextIdx = await _ref
        .read(nextTrainingDayIndexProvider(active.localId).future);
    final label =
        trainingDays[nextIdx % trainingDays.length].label ?? 'Training day';

    // Fire when due, nudged into waking hours (09:00–21:00).
    var fireAt = DateTime.now().add(Duration(hours: hours));
    if (fireAt.hour < 9) {
      fireAt = DateTime(fireAt.year, fireAt.month, fireAt.day, 9);
    } else if (fireAt.hour >= 21) {
      fireAt = DateTime(fireAt.year, fireAt.month, fireAt.day + 1, 9);
    }
    await NotificationService.scheduleAchievementAt(
      id: NotificationService.scheduledDayNotificationId,
      title: scheduledDayTitleForTone(tone, label),
      body: scheduledDayBodyForTone(tone),
      when: fireAt,
    );
  }

  /// "Chest recovered" — fires when the next recovering muscle completes.
  Future<void> _planMuscleRecovered(NotificationTone tone) async {
    final states = await _ref.read(muscleRecoveryProvider.future);
    final now = DateTime.now();
    DateTime? soonest;
    String? muscle;
    for (final s in states) {
      final at = s.recoveredAt;
      if (s.state != MuscleState.recovering || at == null) continue;
      if (at.isAfter(now) && (soonest == null || at.isBefore(soonest))) {
        soonest = at;
        muscle = s.muscleGroup;
      }
    }
    if (soonest == null || muscle == null) {
      await NotificationService.cancelAchievement(
        NotificationService.muscleRecoveredNotificationId,
      );
      return;
    }
    // Recovery can complete at odd hours — hold the ping until 08:00.
    var fireAt = soonest;
    if (fireAt.hour < 8) {
      fireAt = DateTime(fireAt.year, fireAt.month, fireAt.day, 8);
    }
    final display = muscle.isEmpty
        ? muscle
        : muscle[0].toUpperCase() + muscle.substring(1);
    await NotificationService.scheduleAchievementAt(
      id: NotificationService.muscleRecoveredNotificationId,
      title: muscleRecoveredTitleForTone(tone, display),
      body: muscleRecoveredBodyForTone(tone, display),
      when: fireAt,
    );
  }
}

final achievementPlannerProvider =
    Provider<AchievementPlanner>(AchievementPlanner.new);
