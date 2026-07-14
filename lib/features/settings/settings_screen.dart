import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/settings/skins_modal.dart';
import 'package:my_gym_bro/features/settings/widgets/settings_rows.dart';
import 'package:my_gym_bro/features/settings/widgets/settings_sheets.dart';
import 'package:my_gym_bro/features/settings/workout_export.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings — flat-iOS redesign (handoff option 1a).
///
/// Grouped flat white cards (Appearance / Workout / Notifications /
/// General / Data & Account) on the plain grouped-grey backdrop, with
/// compact iOS-Settings rows: flat color badges, inline segmented controls
/// for two-state choices, and sheets for everything else.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final profile = ref.watch(userProfileProvider);
    final anatomyGender = ref.watch(anatomyGenderProvider);
    final weightUnit = profile.valueOrNull?.weightUnit ?? 'kg';
    final authState = ref.watch(authNotifierProvider);
    final isSignedIn = authState.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 48.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.settings,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.card,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16.sp,
                        color: colors.subtitleText,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // ── Profile hero card ──
              _ProfileCard(profile: profile),

              SizedBox(height: 20.h),

              // ── Appearance ──
              SettingsSection(
                header: l10n.settingsSectionAppearance,
                children: [
                  SettingsNavRow(
                    icon: Icons.palette_rounded,
                    iconColor: SettingsBadgeColors.purple,
                    label: l10n.skins,
                    value: availableSkins
                        .firstWhere(
                          (s) => s.id == ref.watch(selectedSkinProvider),
                          orElse: () => availableSkins.first,
                        )
                        .name,
                    onTap: () => showSkinsModal(context, ref),
                  ),
                  SettingsSwitchRow(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    iconColor: SettingsBadgeColors.indigo,
                    label: l10n.darkMode,
                    value: isDark,
                    onChanged: (val) {
                      final newMode = val ? ThemeMode.dark : ThemeMode.light;
                      ref.read(themeModeProvider.notifier).state = newMode;
                      SecureStorage().write('theme_mode', newMode.toString());
                    },
                  ),
                  SettingsSegmentedRow(
                    icon: Icons.accessibility_new_rounded,
                    iconColor: SettingsBadgeColors.teal,
                    label: l10n.anatomyModel,
                    options: [l10n.male, l10n.female],
                    selectedIndex: anatomyGender == AnatomyGender.female
                        ? 1
                        : 0,
                    onChanged: (i) => ref
                        .read(anatomyGenderProvider.notifier)
                        .set(
                          i == 1 ? AnatomyGender.female : AnatomyGender.male,
                        ),
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // ── Workout ──
              SettingsSection(
                header: l10n.settingsSectionWorkout,
                children: [
                  SettingsSegmentedRow(
                    icon: Icons.fitness_center_rounded,
                    iconColor: SettingsBadgeColors.blue,
                    label: l10n.weightUnit,
                    options: const ['KG', 'LBS'],
                    selectedIndex: weightUnit == 'lbs' ? 1 : 0,
                    onChanged: (i) =>
                        _setWeightUnit(ref, i == 1 ? 'lbs' : 'kg'),
                  ),
                  SettingsNavRow(
                    icon: Icons.monitor_weight_rounded,
                    iconColor: SettingsBadgeColors.green,
                    label: l10n.bodyWeight,
                    value: _bodyWeightLabel(profile.valueOrNull, l10n),
                    onTap: () => BodyWeightSheet.show(context),
                  ),
                  SettingsNavRow(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: SettingsBadgeColors.yellow,
                    label: l10n.calorieGoal,
                    value: _calorieGoalLabel(
                      ref.watch(weeklyCalorieGoalProvider),
                      l10n,
                    ),
                    onTap: () => showCalorieGoalSheet(context, ref),
                  ),
                  SettingsNavRow(
                    icon: Icons.percent_rounded,
                    iconColor: SettingsBadgeColors.teal,
                    label: l10n.bodyFat,
                    value: _bodyFatLabel(ref.watch(bodyFatPctProvider), l10n),
                    onTap: () => showBodyFatSheet(context, ref),
                  ),
                  SettingsNavRow(
                    icon: Icons.timer_rounded,
                    iconColor: SettingsBadgeColors.orange,
                    label: l10n.defaultRestTime,
                    value: _restLabel(
                      profile.valueOrNull?.defaultRestSeconds ?? 90,
                    ),
                    onTap: () => RestTimeSheet.show(context),
                  ),
                  SettingsSwitchRow(
                    icon: Icons.volume_up_rounded,
                    iconColor: SettingsBadgeColors.pink,
                    label: l10n.restTimerSound,
                    value: ref.watch(restTimerSoundEnabledProvider),
                    onChanged: (val) => ref
                        .read(restTimerSoundEnabledProvider.notifier)
                        .set(val),
                  ),
                  SettingsSwitchRow(
                    icon: Icons.vibration_rounded,
                    iconColor: SettingsBadgeColors.red,
                    label: l10n.restTimerVibration,
                    value: ref.watch(restTimerVibrationEnabledProvider),
                    onChanged: (val) => ref
                        .read(restTimerVibrationEnabledProvider.notifier)
                        .set(val),
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // ── Notifications ──
              SettingsSection(
                header: l10n.notificationsSection,
                children: [
                  SettingsSwitchRow(
                    icon: Icons.alarm_rounded,
                    iconColor: SettingsBadgeColors.red,
                    label: l10n.trainingReminders,
                    value: ref.watch(trainingRemindersEnabledProvider),
                    onChanged: (val) async {
                      await ref
                          .read(trainingRemindersEnabledProvider.notifier)
                          .set(val);
                      if (val) {
                        await NotificationService.scheduleWorkoutReminder(
                          title: l10n.trainingReminders,
                          body: l10n.trainingReminderBody,
                        );
                      } else {
                        await NotificationService.cancelWorkoutReminder();
                      }
                    },
                  ),
                  SettingsNavRow(
                    icon: Icons.record_voice_over_rounded,
                    iconColor: SettingsBadgeColors.orange,
                    label: l10n.notificationTone,
                    value: toneLabel(
                      notificationToneFromString(
                        profile.valueOrNull?.notificationTone,
                      ),
                      l10n,
                    ),
                    onTap: () => showNotificationToneSheet(
                      context,
                      ref,
                      profile.valueOrNull,
                    ),
                  ),
                  SettingsSwitchRow(
                    icon: Icons.people_alt_rounded,
                    iconColor: SettingsBadgeColors.green,
                    label: l10n.communityNotifications,
                    value: ref.watch(communityNotificationsEnabledProvider),
                    onChanged: (val) async {
                      await ref
                          .read(communityNotificationsEnabledProvider.notifier)
                          .set(val);
                      try {
                        final messaging = FirebaseMessaging.instance;
                        if (val) {
                          await messaging.subscribeToTopic('community');
                        } else {
                          await messaging.unsubscribeFromTopic('community');
                        }
                      } on Exception catch (e) {
                        if (kDebugMode) {
                          debugPrint('[FCM] topic toggle failed: $e');
                        }
                      }
                    },
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // ── General ──
              SettingsSection(
                header: l10n.settingsSectionGeneral,
                children: [
                  SettingsNavRow(
                    icon: Icons.language_rounded,
                    iconColor: SettingsBadgeColors.blue,
                    label: l10n.language,
                    value: localeDisplayName(ref.watch(localeProvider), l10n),
                    onTap: () => showLanguageSheet(context, ref),
                  ),
                  SettingsNavRow(
                    icon: Icons.star_rounded,
                    iconColor: SettingsBadgeColors.yellow,
                    label: l10n.rateApp,
                    onTap: () => _openExternal(context, _storeReviewUri()),
                  ),
                  SettingsNavRow(
                    icon: Icons.mail_rounded,
                    iconColor: SettingsBadgeColors.blue,
                    label: l10n.contactSupport,
                    onTap: () => _openExternal(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: 'support@mygymbro.app',
                        queryParameters: {
                          'subject': 'My Gym Bro — Support request',
                        },
                      ),
                    ),
                  ),
                  SettingsNavRow(
                    icon: Icons.shield_rounded,
                    iconColor: SettingsBadgeColors.gray,
                    label: l10n.privacyPolicy,
                    onTap: () => _openExternal(
                      context,
                      Uri.parse('https://mygymbro.app/privacy'),
                    ),
                  ),
                  SettingsNavRow(
                    icon: Icons.description_rounded,
                    iconColor: SettingsBadgeColors.gray,
                    label: l10n.termsOfService,
                    onTap: () => _openExternal(
                      context,
                      Uri.parse('https://mygymbro.app/terms'),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // ── Data & Account (Apple requirement) ──
              SettingsSection(
                header: l10n.settingsSectionData,
                children: [
                  SettingsNavRow(
                    icon: Icons.ios_share_rounded,
                    iconColor: SettingsBadgeColors.blue,
                    label: l10n.exportData,
                    onTap: () => _exportData(context, ref, l10n),
                  ),
                  SettingsNavRow(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: SettingsBadgeColors.gray,
                    label: l10n.clearCache,
                    onTap: () => _clearCache(context, l10n),
                  ),
                  SettingsNavRow(
                    icon: Icons.delete_forever_rounded,
                    iconColor: SettingsBadgeColors.red,
                    label: l10n.deleteAccount,
                    isDestructive: true,
                    onTap: () =>
                        _showDeleteAccountDialog(context, ref, l10n, colors),
                  ),
                ],
              ),

              // ── Sign out — standalone iOS-style button card ──
              if (isSignedIn) ...[
                SizedBox(height: 18.h),
                SettingsSection(
                  children: [
                    SettingsNavRowShell(
                      onTap: () =>
                          _showSignOutDialog(context, ref, l10n, colors),
                      child: Center(
                        child: Text(
                          l10n.signOut,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 26.h),

              // ── Version footer ──
              Center(
                child: Column(
                  children: [
                    Text(
                      l10n.appName,
                      style: TextStyle(
                        color: colors.subtitleText,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    ref
                        .watch(packageInfoProvider)
                        .when(
                          data: (info) => Text(
                            '${l10n.appVersion(info.version)} '
                            '(${info.buildNumber})',
                            style: TextStyle(
                              color: colors.subtitleText.withValues(alpha: 0.7),
                              fontSize: 10.sp,
                            ),
                          ),
                          loading: () => Text(
                            l10n.appVersion('…'),
                            style: TextStyle(
                              color: colors.subtitleText.withValues(alpha: 0.7),
                              fontSize: 10.sp,
                            ),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Value formatters ──

  static String _bodyWeightLabel(UserProfile? p, AppLocalizations l10n) {
    final kg = p?.bodyWeightKg;
    if (kg == null) return l10n.notSet;
    final unit = p?.weightUnit ?? 'kg';
    return unit == 'lbs' ? '${(kg * 2.20462).round()} lbs' : '${kg.round()} kg';
  }

  static String _calorieGoalLabel(double? goal, AppLocalizations l10n) {
    if (goal == null) return l10n.notSet;
    return '${goal.round()} kcal';
  }

  static String _bodyFatLabel(double? pct, AppLocalizations l10n) {
    if (pct == null) return l10n.notSet;
    return pct == pct.roundToDouble()
        ? '${pct.round()}%'
        : '${pct.toStringAsFixed(1)}%';
  }

  static String _restLabel(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final padded = s < 10 ? '0$s' : '$s';
    return '$m:$padded';
  }

  // ── Weight unit ──

  static Future<void> _setWeightUnit(WidgetRef ref, String unit) async {
    final dao = ref.read(userProfileDaoProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      await dao.upsert(UserProfilesCompanion(weightUnit: Value(unit)));
    } else {
      await dao.updateWeightUnit(profile.localId, unit);
    }
    ref.invalidate(userProfileProvider);
  }

  // ── External links ──

  static Uri _storeReviewUri() {
    // Platform-appropriate review URLs. These no-op gracefully if the bundle
    // ID isn't yet published — caller surfaces an error snackbar.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse(
        'https://apps.apple.com/app/id0000000000?action=write-review',
      );
    }
    return Uri.parse('market://details?id=com.mygymbro.app');
  }

  static Future<void> _openExternal(BuildContext context, Uri uri) async {
    final l10n = AppLocalizations.of(context);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showSnack(context, l10n.couldNotOpenLink);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[launchUrl] $e');
      if (context.mounted) _showSnack(context, l10n.couldNotOpenLink);
    }
  }

  static void _showSnack(BuildContext context, String msg) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        backgroundColor: colors.cardElevated,
      ),
    );
  }

  // ── Export data ──

  /// Exports the full workout history as CSV and opens the share sheet.
  static Future<void> _exportData(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final db = ref.read(databaseProvider);
    final unit = ref.read(weightUnitProvider);
    final messenger = ScaffoldMessenger.of(context);
    // Brief loading state while the query + file write run.
    _showSnack(context, l10n.exportPreparing);
    try {
      final csv = await buildWorkoutCsv(db, unit);
      messenger.hideCurrentSnackBar();
      if (csv == null) {
        if (context.mounted) _showSnack(context, l10n.exportNothingYet);
        return;
      }
      // Anchor for the iPad share popover.
      Rect? origin;
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          origin = box.localToGlobal(Offset.zero) & box.size;
        }
      }
      await shareWorkoutCsv(csv, sharePositionOrigin: origin);
    } on Exception catch (e, st) {
      CrashReporter.recordError(e, stackTrace: st, reason: 'workout export');
      messenger.hideCurrentSnackBar();
      if (context.mounted) _showSnack(context, l10n.exportFailed);
    }
  }

  // ── Clear cache ──

  static Future<void> _clearCache(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    try {
      await CachedNetworkImage.evictFromCache('');
      await ExerciseGifCache.instance.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (context.mounted) _showSnack(context, l10n.cacheCleared);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[clearCache] $e');
      if (context.mounted) _showSnack(context, l10n.cacheClearFailed);
    }
  }

  // ── Sign out ──

  static void _showSignOutDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppColorsTheme colors,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          l10n.signOut,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.signOutConfirm,
          style: TextStyle(color: colors.subtitleText, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.signIn);
            },
            child: Text(l10n.signOut, style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
  }

  // ── Delete account dialog ──

  static void _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppColorsTheme colors,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          l10n.deleteAccount,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.deleteAccountConfirm,
          style: TextStyle(color: colors.subtitleText, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(authNotifierProvider.notifier)
                  .deleteAccount();
              if (!context.mounted) return;
              if (ok) {
                Navigator.of(context).pop();
              } else {
                _showSnack(context, l10n.deleteAccountFailed);
              }
            },
            child: Text(
              l10n.deleteAccountButton,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile hero card — avatar, name, plan, premium banner
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final AsyncValue<UserProfile?> profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = profile.valueOrNull;

    return SettingsSection(
      radius: 18.r,
      children: [
        // Identity row → profile screen
        SettingsNavRowShell(
          onTap: () => context.push(AppRoutes.profile),
          child: Row(
            children: [
              UserAvatar(
                size: 46,
                url: p?.avatarUrl,
                iconColor: colors.textPrimary,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.displayName ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _planLabel(p?.subscriptionStatus, l10n),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.subtitleText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary.withValues(alpha: 0.7),
                size: 18.sp,
              ),
            ],
          ),
        ),

        // Premium banner → paywall (hosts Restore Purchases)
        SettingsNavRowShell(
          onTap: () => context.push(AppRoutes.paywall),
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: colors.accent,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: colors.todayPillText,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    l10n.manageSubscription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.todayPillText,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colors.todayPillText.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Builder(
                    builder: (context) {
                      final status = p?.subscriptionStatus;
                      final daysLeft = ref.watch(trialDaysLeftProvider);
                      final label = status == 'active'
                          ? l10n.planPremium
                          : (daysLeft != null
                                ? l10n.trialDaysLeft(daysLeft)
                                : l10n.freeTrial);
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.todayPillText,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 2.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.todayPillText.withValues(alpha: 0.7),
                  size: 18.sp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _planLabel(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'active':
      case 'grace_period':
        return l10n.planPremium;
      case 'expired':
        return l10n.subscriptionExpired;
      case 'trial':
        return l10n.freeTrial;
      default:
        return l10n.freeTrial;
    }
  }
}
