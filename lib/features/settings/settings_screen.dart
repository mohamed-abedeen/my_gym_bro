import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/oc_glass_btn.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';


/// Figma frame 26 — Account & Settings screen.
/// Full-screen modal with rounded panel, elevated cards.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider);
    final topPad = MediaQuery.of(context).padding.top;
    final colors = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final anatomyGender = ref.watch(anatomyGenderProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Rounded background panel ──
          Positioned(
            left: 7.w,
            right: 7.w,
            top: topPad + 30.h,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.panelBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(55.r),
                  topRight: Radius.circular(55.r),
                ),
              ),
            ),
          ),

          // ── Scrollable content ──
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topPad + 50.h,
                left: 25.w,
                right: 25.w,
                bottom: 40.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: "Account" + X button ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.account,
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      OcGlassBtn(
                        type: OcGlassBtnType.close,
                        size: 48,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // ── Profile card ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(14.w, 15.h, 14.w, 18.h),
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: Column(
                      children: [
                        // Avatar + Name + Email
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.profile),
                          child: Row(
                            children: [
                              LiquidGlassButton(
                                width: 68.w,
                                height: 68.w,
                                opacity: 0.65,
                                radius: 296.r,
                                child: UserAvatar(
                                  size: 62,
                                  url: profile.valueOrNull?.avatarUrl,
                                  iconColor: colors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.when(
                                        data: (p) =>
                                            p?.displayName ?? 'User',
                                        loading: () => '...',
                                        error: (_, __) => 'User',
                                      ),
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      profile.when(
                                        data: (p) =>
                                            p?.subscriptionStatus ?? '',
                                        loading: () => '',
                                        error: (_, __) => '',
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w400,
                                        color: colors.subtitleText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // Divider
                        Padding(
                          padding: EdgeInsets.only(left: 68.w),
                          child: Container(
                            height: 1.h,
                            decoration: BoxDecoration(
                              color: colors.divider,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),

                        SizedBox(height: 12.h),

                        // Subscription row — tappable, opens the paywall
                        // (which hosts Restore Purchases). Trailing text shows
                        // the trial countdown when applicable.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push(AppRoutes.paywall),
                          child: Row(
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                color: colors.textPrimary,
                                size: 21.sp,
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                l10n.manageSubscription,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Builder(builder: (context) {
                                final daysLeft =
                                    ref.watch(trialDaysLeftProvider);
                                final label = daysLeft != null
                                    ? l10n.trialDaysLeft(daysLeft)
                                    : l10n.freeTrial;
                                return Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: colors.subtitleText,
                                  ),
                                );
                              }),
                              SizedBox(width: 6.w),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.subtitleText,
                                size: 18.sp,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── Settings rows card ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: Column(
                      children: [
                        // Skins
                        _SettingsRow(
                          icon: Icons.palette_outlined,
                          label: 'Skins',
                          subtitle: availableSkins
                              .firstWhere(
                                (s) => s.id == ref.watch(selectedSkinProvider),
                                orElse: () => availableSkins.first,
                              )
                              .name,
                          colors: colors,
                          onTap: () => showSkinsModal(context, ref),
                        ),
                        _settingsDivider(colors),
                        // Dark Mode toggle
                        _DarkModeRow(
                          isDark: isDark,
                          colors: colors,
                          label: l10n.darkMode,
                          onChanged: (val) {
                            final newMode = val ? ThemeMode.dark : ThemeMode.light;
                            ref.read(themeModeProvider.notifier).state = newMode;
                            SecureStorage().write('theme_mode', newMode.toString());
                          },
                        ),
                        _settingsDivider(colors),
                        // Anatomy Gender toggle
                        _ToggleRow(
                          icon: Icons.person_rounded,
                          label: 'Anatomy Gender',
                          value: anatomyGender == AnatomyGender.female,
                          activeLabel: 'Female',
                          inactiveLabel: 'Male',
                          colors: colors,
                          onChanged: (val) {
                            ref.read(anatomyGenderProvider.notifier).state =
                                val ? AnatomyGender.female : AnatomyGender.male;
                          },
                        ),
                        _settingsDivider(colors),
                        // Notification tone
                        _SettingsRow(
                          icon: Icons.notifications_outlined,
                          label: l10n.notificationTone,
                          subtitle: toneLabel(
                            notificationToneFromString(
                              profile.value?.notificationTone,
                            ),
                            l10n,
                          ),
                          colors: colors,
                          onTap: () => _showNotificationToneModal(
                            context, ref, colors, l10n, profile.value),
                        ),
                        _settingsDivider(colors),
                        // Training Reminders
                        _SwitchRow(
                          icon: Icons.alarm_rounded,
                          label: l10n.trainingReminders,
                          value: ref.watch(trainingRemindersEnabledProvider),
                          colors: colors,
                          onChanged: (val) async {
                            await ref
                                .read(trainingRemindersEnabledProvider.notifier)
                                .set(val);
                            if (val) {
                              await NotificationService.scheduleWorkoutReminder(
                                title: l10n.trainingReminders,
                                body: "Keep your streak going. Let's train.",
                              );
                            } else {
                              await NotificationService.cancelWorkoutReminder();
                            }
                          },
                        ),
                        _settingsDivider(colors),
                        // Rest Timer Sound
                        _SwitchRow(
                          icon: Icons.volume_up_rounded,
                          label: l10n.restTimerSound,
                          value: ref.watch(restTimerSoundEnabledProvider),
                          colors: colors,
                          onChanged: (val) => ref
                              .read(restTimerSoundEnabledProvider.notifier)
                              .set(val),
                        ),
                        _settingsDivider(colors),
                        // Community Notifications
                        _SwitchRow(
                          icon: Icons.people_outline_rounded,
                          label: l10n.communityNotifications,
                          value: ref
                              .watch(communityNotificationsEnabledProvider),
                          colors: colors,
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
                        _settingsDivider(colors),
                        // Language
                        _SettingsRow(
                          icon: Icons.language_rounded,
                          label: l10n.language,
                          subtitle: _localeName(ref.watch(localeProvider)),
                          colors: colors,
                          onTap: () => _showLanguageSheet(context, ref, colors),
                        ),
                        _settingsDivider(colors),
                        // Weight Unit
                        _SettingsRow(
                          icon: Icons.fitness_center_rounded,
                          label: l10n.weightUnit,
                          subtitle: profile.whenData((p) => p?.weightUnit ?? 'kg').value ?? 'kg',
                          colors: colors,
                          onTap: () => _WeightUnitSheet.show(context),
                        ),
                        _settingsDivider(colors),
                        // Body Weight — feeds the calorie estimator.
                        _SettingsRow(
                          icon: Icons.monitor_weight_outlined,
                          label: l10n.bodyWeight,
                          subtitle: () {
                            final p = profile.valueOrNull;
                            final kg = p?.bodyWeightKg;
                            if (kg == null) return l10n.notSet;
                            final unit = p?.weightUnit ?? 'kg';
                            return unit == 'lbs'
                                ? '${(kg * 2.20462).round()} lbs'
                                : '${kg.round()} kg';
                          }(),
                          colors: colors,
                          onTap: () => _BodyWeightSheet.show(context),
                        ),
                        _settingsDivider(colors),
                        // Default Rest Time
                        _SettingsRow(
                          icon: Icons.timer_outlined,
                          label: l10n.defaultRestTime,
                          subtitle: '${profile.whenData((p) => p?.defaultRestSeconds ?? 90).value ?? 90}s',
                          colors: colors,
                          onTap: () => _RestTimeSheet.show(context),
                        ),
                        _settingsDivider(colors),
                        // Rate the App
                        _SettingsRow(
                          icon: Icons.star_outline_rounded,
                          label: l10n.rateApp,
                          colors: colors,
                          onTap: () => _openExternal(
                            context,
                            _storeReviewUri(),
                            colors: colors,
                          ),
                        ),
                        _settingsDivider(colors),
                        // Contact Support
                        _SettingsRow(
                          icon: Icons.mail_outline_rounded,
                          label: l10n.contactSupport,
                          colors: colors,
                          onTap: () => _openExternal(
                            context,
                            Uri(
                              scheme: 'mailto',
                              path: 'support@mygymbro.app',
                              queryParameters: {
                                'subject': 'My Gym Bro — Support request',
                              },
                            ),
                            colors: colors,
                          ),
                        ),
                        _settingsDivider(colors),
                        // Privacy Policy
                        _SettingsRow(
                          icon: Icons.shield_outlined,
                          label: l10n.privacyPolicy,
                          colors: colors,
                          onTap: () => _openExternal(
                            context,
                            Uri.parse('https://mygymbro.app/privacy'),
                            colors: colors,
                          ),
                        ),
                        _settingsDivider(colors),
                        // Terms of Service
                        _SettingsRow(
                          icon: Icons.description_outlined,
                          label: l10n.termsOfService,
                          colors: colors,
                          onTap: () => _openExternal(
                            context,
                            Uri.parse('https://mygymbro.app/terms'),
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── Data & Account card (Apple requirement) ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: Column(
                      children: [
                        // Export My Data
                        _SettingsRow(
                          icon: Icons.download_rounded,
                          label: l10n.exportData,
                          colors: colors,
                          onTap: () {
                            if (kDebugMode) {
                              debugPrint('[Export] CSV export not yet implemented.');
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Export coming soon'),
                                backgroundColor: colors.cardElevated,
                              ),
                            );
                          },
                        ),
                        _settingsDivider(colors),
                        // Clear Cache
                        _SettingsRow(
                          icon: Icons.cleaning_services_rounded,
                          label: l10n.clearCache,
                          colors: colors,
                          onTap: () => _clearCache(context, colors),
                        ),
                        _settingsDivider(colors),
                        // Delete Account — red, Apple required
                        _SettingsRow(
                          icon: Icons.delete_outline_rounded,
                          label: l10n.deleteAccount,
                          isDestructive: true,
                          colors: colors,
                          onTap: () => _showDeleteAccountDialog(context, ref, l10n, colors),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Version footer — reads the real bundled version+build
                  // from PackageInfo via `packageInfoProvider` instead of
                  // a hardcoded string, so a release that bumps the
                  // version in pubspec.yaml is reflected automatically.
                  Center(
                    child: ref.watch(packageInfoProvider).when(
                          data: (info) => Text(
                            '${l10n.appVersion(info.version)} (${info.buildNumber})',
                            style: TextStyle(
                              color: colors.subtitleText,
                              fontSize: 12.sp,
                            ),
                          ),
                          loading: () => Text(
                            l10n.appVersion('…'),
                            style: TextStyle(
                              color: colors.subtitleText,
                              fontSize: 12.sp,
                            ),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  static String _localeName(Locale? locale) {
    if (locale == null) return 'System';
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      default:
        return locale.languageCode;
    }
  }

  static Widget _settingsDivider(AppColorsTheme colors) => Padding(
        padding: EdgeInsets.only(left: 50.w),
        child: Container(
          height: 1.h,
          decoration: BoxDecoration(
            color: colors.divider,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      );

  // ── Language bottom sheet ──

  static void _showLanguageSheet(
      BuildContext context, WidgetRef ref, AppColorsTheme colors) {
    final current = ref.read(localeProvider);
    final options = <Locale?>[
      null, // system
      const Locale('en'),
      const Locale('de'),
      const Locale('es'),
      const Locale('fr'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((locale) {
              final name = _localeName(locale);
              final isSelected = current == locale;
              return ListTile(
                leading: isSelected
                    ? Icon(Icons.check_rounded, color: colors.accent, size: 20.sp)
                    : SizedBox(width: 20.sp),
                title: Text(
                  name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () {
                  ref.read(localeProvider.notifier).state = locale;
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Notification tone modal ──

  static void _showNotificationToneModal(
    BuildContext context,
    WidgetRef ref,
    AppColorsTheme colors,
    AppLocalizations l10n,
    UserProfile? profile,
  ) {
    final current = notificationToneFromString(profile?.notificationTone);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardElevated,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notificationTone,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                l10n.notificationToneSubtitle,
                style: TextStyle(
                  color: colors.subtitleText,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              ...NotificationTone.values.map((tone) {
                final isSelected = tone == current;
                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _ToneCard(
                    tone: tone,
                    isSelected: isSelected,
                    colors: colors,
                    l10n: l10n,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (profile == null) return;
                      await saveNotificationTone(
                        db: ref.read(databaseProvider),
                        syncService: ref.read(syncServiceProvider),
                        profile: profile,
                        tone: tone,
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── External links ──

  static Uri _storeReviewUri() {
    // Using platform-appropriate review URLs. These will no-op gracefully
    // if the bundle ID isn't yet published — caller surfaces an error snackbar.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse(
        'https://apps.apple.com/app/id0000000000?action=write-review',
      );
    }
    return Uri.parse(
      'market://details?id=com.mygymbro.app',
    );
  }

  static Future<void> _openExternal(
    BuildContext context,
    Uri uri, {
    required AppColorsTheme colors,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showSnack(context, 'Could not open link', colors);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[launchUrl] $e');
      if (context.mounted) _showSnack(context, 'Could not open link', colors);
    }
  }

  static void _showSnack(
      BuildContext context, String msg, AppColorsTheme colors) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: colors.cardElevated,
      ),
    );
  }

  // ── Clear cache ──

  static Future<void> _clearCache(
      BuildContext context, AppColorsTheme colors) async {
    try {
      await CachedNetworkImage.evictFromCache('');
      await ExerciseGifCache.instance.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (context.mounted) _showSnack(context, 'Cache cleared', colors);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[clearCache] $e');
      if (context.mounted) {
        _showSnack(context, 'Failed to clear cache', colors);
      }
    }
  }

  // ── Delete account dialog ──

  static void _showDeleteAccountDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, AppColorsTheme colors) {
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
          style: TextStyle(
            color: colors.subtitleText,
            fontSize: 14.sp,
          ),
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
                _showSnack(
                  context,
                  'Could not delete account. Please try again.',
                  colors,
                );
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

/// Anatomy gender toggle row with a switch.
class _ToggleRow extends StatelessWidget {

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.colors,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final String activeLabel;
  final String inactiveLabel;
  final AppColorsTheme colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, color: colors.textPrimary, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  value ? activeLabel : inactiveLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colors.subtitleText,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Dark-mode toggle row with a switch.
class _DarkModeRow extends StatelessWidget {

  const _DarkModeRow({
    required this.isDark,
    required this.colors,
    required this.label,
    required this.onChanged,
  });
  final bool isDark;
  final AppColorsTheme colors;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: colors.textPrimary,
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeTrackColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.colors,
    this.subtitle,
    this.isDestructive = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback? onTap;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? colors.danger : colors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () {},
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDestructive
                            ? colors.danger.withValues(alpha: 0.6)
                            : colors.subtitleText,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive
                  ? colors.danger.withValues(alpha: 0.6)
                  : colors.textSecondary,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings row with an inline switch — used for simple on/off toggles
/// like training reminders, rest-timer sound, or community notifications.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final AppColorsTheme colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, color: colors.textPrimary, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weight unit bottom sheet
// Self-contained ConsumerWidget: reads profile directly so it is never
// blocked by a stale/null snapshot from the parent.
// ─────────────────────────────────────────────────────────────────────────────

class _WeightUnitSheet extends ConsumerWidget {
  const _WeightUnitSheet();

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WeightUnitSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    // Watch live so the checkmark updates instantly.
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final current = profile?.weightUnit ?? 'kg';

    return Container(
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['kg', 'lbs'].map((unit) {
              final isSelected = current == unit;
              return ListTile(
                leading: isSelected
                    ? Icon(Icons.check_rounded,
                        color: colors.accent, size: 20.sp)
                    : SizedBox(width: 20.sp),
                title: Text(
                  unit.toUpperCase(),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () async {
                  final dao = ref.read(userProfileDaoProvider);
                  // If no profile row yet, create one with the chosen unit.
                  if (profile == null) {
                    await dao.upsert(UserProfilesCompanion(
                      weightUnit: Value(unit),
                    ));
                  } else {
                    await dao.updateWeightUnit(profile.localId, unit);
                  }
                  // Force the stream provider to re-evaluate immediately.
                  ref.invalidate(userProfileProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body weight bottom sheet — numeric input, respects user's weight unit
// ─────────────────────────────────────────────────────────────────────────────

class _BodyWeightSheet extends ConsumerStatefulWidget {
  const _BodyWeightSheet();

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BodyWeightSheet(),
    );
  }

  @override
  ConsumerState<_BodyWeightSheet> createState() => _BodyWeightSheetState();
}

class _BodyWeightSheetState extends ConsumerState<_BodyWeightSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).valueOrNull;
    final kg = profile?.bodyWeightKg;
    final unit = profile?.weightUnit ?? 'kg';
    final initial = kg == null
        ? ''
        : (unit == 'lbs'
            ? (kg * 2.20462).round().toString()
            : kg.round().toString());
    _ctrl = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    final profile = ref.read(userProfileProvider).valueOrNull;
    final dao = ref.read(userProfileDaoProvider);
    final unit = profile?.weightUnit ?? 'kg';

    double? kg;
    if (raw.isNotEmpty) {
      final parsed = double.tryParse(raw.replaceAll(',', '.'));
      // Clamp to plausible adult range to avoid garbage input poisoning
      // the calorie estimator. Anything outside this clamp is treated as
      // "clear" (null) — the next save attempt can correct it.
      if (parsed != null && parsed > 0) {
        final asKg = unit == 'lbs' ? parsed / 2.20462 : parsed;
        if (asKg >= 20 && asKg <= 300) kg = asKg;
      }
    }

    if (profile == null) {
      await dao.upsert(UserProfilesCompanion(bodyWeightKg: Value(kg)));
    } else {
      await dao.updateBodyWeight(profile.localId, kg);
    }
    ref
      ..invalidate(userProfileProvider)
      ..invalidate(activityStatsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final unit = profile?.weightUnit ?? 'kg';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.bodyWeight,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    suffixText: unit,
                    suffixStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    TextButton(
                      onPressed: _save,
                      child: Text(
                        l10n.save,
                        style: TextStyle(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default rest time bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RestTimeSheet extends ConsumerWidget {
  const _RestTimeSheet();

  static const _options = [30, 60, 90, 120, 180];

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RestTimeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final current = profile?.defaultRestSeconds ?? 90;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _options.map((seconds) {
              final isSelected = current == seconds;
              return ListTile(
                leading: isSelected
                    ? Icon(Icons.check_rounded,
                        color: colors.accent, size: 20.sp)
                    : SizedBox(width: 20.sp),
                title: Text(
                  '${seconds}s',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () async {
                  final dao = ref.read(userProfileDaoProvider);
                  if (profile == null) {
                    await dao.upsert(UserProfilesCompanion(
                      defaultRestSeconds: Value(seconds),
                    ));
                  } else {
                    await dao.updateRestSeconds(profile.localId, seconds);
                  }
                  ref.invalidate(userProfileProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Preview card for a single [NotificationTone] — label, description,
/// and the pinned English example sentence that showcases the voice.
class _ToneCard extends StatelessWidget {

  const _ToneCard({
    required this.tone,
    required this.isSelected,
    required this.colors,
    required this.l10n,
    required this.onTap,
  });
  final NotificationTone tone;
  final bool isSelected;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.textSecondary.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    toneLabel(tone, l10n),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: colors.accent, size: 18.sp),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              toneDescription(tone, l10n),
              style: TextStyle(
                color: colors.subtitleText,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.notificationToneExampleLabel.toUpperCase(),
                    style: TextStyle(
                      color: colors.subtitleText,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    toneExampleSentence(tone),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
