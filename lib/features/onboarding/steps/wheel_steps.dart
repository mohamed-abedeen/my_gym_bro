import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_wheel.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

const _column = Duration(milliseconds: 70);

Widget _title(ObFrame ob, String text) => ob.centered(
      top: 100,
      inset: 24,
      child: Text(text, textAlign: TextAlign.center, style: ob.text(22)),
    );

// ─────────────────────────────────────────────────────────────────────────────
// 07 — Birthdate
// ─────────────────────────────────────────────────────────────────────────────

class BirthdateStep extends ConsumerWidget {
  const BirthdateStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final months = obMonthNames(context);
    final firstYear = ObUnits.firstBirthYear();
    final lastYear = ObUnits.lastBirthYear();

    // Like iOS, a day past the new month's end snaps back to its last day.
    void clampDay(int month, int year) {
      final last = DateTime(year, month + 1, 0).day;
      if (ref.read(onboardingProvider).birthDay > last) {
        notifier.setBirthDay(last);
      }
    }

    return ObArtboard(
      children: [
        _title(ob, l10n.obBirthdateTitle),
        ob.at(
          left: 28,
          top: 465,
          width: 384,
          height: 36,
          child: const ObWheelBar(radius: 8),
        ),
        ob.at(
          left: 58,
          top: 364,
          width: 70,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: 31,
            index: data.birthDay - 1,
            labelBuilder: (i) => '${i + 1}',
            semanticLabel: l10n.obWheelDay,
            onChanged: (i) => notifier.setBirthDay(i + 1),
          ),
        ),
        ob.at(
          left: 125,
          top: 364,
          width: 140,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: 12,
            index: data.birthMonth - 1,
            labelBuilder: (i) => months[i],
            introDelay: _column,
            semanticLabel: l10n.obWheelMonth,
            onChanged: (i) {
              notifier.setBirthMonth(i + 1);
              clampDay(i + 1, ref.read(onboardingProvider).birthYear);
            },
          ),
        ),
        ob.at(
          left: 280,
          top: 364,
          width: 100,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: lastYear - firstYear + 1,
            index: (data.birthYear - firstYear).clamp(0, lastYear - firstYear),
            labelBuilder: (i) => '${firstYear + i}',
            introDelay: _column * 2,
            semanticLabel: l10n.obWheelYear,
            onChanged: (i) {
              notifier.setBirthYear(firstYear + i);
              clampDay(ref.read(onboardingProvider).birthMonth, firstYear + i);
            },
          ),
        ),
        // 16+ only (Terms of Use). Continue stays disabled meanwhile.
        ob.centered(
          top: 628,
          inset: 40,
          child: AnimatedOpacity(
            opacity: data.isOldEnough() ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Text(
              l10n.obAgeTooYoung(OnboardingData.minAge),
              textAlign: TextAlign.center,
              style: ob.text(13,
                  color: AppOnboarding.recovering, lineHeight: 17),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 08 — Height
// ─────────────────────────────────────────────────────────────────────────────

class HeightStep extends ConsumerWidget {
  const HeightStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final cm = ref.watch(onboardingProvider.select((d) => d.heightCm));
    final metric =
        ref.watch(onboardingProvider.select((d) => d.heightMetric));
    final notifier = ref.read(onboardingProvider.notifier);

    return ObArtboard(
      children: [
        _title(ob, l10n.obHeightTitle),
        ob.at(
          left: 168,
          top: 454,
          width: 104,
          height: 44,
          child: const ObWheelBar(),
        ),
        ob.at(
          left: 140,
          top: 357,
          width: 160,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: ObUnits.heightCount(metric: metric),
            index: ObUnits.heightIndex(cm, metric: metric),
            labelBuilder: (i) => ObUnits.heightLabel(i, metric: metric),
            semanticLabel: l10n.obWheelHeight,
            onChanged: (i) =>
                notifier.setHeightCm(ObUnits.cmFromIndex(i, metric: metric)),
          ),
        ),
        ob.at(
          left: 33,
          top: 774,
          width: 374,
          height: 48,
          child: ObUnitToggle(
            firstLabel: l10n.obUnitFt,
            secondLabel: l10n.obUnitCm,
            secondSelected: metric,
            onChanged: (m) => notifier.setHeightMetric(metric: m),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 09 — Weight · 10 — Target weight
// ─────────────────────────────────────────────────────────────────────────────

class WeightStep extends ConsumerWidget {
  const WeightStep({this.target = false, super.key});

  /// true renders the target-weight variant (with the Lose/Gain note).
  final bool target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final metric = data.weightMetric;
    final kg = target ? data.effectiveTargetKg : data.weightKg;
    final (whole, dec) = ObUnits.weightIndexes(kg, metric: metric);
    final min = ObUnits.weightMin(metric: metric);
    final unit = metric ? 'kg' : 'lb';

    void set(int wholeIndex, int decIndex) {
      final next =
          ObUnits.kgFromIndexes(wholeIndex, decIndex, metric: metric);
      target ? notifier.setTargetWeightKg(next) : notifier.setWeightKg(next);
    }

    final diff = data.effectiveTargetKg - data.weightKg;
    final delta = ObUnits.deltaLabel(
      data.weightKg,
      data.effectiveTargetKg,
      metric: metric,
    );

    return ObArtboard(
      children: [
        _title(ob, target ? l10n.obTargetTitle : l10n.obWeightTitle),
        ob.at(
          left: 120,
          top: 437,
          width: 90,
          height: 44,
          child: const ObWheelBar(),
        ),
        ob.at(
          left: 230,
          top: 437,
          width: 90,
          height: 44,
          child: const ObWheelBar(),
        ),
        ob.at(
          left: 120,
          top: 340,
          width: 90,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: ObUnits.weightCount(metric: metric),
            index: whole,
            labelBuilder: (i) => '${min + i}',
            semanticLabel: l10n.obWheelWeight,
            onChanged: (i) => set(i, dec),
          ),
        ),
        ob.at(
          left: 230,
          top: 340,
          width: 90,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: 10,
            index: dec,
            labelBuilder: (i) => '.$i $unit',
            introDelay: _column,
            semanticLabel: l10n.obWheelDecimal,
            onChanged: (i) => set(whole, i),
          ),
        ),
        if (target)
          ob.centered(
            top: 620,
            child: AnimatedOpacity(
              opacity: diff.abs() > 0.05 ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                diff < 0 ? l10n.obLoseAmount(delta) : l10n.obGainAmount(delta),
                style: ob.text(13, color: AppOnboarding.textMuted),
              ),
            ),
          ),
        ob.at(
          left: 33,
          top: 774,
          width: 374,
          height: 48,
          child: ObUnitToggle(
            firstLabel: l10n.obUnitLb,
            secondLabel: l10n.obUnitKg,
            secondSelected: metric,
            onChanged: (m) => notifier.setWeightMetric(metric: m),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 16 — Rest days (only after a real injury)
// ─────────────────────────────────────────────────────────────────────────────

class RestDaysStep extends ConsumerWidget {
  const RestDaysStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final areas = [
      for (final a in InjuryArea.values)
        if (data.injuries.contains(a))
          obMidSentence(context, l10n.injuryLabel(a)),
    ];

    return ObArtboard(
      children: [
        _title(ob, l10n.obRestTitle),
        ob.at(
          left: 160,
          top: 473,
          width: 120,
          height: 44,
          child: const ObWheelBar(),
        ),
        ob.at(
          left: 140,
          top: 376,
          width: 160,
          height: ObWheel.height,
          child: ObWheel(
            itemCount: 14,
            index: data.restDays - 1,
            labelBuilder: (i) => l10n.obRestDays(i + 1),
            semanticLabel: l10n.obWheelRest,
            onChanged: (i) => notifier.setRestDays(i + 1),
          ),
        ),
        if (areas.isNotEmpty)
          ob.at(
            left: 60,
            right: 60,
            top: 660,
            child: ObEntrance(
              delay: const Duration(milliseconds: 300),
              child: Text(
                l10n.obRestNote(areas.join(', '), areas.length),
                textAlign: TextAlign.center,
                style: ob.text(13,
                    color: AppOnboarding.textMuted, lineHeight: 17),
              ),
            ),
          ),
      ],
    );
  }
}
