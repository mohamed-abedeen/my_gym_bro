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
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/settings/skins_modal.dart';
import 'package:my_gym_bro/features/settings/widgets/settings_rows.dart';
import 'package:my_gym_bro/features/settings/widgets/settings_sheets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/oc_glass_btn.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings — premium iOS-26-style redesign.
///
/// Grouped frosted-glass sections (Appearance / Workout / Notifications /
/// General / Data & Account) over an ambient gradient backdrop, with compact
/// iOS-Settings rows: tinted icon badges, inline segmented controls for
/// two-state choices, and floating glass sheets for everything else.
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
      body: Stack(
        children: [
          // ── Ambient backdrop — gives the frosted cards something to blur ──
          Positioned(
            top: -110.h,
            right: -90.w,
            child: _AuroraBlob(
              color: colors.accent,
              size: 340.w,
              alpha: isDark ? 0.20 : 0.26,
            ),
          ),
          Positioned(
            top: 300.h,
            left: -150.w,
            child: _AuroraBlob(
              color: SettingsBadgeColors.indigo,
              size: 380.w,
              alpha: isDark ? 0.16 : 0.16,
            ),
          ),
          Positioned(
            bottom: -120.h,
            right: -70.w,
            child: _AuroraBlob(
              color: SettingsBadgeColors.teal,
              size: 320.w,
              alpha: isDark ? 0.12 : 0.14,
            ),
          ),

          // ── Content ──
          SafeArea(
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
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: colors.textPrimary,
                        ),
                      ),
                      OcGlassBtn(
                        type: OcGlassBtnType.close,
                        size: 42,
                        onTap: () => Navigator.of(context).pop(),
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
                          final newMode =
                              val ? ThemeMode.dark : ThemeMode.light;
                          ref.read(themeModeProvider.notifier).state = newMode;
                          SecureStorage()
                              .write('theme_mode', newMode.toString());
                        },
                      ),
                      SettingsSegmentedRow(
                        icon: Icons.accessibility_new_rounded,
                        iconColor: SettingsBadgeColors.teal,
                        label: l10n.anatomyModel,
                        options: [l10n.male, l10n.female],
                        selectedIndex:
                            anatomyGender == AnatomyGender.female ? 1 : 0,
                        onChanged: (i) => ref
                            .read(anatomyGenderProvider.notifier)
                            .set(i == 1
                                ? AnatomyGender.female
                                : AnatomyGender.male),
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
                        value: _bodyFatLabel(
                          ref.watch(bodyFatPctProvider),
                          l10n,
                        ),
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
                        value: ref
                            .watch(communityNotificationsEnabledProvider),
                        onChanged: (val) async {
                          await ref
                              .read(communityNotificationsEnabledProvider
                                  .notifier)
                              .set(val);
                          try {
                            final messaging = FirebaseMessaging.instance;
                            if (val) {
                              await messaging.subscribeToTopic('community');
                            } else {
                              await messaging
                                  .unsubscribeFromTopic('community');
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
                        value: localeDisplayName(
                          ref.watch(localeProvider),
                          l10n,
                        ),
                        onTap: () => showLanguageSheet(context, ref),
                      ),
                      SettingsNavRow(
                        icon: Icons.star_rounded,
                        iconColor: SettingsBadgeColors.yellow,
                        label: l10n.rateApp,
                        onTap: () =>
                            _openExternal(context, _storeReviewUri()),
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
                        onTap: () =>
                            _showSnack(context, l10n.exportComingSoon),
                      ),
                      SettingsNavRow(
                        icon: Icons.cleaning_services_rounded,
                        iconColor: SettingsBadgeColors.gray,
                        label: l10n.clearCache,
                        onTap: () => _clearCache(context, l10n),
                      ),
                      if (isSignedIn)
                        SettingsNavRow(
                          icon: Icons.logout_rounded,
                          iconColor: SettingsBadgeColors.gray,
                          label: l10n.signOut,
                          onTap: () =>
                              _showSignOutDialog(context, ref, l10n, colors),
                        ),
                      SettingsNavRow(
                        icon: Icons.delete_forever_rounded,
                        iconColor: SettingsBadgeColors.red,
                        label: l10n.deleteAccount,
                        isDestructive: true,
                        onTap: () => _showDeleteAccountDialog(
                            context, ref, l10n, colors),
                      ),
                    ],
                  ),

                  SizedBox(height: 26.h),

                  // ── Version footer ──
                  Center(
                    child: Column(
                      children: [
                        Text(
                          l10n.appName,
                          style: TextStyle(
                            color: colors.subtitleText,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        ref.watch(packageInfoProvider).when(
                              data: (info) => Text(
                                '${l10n.appVersion(info.version)} '
                                '(${info.buildNumber})',
                                style: TextStyle(
                                  color: colors.subtitleText
                                      .withValues(alpha: 0.7),
                                  fontSize: 11.sp,
                                ),
                              ),
                              loading: () => Text(
                                l10n.appVersion('…'),
                                style: TextStyle(
                                  color: colors.subtitleText
                                      .withValues(alpha: 0.7),
                                  fontSize: 11.sp,
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
        ],
      ),
    );
  }

  // ── Value formatters ──

  static String _bodyWeightLabel(UserProfile? p, AppLocalizations l10n) {
    final kg = p?.bodyWeightKg;
    if (kg == null) return l10n.notSet;
    final unit = p?.weightUnit ?? 'kg';
    return unit == 'lbs'
        ? '${(kg * 2.20462).round()} lbs'
        : '${kg.round()} kg';
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
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  // ── Clear cache ──

  static Future<void> _clearCache(
      BuildContext context, AppLocalizations l10n) async {
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
            child: Text(
              l10n.signOut,
              style: TextStyle(color: colors.danger),
            ),
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
      children: [
        // Identity row → profile screen
        SettingsNavRowShell(
          onTap: () => context.push(AppRoutes.profile),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.accent,
                      colors.accent.withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: UserAvatar(
                  size: 52,
                  url: p?.avatarUrl,
                  iconColor: colors.textPrimary,
                ),
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
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _planLabel(p?.subscriptionStatus, l10n),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
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
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  colors.accent,
                  Color.lerp(colors.accent, colors.amber, 0.55)!,
                ],
              ),
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colors.todayPillText.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Builder(builder: (context) {
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
                  }),
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

// ─────────────────────────────────────────────────────────────────────────────
// Ambient backdrop blob — soft radial glow the glass cards frost over
// ─────────────────────────────────────────────────────────────────────────────

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({
    required this.color,
    required this.size,
    required this.alpha,
  });

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
