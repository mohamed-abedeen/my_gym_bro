import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/anatomy_body.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import '../../shared/widgets/oc_glass_btn.dart';
import '../../core/security/secure_storage.dart';
import '../workout/workout_providers.dart';

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
                        'Account',
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
                        Row(
                          children: [
                            LiquidGlassButton(
                              width: 68.w,
                              height: 68.w,
                              opacity: 0.65,
                              radius: 296.r,
                              child: profile.when(
                                data: (p) => p?.avatarUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          p!.avatarUrl!,
                                          width: 62.w,
                                          height: 62.w,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Icon(
                                            Icons.person_rounded,
                                            color: colors.textPrimary,
                                            size: 34.sp,
                                          ),
                                        ),
                                      )
                                    : Icon(Icons.person_rounded,
                                        color: colors.textPrimary,
                                        size: 34.sp),
                                loading: () => Icon(Icons.person_rounded,
                                    color: colors.textPrimary, size: 34.sp),
                                error: (_, __) => Icon(
                                    Icons.person_rounded,
                                    color: colors.textPrimary,
                                    size: 34.sp),
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

                        // Subscription row
                        Row(
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
                            Text(
                              l10n.freeTrial,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.subtitleText,
                              ),
                            ),
                          ],
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
                        // Notifications
                        _SettingsRow(
                          icon: Icons.notifications_outlined,
                          label: l10n.notificationsSection,
                          colors: colors,
                        ),
                        _settingsDivider(colors),
                        // Training Reminders
                        _SettingsRow(
                          icon: Icons.alarm_rounded,
                          label: l10n.trainingReminders,
                          colors: colors,
                        ),
                        _settingsDivider(colors),
                        // Rest Timer Sound
                        _SettingsRow(
                          icon: Icons.volume_up_rounded,
                          label: l10n.restTimerSound,
                          colors: colors,
                        ),
                        _settingsDivider(colors),
                        // Community Notifications
                        _SettingsRow(
                          icon: Icons.people_outline_rounded,
                          label: l10n.communityNotifications,
                          colors: colors,
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
                          onTap: () => _showWeightUnitModal(context, ref, colors, profile.value),
                        ),
                        _settingsDivider(colors),
                        // Default Rest Time
                        _SettingsRow(
                          icon: Icons.timer_outlined,
                          label: l10n.defaultRestTime,
                          subtitle: '${profile.whenData((p) => p?.defaultRestSeconds ?? 90).value ?? 90}s',
                          colors: colors,
                          onTap: () => _showRestTimeModal(context, ref, colors, profile.value),
                        ),
                        _settingsDivider(colors),
                        // Rate the App
                        _SettingsRow(
                          icon: Icons.star_outline_rounded,
                          label: l10n.rateApp,
                          colors: colors,
                        ),
                        _settingsDivider(colors),
                        // Contact Support
                        _SettingsRow(
                          icon: Icons.mail_outline_rounded,
                          label: l10n.contactSupport,
                          colors: colors,
                        ),
                        _settingsDivider(colors),
                        // Privacy Policy
                        _SettingsRow(
                          icon: Icons.shield_outlined,
                          label: l10n.privacyPolicy,
                          colors: colors,
                        ),
                        _settingsDivider(colors),
                        // Terms of Service
                        _SettingsRow(
                          icon: Icons.description_outlined,
                          label: l10n.termsOfService,
                          colors: colors,
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

                  // Version
                  Center(
                    child: Text(
                      l10n.appVersion('1.0.0'),
                      style: TextStyle(
                        color: colors.subtitleText,
                        fontSize: 12.sp,
                      ),
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

    showModalBottomSheet(
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

  // ── Weight unit modal ──

  static void _showWeightUnitModal(BuildContext context, WidgetRef ref,
      AppColorsTheme colors, UserProfile? profile) {
    if (profile == null) return;
    final currentUnit = profile.weightUnit;

    showModalBottomSheet(
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
            children: ['kg', 'lbs'].map((unit) {
              final isSelected = currentUnit == unit;
              return ListTile(
                leading: isSelected
                    ? Icon(Icons.check_rounded, color: colors.accent, size: 20.sp)
                    : SizedBox(width: 20.sp),
                title: Text(
                  unit.toUpperCase(),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () {
                  ref
                      .read(userProfileDaoProvider)
                      .updateWeightUnit(profile.localId, unit);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Default rest time modal ──

  static void _showRestTimeModal(BuildContext context, WidgetRef ref,
      AppColorsTheme colors, UserProfile? profile) {
    if (profile == null) return;
    final currentSeconds = profile.defaultRestSeconds;
    final options = [30, 60, 90, 120];

    showModalBottomSheet(
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
            children: options.map((seconds) {
              final isSelected = currentSeconds == seconds;
              return ListTile(
                leading: isSelected
                    ? Icon(Icons.check_rounded, color: colors.accent, size: 20.sp)
                    : SizedBox(width: 20.sp),
                title: Text(
                  '${seconds}s',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () {
                  ref
                      .read(userProfileDaoProvider)
                      .updateRestSeconds(profile.localId, seconds);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Delete account dialog ──

  static void _showDeleteAccountDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, AppColorsTheme colors) {
    showDialog(
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
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
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
  final IconData icon;
  final String label;
  final bool value;
  final String activeLabel;
  final String inactiveLabel;
  final AppColorsTheme colors;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.colors,
    required this.onChanged,
  });

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
            activeColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Dark-mode toggle row with a switch.
class _DarkModeRow extends StatelessWidget {
  final bool isDark;
  final AppColorsTheme colors;
  final String label;
  final ValueChanged<bool> onChanged;

  const _DarkModeRow({
    required this.isDark,
    required this.colors,
    required this.label,
    required this.onChanged,
  });

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
            activeColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback? onTap;
  final AppColorsTheme colors;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.colors,
    this.subtitle,
    this.isDestructive = false,
    this.onTap,
  });

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
