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
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/oc_glass_btn.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings — designed to HIG patterns the way Apple's first-party apps
/// (Fitness, Health, Journal) do settings, not as a Settings-app clone:
///
/// * collapsing large title with an always-frosted top edge and an inline
///   title that fades in as you scroll (the iOS large-title pattern),
/// * centered profile header (avatar, name, plan),
/// * a subscription feature card,
/// * icon-less content-first grouped rows with footnote group footers,
/// * centered red text rows for destructive actions.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = _scroll.offset > 30;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final profile = ref.watch(userProfileProvider);
    final anatomyGender = ref.watch(anatomyGenderProvider);
    final weightUnit = profile.valueOrNull?.weightUnit ?? 'kg';
    final authState = ref.watch(authNotifierProvider);
    final isSignedIn = authState.status == AuthStatus.authenticated;
    final topPad = MediaQuery.of(context).padding.top;
    final barHeight = topPad + 50.h;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Ambient accent wash behind the top of the screen ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320.h,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.accent.withValues(alpha: isDark ? 0.12 : 0.16),
                      colors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable content ──
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              padding:
                  EdgeInsets.fromLTRB(16.w, barHeight + 6.h, 16.w, 48.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large title — fades out as the inline title fades in.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _collapsed ? 0 : 1,
                    child: Text(
                      l10n.settings,
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  // ── Profile header — centered, taps through to profile ──
                  Center(child: _ProfileHeader(profile: profile.valueOrNull)),

                  SizedBox(height: 20.h),

                  // ── Subscription feature card ──
                  _SubscriptionCard(profile: profile.valueOrNull),

                  SizedBox(height: 24.h),

                  // ── Appearance ──
                  SettingsSection(
                    header: l10n.settingsSectionAppearance,
                    children: [
                      SettingsNavRow(
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

                  SizedBox(height: 22.h),

                  // ── Workout ──
                  SettingsSection(
                    header: l10n.settingsSectionWorkout,
                    footer: l10n.settingsWorkoutFooter,
                    children: [
                      SettingsSegmentedRow(
                        label: l10n.weightUnit,
                        options: const ['KG', 'LBS'],
                        selectedIndex: weightUnit == 'lbs' ? 1 : 0,
                        onChanged: (i) =>
                            _setWeightUnit(ref, i == 1 ? 'lbs' : 'kg'),
                      ),
                      SettingsNavRow(
                        label: l10n.bodyWeight,
                        value: _bodyWeightLabel(profile.valueOrNull, l10n),
                        onTap: () => BodyWeightSheet.show(context),
                      ),
                      SettingsNavRow(
                        label: l10n.calorieGoal,
                        value: _calorieGoalLabel(
                          ref.watch(weeklyCalorieGoalProvider),
                          l10n,
                        ),
                        onTap: () => showCalorieGoalSheet(context, ref),
                      ),
                      SettingsNavRow(
                        label: l10n.bodyFat,
                        value: _bodyFatLabel(
                          ref.watch(bodyFatPctProvider),
                          l10n,
                        ),
                        onTap: () => showBodyFatSheet(context, ref),
                      ),
                      SettingsNavRow(
                        label: l10n.defaultRestTime,
                        value: _restLabel(
                          profile.valueOrNull?.defaultRestSeconds ?? 90,
                        ),
                        onTap: () => RestTimeSheet.show(context),
                      ),
                      SettingsSwitchRow(
                        label: l10n.restTimerSound,
                        value: ref.watch(restTimerSoundEnabledProvider),
                        onChanged: (val) => ref
                            .read(restTimerSoundEnabledProvider.notifier)
                            .set(val),
                      ),
                      SettingsSwitchRow(
                        label: l10n.restTimerVibration,
                        value: ref.watch(restTimerVibrationEnabledProvider),
                        onChanged: (val) => ref
                            .read(restTimerVibrationEnabledProvider.notifier)
                            .set(val),
                      ),
                    ],
                  ),

                  SizedBox(height: 22.h),

                  // ── Notifications ──
                  SettingsSection(
                    header: l10n.notificationsSection,
                    footer: l10n.settingsNotificationsFooter,
                    children: [
                      SettingsSwitchRow(
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

                  SizedBox(height: 22.h),

                  // ── General ──
                  SettingsSection(
                    header: l10n.settingsSectionGeneral,
                    children: [
                      SettingsNavRow(
                        label: l10n.language,
                        value: localeDisplayName(
                          ref.watch(localeProvider),
                          l10n,
                        ),
                        onTap: () => showLanguageSheet(context, ref),
                      ),
                      SettingsNavRow(
                        label: l10n.rateApp,
                        onTap: () =>
                            _openExternal(context, _storeReviewUri()),
                      ),
                      SettingsNavRow(
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
                        label: l10n.privacyPolicy,
                        onTap: () => _openExternal(
                          context,
                          Uri.parse('https://mygymbro.app/privacy'),
                        ),
                      ),
                      SettingsNavRow(
                        label: l10n.termsOfService,
                        onTap: () => _openExternal(
                          context,
                          Uri.parse('https://mygymbro.app/terms'),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 22.h),

                  // ── Data ──
                  SettingsSection(
                    header: l10n.settingsSectionData,
                    children: [
                      SettingsNavRow(
                        label: l10n.exportData,
                        onTap: () =>
                            _showSnack(context, l10n.exportComingSoon),
                      ),
                      SettingsNavRow(
                        label: l10n.clearCache,
                        onTap: () => _clearCache(context, l10n),
                      ),
                    ],
                  ),

                  SizedBox(height: 22.h),

                  // ── Account actions (Apple requirement: delete path) ──
                  SettingsSection(
                    footer: l10n.settingsDataFooter,
                    children: [
                      if (isSignedIn)
                        SettingsButtonRow(
                          label: l10n.signOut,
                          color: colors.danger,
                          onTap: () =>
                              _showSignOutDialog(context, ref, l10n, colors),
                        ),
                      SettingsButtonRow(
                        label: l10n.deleteAccount,
                        color: colors.danger,
                        onTap: () => _showDeleteAccountDialog(
                            context, ref, l10n, colors),
                      ),
                    ],
                  ),

                  SizedBox(height: 28.h),

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

          // ── Pinned top bar — frosted edge + inline title on collapse ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: barHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Frost is always on (matches the app's scroll-edge
                // pattern); only the tint fades in with the collapse.
                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _collapsed ? 1 : 0,
                    child: GlassSurface(
                      radius: 0,
                      border: false,
                      blurSigma: AppGlass.blurStrong,
                      tint: colors.background
                          .withValues(alpha: isDark ? 0.55 : 0.6),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _collapsed ? 1 : 0,
                    child: Container(
                      height: 0.5,
                      color: colors.divider.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _collapsed ? 1 : 0,
                          child: Text(
                            l10n.settings,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OcGlassBtn(
                            type: OcGlassBtnType.close,
                            size: 38,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
// Profile header — centered avatar, name, plan (Apple ID / Health pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(AppRoutes.profile),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.textPrimary.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: UserAvatar(
              size: 74,
              url: profile?.avatarUrl,
              iconColor: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile?.displayName ?? 'User',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(width: 3.w),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary.withValues(alpha: 0.6),
                size: 20.sp,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            _planLabel(profile?.subscriptionStatus, l10n),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: colors.subtitleText,
            ),
          ),
        ],
      ),
    );
  }

  static String _planLabel(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'active':
      case 'grace_period':
        return l10n.planPremium;
      case 'expired':
        return l10n.subscriptionExpired;
      default:
        return l10n.freeTrial;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription feature card → paywall (hosts Restore Purchases)
// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final status = profile?.subscriptionStatus;
    final daysLeft = ref.watch(trialDaysLeftProvider);
    final planText = status == 'active'
        ? l10n.planPremium
        : (daysLeft != null ? l10n.trialDaysLeft(daysLeft) : l10n.freeTrial);

    return GlassSurface(
      width: double.infinity,
      radius: 22.r,
      child: SettingsNavRowShell(
        onTap: () => context.push(AppRoutes.paywall),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.accent,
                    Color.lerp(colors.accent, colors.amber, 0.55)!,
                  ],
                ),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: colors.todayPillText,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.manageSubscription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    planText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: colors.subtitleText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary.withValues(alpha: 0.6),
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
