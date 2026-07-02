import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// Floating frosted bottom sheets for the redesigned settings screen.
///
/// All sheets share [_SheetShell]: a floating glass panel (frosted
/// [GlassSurface], per the glass system) with a drag handle and title.

// ─────────────────────────────────────────────────────────────────────────────
// Shared shell
// ─────────────────────────────────────────────────────────────────────────────

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h + bottomInset),
      child: SafeArea(
        top: false,
        child: GlassSurface(
          radius: 30.r,
          blurSigma: AppGlass.blurStrong,
          tint: colors.panelBackground.withValues(alpha: isDark ? 0.72 : 0.78),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colors.subtitleText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 3.h),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: colors.subtitleText,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
                SizedBox(height: 14.h),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showGlassSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: builder,
  );
}

/// Checkmark option row used by list-style sheets.
class _SheetOptionRow extends StatelessWidget {
  const _SheetOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.14)
              : colors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? colors.accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: colors.accent, size: 18.sp),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language
// ─────────────────────────────────────────────────────────────────────────────

/// Human-readable name for a locale option (null = follow system).
String localeDisplayName(Locale? locale, AppLocalizations l10n) {
  if (locale == null) return l10n.languageSystem;
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

void showLanguageSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  const options = <Locale?>[
    null,
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
  ];

  _showGlassSheet(context, (ctx) {
    final current = ref.read(localeProvider);
    return _SheetShell(
      title: l10n.language,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final locale in options)
            _SheetOptionRow(
              label: localeDisplayName(locale, l10n),
              selected: current == locale,
              onTap: () async {
                ref.read(localeProvider.notifier).state = locale;
                Navigator.of(ctx).pop();
                // Persist so the choice survives a restart (main.dart reads
                // profile.preferredLanguage before the first frame).
                final code = locale?.languageCode ?? 'system';
                final dao = ref.read(userProfileDaoProvider);
                final profile =
                    ref.read(userProfileProvider).valueOrNull;
                if (profile == null) {
                  await dao.upsert(
                    UserProfilesCompanion(preferredLanguage: Value(code)),
                  );
                } else {
                  await dao.updateLanguage(profile.localId, code);
                }
              },
            ),
        ],
      ),
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Default rest time — chips grid
// ─────────────────────────────────────────────────────────────────────────────

class RestTimeSheet extends ConsumerWidget {
  const RestTimeSheet({super.key});

  static const _options = [30, 45, 60, 90, 120, 150, 180, 240];

  static void show(BuildContext context) {
    _showGlassSheet(context, (_) => const RestTimeSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final current = profile?.defaultRestSeconds ?? 90;

    return _SheetShell(
      title: l10n.defaultRestTime,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: _options.map((seconds) {
          final selected = current == seconds;
          return GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              final dao = ref.read(userProfileDaoProvider);
              if (profile == null) {
                await dao.upsert(
                  UserProfilesCompanion(defaultRestSeconds: Value(seconds)),
                );
              } else {
                await dao.updateRestSeconds(profile.localId, seconds);
              }
              ref.invalidate(userProfileProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selected
                    ? colors.accent
                    : colors.textSecondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                seconds < 60
                    ? '${seconds}s'
                    : (seconds % 60 == 0
                        ? '${seconds ~/ 60}:00'
                        : '${seconds ~/ 60}:${seconds % 60}'),
                style: TextStyle(
                  color: selected ? colors.todayPillText : colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body weight — numeric input, respects the user's weight unit
// ─────────────────────────────────────────────────────────────────────────────

class BodyWeightSheet extends ConsumerStatefulWidget {
  const BodyWeightSheet({super.key});

  static void show(BuildContext context) {
    _showGlassSheet(context, (_) => const BodyWeightSheet());
  }

  @override
  ConsumerState<BodyWeightSheet> createState() => _BodyWeightSheetState();
}

class _BodyWeightSheetState extends ConsumerState<BodyWeightSheet> {
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

    return _SheetShell(
      title: l10n.bodyWeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          SizedBox(height: 18.h),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification tone
// ─────────────────────────────────────────────────────────────────────────────

void showNotificationToneSheet(
  BuildContext context,
  WidgetRef ref,
  UserProfile? profile,
) {
  final l10n = AppLocalizations.of(context);
  final current = notificationToneFromString(profile?.notificationTone);

  _showGlassSheet(context, (ctx) {
    final colors = AppColors.of(ctx);
    return _SheetShell(
      title: l10n.notificationTone,
      subtitle: l10n.notificationToneSubtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: NotificationTone.values.map((tone) {
          final isSelected = tone == current;
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
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
        }).toList(),
      ),
    );
  });
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.10)
              : colors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? colors.accent : Colors.transparent,
            width: 1.2,
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
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: colors.accent, size: 17.sp),
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
            SizedBox(height: 8.h),
            Text(
              '“${toneExampleSentence(tone)}”',
              style: TextStyle(
                color: colors.textPrimary.withValues(alpha: 0.85),
                fontSize: 12.5.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
