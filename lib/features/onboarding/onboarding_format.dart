import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Unit math and display strings for the onboarding wheels, timeline and
/// paywall. Body values are canonical kg / cm; everything here converts at
/// the edges.
class ObUnits {
  ObUnits._();

  // ── Weight wheels: whole part + a .0–.9 decimal column ──
  static const int minKg = 30;
  static const int maxKg = 200;
  static const int minLb = 66;
  static const int maxLb = 440;

  static int weightMin({required bool metric}) => metric ? minKg : minLb;

  static int weightCount({required bool metric}) =>
      metric ? maxKg - minKg + 1 : maxLb - minLb + 1;

  /// [kg] in the display unit, rounded to the wheels' 0.1 step.
  static double displayWeight(double kg, {required bool metric}) {
    final v = metric ? kg : kg * kLbsPerKg;
    return (v * 10).round() / 10;
  }

  /// (whole-part index, decimal index) for the two weight columns.
  static (int, int) weightIndexes(double kg, {required bool metric}) {
    final v = displayWeight(kg, metric: metric);
    final min = weightMin(metric: metric);
    final count = weightCount(metric: metric);
    final whole = v.floor().clamp(min, min + count - 1);
    final dec = ((v - v.floor()) * 10).round().clamp(0, 9);
    return (whole - min, dec);
  }

  /// Canonical kg for a (whole index, decimal index) pair.
  static double kgFromIndexes(
    int wholeIndex,
    int decIndex, {
    required bool metric,
  }) {
    final v = weightMin(metric: metric) + wholeIndex + decIndex / 10;
    return metric ? v : v / kLbsPerKg;
  }

  // ── Height wheel: 120–230 cm or 4′0″–7′6″ (48–90 in) ──
  static const int minCm = 120;
  static const int maxCm = 230;
  static const int minIn = 48;
  static const int maxIn = 90;

  static int heightCount({required bool metric}) =>
      metric ? maxCm - minCm + 1 : maxIn - minIn + 1;

  static int heightIndex(double cm, {required bool metric}) => metric
      ? (cm.round() - minCm).clamp(0, maxCm - minCm)
      : ((cm / 2.54).round() - minIn).clamp(0, maxIn - minIn);

  static double cmFromIndex(int index, {required bool metric}) =>
      metric ? (minCm + index).toDouble() : (minIn + index) * 2.54;

  static String heightLabel(int index, {required bool metric}) {
    if (metric) return '${minCm + index} cm';
    final inches = minIn + index;
    return '${inches ~/ 12}′ ${inches % 12}″';
  }

  // ── Birth year: 90 years back to the minimum age's year. Someone turning
  // 16 later this year can still pick it; the step's age check blocks them.
  static int firstBirthYear([DateTime? now]) =>
      (now ?? DateTime.now()).year - 90;
  static int lastBirthYear([DateTime? now]) =>
      (now ?? DateTime.now()).year - OnboardingData.minAge;

  // ── Display strings ──

  /// "157.9 kg" / "72 kg" / "160.3 lb" — the timeline's today/target labels.
  static String weightLabel(double kg, {required bool metric}) {
    final v = displayWeight(kg, metric: metric);
    final s = v.toStringAsFixed(1);
    final clean = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    return '${groupDigits(clean)} ${metric ? 'kg' : 'lb'}';
  }

  /// "88Kg" / "194Lb" — the timeline headline (whole part only).
  static String headlineWeight(double kg, {required bool metric}) {
    final v = displayWeight(kg, metric: metric).floor();
    return '${groupDigits('$v')}${metric ? 'Kg' : 'Lb'}';
  }

  /// "16.0 kg" — the target step's Lose / Gain amount.
  static String deltaLabel(double fromKg, double toKg, {required bool metric}) {
    final d = (displayWeight(toKg, metric: metric) -
            displayWeight(fromKg, metric: metric))
        .abs();
    return '${groupDigits(d.toStringAsFixed(1))} ${metric ? 'kg' : 'lb'}';
  }
}

/// "Jun 23" / "23. Juni" / "23 jun" / "23 juin".
String obShortDate(BuildContext context, DateTime date) =>
    DateFormat.MMMd(Localizations.localeOf(context).toString()).format(date);

/// Full month names for the birthdate wheel (index 0 = January).
List<String> obMonthNames(BuildContext context) {
  final f = DateFormat.MMMM(Localizations.localeOf(context).toString());
  return [for (var m = 1; m <= 12; m++) f.format(DateTime(2000, m))];
}

/// Localized weekday name for an ISO weekday (Monday = 1), capitalised as a
/// standalone label (Spanish/French names come back lowercase).
String obWeekdayName(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toString();
  // 2024-01-01 was a Monday.
  final name = DateFormat.EEEE(locale).format(DateTime(2024, 1, weekday));
  return toBeginningOfSentenceCase(name, locale);
}

/// A label used mid-sentence ("We'll keep your knee, back out of…"):
/// lowercased, except in German, which capitalises nouns.
String obMidSentence(BuildContext context, String label) =>
    Localizations.localeOf(context).languageCode == 'de'
        ? label
        : label.toLowerCase();

/// Splits a localized template around one highlighted placeholder so the
/// value can be styled on its own, whatever the language's word order.
///
/// [build] receives a sentinel and must return the localized string with the
/// sentinel in the placeholder's position.
List<InlineSpan> obHighlight({
  required String Function(String placeholder) build,
  required String value,
  required TextStyle highlight,
}) {
  const sentinel = '\u0000';
  final parts = build(sentinel).split(sentinel);
  return [
    TextSpan(text: parts.first),
    TextSpan(text: value, style: highlight),
    if (parts.length > 1) TextSpan(text: parts.sublist(1).join(value)),
  ];
}

/// The localized copy for each answer, shared by the steps and the paywall.
extension ObLabels on AppLocalizations {
  String goalLabel(OnboardingGoal g) => switch (g) {
        OnboardingGoal.buildMuscle => obGoalBuildMuscle,
        OnboardingGoal.loseWeight => obGoalLoseWeight,
        OnboardingGoal.gainStrength => obGoalGainStrength,
        OnboardingGoal.stayFit => obGoalStayFit,
      };

  String goalHead(OnboardingGoal g) => switch (g) {
        OnboardingGoal.buildMuscle => obGoalBuildMuscleHead,
        OnboardingGoal.loseWeight => obGoalLoseWeightHead,
        OnboardingGoal.gainStrength => obGoalGainStrengthHead,
        OnboardingGoal.stayFit => obGoalStayFitHead,
      };

  String goalBody(OnboardingGoal g) => switch (g) {
        OnboardingGoal.buildMuscle => obGoalBuildMuscleBody,
        OnboardingGoal.loseWeight => obGoalLoseWeightBody,
        OnboardingGoal.gainStrength => obGoalGainStrengthBody,
        OnboardingGoal.stayFit => obGoalStayFitBody,
      };

  String focusLabel(FocusArea a) => switch (a) {
        FocusArea.back => obFocusBack,
        FocusArea.chest => obFocusChest,
        FocusArea.arms => obFocusArms,
        FocusArea.abs => obFocusAbs,
        FocusArea.glutes => obFocusGlutes,
        FocusArea.legs => obFocusLegs,
        FocusArea.fullBody => obFocusFullBody,
      };

  String issueLabel(HealthIssue i) => switch (i) {
        HealthIssue.sitting => obIssueSitting,
        HealthIssue.sleep => obIssueSleep,
        HealthIssue.diet => obIssueDiet,
        HealthIssue.healthy => obIssueHealthy,
      };

  String issueHead(HealthIssue i) => switch (i) {
        HealthIssue.sitting => obIssueSittingHead,
        HealthIssue.sleep => obIssueSleepHead,
        HealthIssue.diet => obIssueDietHead,
        HealthIssue.healthy => obIssueHealthyHead,
      };

  String issueBody(HealthIssue i) => switch (i) {
        HealthIssue.sitting => obIssueSittingBody,
        HealthIssue.sleep => obIssueSleepBody,
        HealthIssue.diet => obIssueDietBody,
        HealthIssue.healthy => obIssueHealthyBody,
      };

  String injuryLabel(InjuryArea a) => switch (a) {
        InjuryArea.shoulder => obInjuryShoulder,
        InjuryArea.back => obInjuryBack,
        InjuryArea.waist => obInjuryWaist,
        InjuryArea.wrist => obInjuryWrist,
        InjuryArea.knee => obInjuryKnee,
      };

  String experienceLabel(ExperienceLevel e) => switch (e) {
        ExperienceLevel.rookie => obExpRookie,
        ExperienceLevel.active => obExpActive,
        ExperienceLevel.expert => obExpExpert,
      };

  String experienceSub(ExperienceLevel e) => switch (e) {
        ExperienceLevel.rookie => obExpRookieSub,
        ExperienceLevel.active => obExpActiveSub,
        ExperienceLevel.expert => obExpExpertSub,
      };
}
