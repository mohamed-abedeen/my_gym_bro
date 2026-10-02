import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/shared/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Answer vocabularies. Each `wire` value is what lands in `user_profiles`
// (Drift + Supabase, migration 021); the enum name drives the UI.
// ─────────────────────────────────────────────────────────────────────────────

/// Goals step. [art] names the icon pair in `assets/onboarding/`.
enum OnboardingGoal {
  buildMuscle('build_muscle', 'muscle'),
  loseWeight('lose_weight', 'lose'),
  gainStrength('gain_strength', 'strength'),
  stayFit('stay_fit', 'fit');

  const OnboardingGoal(this.wire, this.art);
  final String wire;
  final String art;

  static OnboardingGoal? fromWire(String? v) =>
      values.where((g) => g.wire == v).firstOrNull;
}

/// Muscle-focus step. [fullBody] ("All Body") is exclusive.
enum FocusArea {
  back('back'),
  chest('chest'),
  arms('arms'),
  abs('abs'),
  glutes('glutes'),
  legs('legs'),
  fullBody('full_body');

  const FocusArea(this.wire);
  final String wire;

  static FocusArea? fromWire(String? v) =>
      values.where((a) => a.wire == v).firstOrNull;
}

/// "Do you experience any of the following issues?" — single choice.
enum HealthIssue {
  sitting('prolonged_sitting', 'sitting'),
  sleep('poor_sleep', 'sleep'),
  diet('diet', 'diet'),
  healthy('healthy', 'healthy');

  const HealthIssue(this.wire, this.art);
  final String wire;
  final String art;

  static HealthIssue? fromWire(String? v) =>
      values.where((i) => i.wire == v).firstOrNull;
}

/// Recent-injury body areas. "None" is modelled separately
/// ([OnboardingData.noInjuries]) because it is exclusive, not an area.
enum InjuryArea {
  shoulder,
  back,
  waist,
  wrist,
  knee;

  String get wire => name;

  static InjuryArea? fromWire(String? v) =>
      values.where((a) => a.wire == v).firstOrNull;
}

/// Training experience. [wire] reuses the beginner/intermediate/advanced
/// buckets the server's rivals matcher (`assign_rivals`, migration 015)
/// already orders by.
enum ExperienceLevel {
  rookie('beginner'),
  active('intermediate'),
  expert('advanced');

  const ExperienceLevel(this.wire);
  final String wire;

  static ExperienceLevel? fromWire(String? v) =>
      values.where((e) => e.wire == v).firstOrNull;
}

// ─────────────────────────────────────────────────────────────────────────────
// Flow
// ─────────────────────────────────────────────────────────────────────────────

/// The user's answer on the health-data consent step (GDPR Art. 9: weight,
/// height, target weight, health issues and injuries need explicit consent).
enum HealthConsent {
  /// Checkbox not ticked yet.
  unanswered,

  /// Ticked, then continued: the health questions are asked and saved.
  granted,

  /// "Continue without health data": those questions are skipped and none
  /// of it is stored.
  declined,
}

/// Every step of the onboarding flow after the splash, in order. The live
/// flow is derived from the answers ([OnboardingData.flow]): [restDays] only
/// appears when a real injury was picked, and the health questions drop out
/// when consent was declined.
enum OnboardingStep {
  welcome,
  gender,
  goal,
  goalDetail,
  focus,
  healthConsent,
  section2,
  birthdate,
  height,
  weight,
  target,
  timeline1,
  section3,
  issues,
  issueDetail,
  injuries,
  restDays,
  recovery,
  experience,
  compete,
  trainingDays,
  timeline2,
  paywall;

  /// Filled progress segments (0–4) for the header bar; null on steps that
  /// show no progress bar (welcome, the section interstitials, the paywall).
  double? get progress => switch (this) {
        gender => .12,
        goal => .5,
        goalDetail => .75,
        focus => 1,
        healthConsent => 1.05,
        birthdate => 1.15,
        height => 1.4,
        weight => 1.7,
        target => 1.9,
        timeline1 => 2,
        issues => 2.12,
        issueDetail => 2.25,
        injuries => 2.5,
        restDays => 2.75,
        recovery => 3,
        experience => 3.15,
        compete => 3.3,
        trainingDays => 3.6,
        timeline2 => 4,
        welcome || section2 || section3 || paywall => null,
      };

  bool get isSection => this == section2 || this == section3;

  /// Steps that ask for (or are built from) health data — skipped entirely
  /// without consent.
  static const healthSteps = {
    height,
    weight,
    target,
    timeline1,
    issues,
    issueDetail,
    injuries,
    restDays,
    timeline2,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Prediction
// ─────────────────────────────────────────────────────────────────────────────

/// The target-timeline estimate shown on the timeline steps and the paywall.
///
/// A plain ~0.55 kg/week pace, floored at four weeks, counted from [from].
/// The "optimized" date is the same estimate pulled in by ~4% (at least four
/// days) — the design's "your target is closer than you think" beat.
@immutable
class OnboardingPrediction {
  const OnboardingPrediction._(this.from, this.days, this.soonerDays);

  factory OnboardingPrediction.of({
    required double currentKg,
    required double targetKg,
    DateTime? from,
  }) {
    final days = math.max(
      minDays,
      ((targetKg - currentKg).abs() / kgPerWeek * 7).round(),
    );
    final sooner = math.max(4, (days * 0.04).round());
    final start = from ?? DateTime.now();
    return OnboardingPrediction._(
      DateTime(start.year, start.month, start.day),
      days,
      sooner,
    );
  }

  static const double kgPerWeek = 0.55;
  static const int minDays = 28;

  /// Midnight of the day the estimate counts from.
  final DateTime from;

  /// Days to the target at the plain pace.
  final int days;

  /// How many days the optimized estimate saves.
  final int soonerDays;

  /// Target date at the plain pace (timeline step 1).
  DateTime get date => from.add(Duration(days: days));

  /// The pulled-in date (timeline step 2, paywall, success overlay).
  DateTime get optimizedDate => from.add(Duration(days: days - soonerDays));
}

// ─────────────────────────────────────────────────────────────────────────────
// Answers
// ─────────────────────────────────────────────────────────────────────────────

/// Holds every answer collected during the onboarding flow. Body values are
/// canonical (kg / cm); the unit flags only drive display.
@immutable
class OnboardingData {
  const OnboardingData({
    this.gender,
    this.goal,
    this.focus = const {},
    this.healthConsent = HealthConsent.unanswered,
    this.birthDay = 8,
    this.birthMonth = 4,
    this.birthYear = 2008,
    this.heightCm = 170,
    this.heightMetric = true,
    this.weightKg = 72,
    this.targetWeightKg,
    this.weightMetric = true,
    this.issue,
    this.injuries = const {},
    this.noInjuries = false,
    this.restDays = 3,
    this.experience,
    this.trainingDays = const {},
    this.reminder = true,
  });

  /// 'male' | 'female'.
  final String? gender;
  final OnboardingGoal? goal;
  final Set<FocusArea> focus;

  /// Explicit consent for the health questions (Art. 9 GDPR). Without it
  /// none of the health answers are asked or stored.
  final HealthConsent healthConsent;

  /// Raw wheel values — the day can exceed the month's length until
  /// [birthDate] clamps it.
  final int birthDay;
  final int birthMonth;
  final int birthYear;

  final double heightCm;

  /// true = CM, false = FT/IN.
  final bool heightMetric;

  final double weightKg;

  /// Null until the user touches the target wheel — [effectiveTargetKg]
  /// supplies a goal-aware default meanwhile.
  final double? targetWeightKg;

  /// true = KG, false = LB. Shared by the weight and target steps.
  final bool weightMetric;

  final HealthIssue? issue;
  final Set<InjuryArea> injuries;
  final bool noInjuries;

  /// Planned rest after an injury (1–14). Only meaningful with [injuries].
  final int restDays;

  final ExperienceLevel? experience;

  /// ISO weekdays, Monday = 1 … Sunday = 7 (matches [DateTime.weekday]).
  final Set<int> trainingDays;

  /// Training-reminder switch on the training-days step.
  final bool reminder;

  bool get isFemale => gender == 'female';

  bool get hasRealInjuries => injuries.isNotEmpty;

  bool get hasHealthConsent => healthConsent == HealthConsent.granted;

  /// The wheel date, with the day clamped to the month (31 Feb → 28/29).
  DateTime get birthDate {
    final lastDay = DateTime(birthYear, birthMonth + 1, 0).day;
    return DateTime(birthYear, birthMonth, math.min(birthDay, lastDay));
  }

  /// My Gym Bro is 16+ (Terms of Use; Germany's GDPR age of consent).
  static const int minAge = AppConstants.minUserAge;

  /// Completed years on [today] (defaults to now).
  int ageOn([DateTime? today]) {
    final now = today ?? DateTime.now();
    final born = birthDate;
    final hadBirthday = now.month > born.month ||
        (now.month == born.month && now.day >= born.day);
    return now.year - born.year - (hadBirthday ? 0 : 1);
  }

  bool isOldEnough([DateTime? today]) => ageOn(today) >= minAge;

  /// A starting target that points the right way for the chosen goal.
  double get defaultTargetKg => switch (goal) {
        OnboardingGoal.loseWeight => weightKg - 5,
        OnboardingGoal.buildMuscle => weightKg + 5,
        OnboardingGoal.gainStrength => weightKg + 3,
        OnboardingGoal.stayFit || null => weightKg,
      };

  double get effectiveTargetKg =>
      (targetWeightKg ?? defaultTargetKg).clamp(minWeightKg, maxWeightKg);

  static const double minWeightKg = 30;
  static const double maxWeightKg = 200;

  OnboardingPrediction prediction({DateTime? from}) => OnboardingPrediction.of(
        currentKg: weightKg,
        targetKg: effectiveTargetKg,
        from: from,
      );

  /// The live flow: [OnboardingStep.restDays] only after a real injury, and
  /// none of the health steps once consent was declined.
  List<OnboardingStep> get flow => [
        for (final s in OnboardingStep.values)
          if ((s != OnboardingStep.restDays || hasRealInjuries) &&
              !(healthConsent == HealthConsent.declined &&
                  OnboardingStep.healthSteps.contains(s)))
            s,
      ];

  /// Whether Continue is enabled on [step] — the answer-required steps stay
  /// disabled until something is picked; wheel/info steps always pass. The
  /// consent step needs the box ticked (declining has its own button), and
  /// the birthdate step needs the 16+ age.
  bool canContinue(OnboardingStep step) => switch (step) {
        OnboardingStep.gender => gender != null,
        OnboardingStep.goal => goal != null,
        OnboardingStep.focus => focus.isNotEmpty,
        OnboardingStep.healthConsent => hasHealthConsent,
        OnboardingStep.birthdate => isOldEnough(),
        OnboardingStep.issues => issue != null,
        OnboardingStep.injuries => noInjuries || injuries.isNotEmpty,
        OnboardingStep.experience => experience != null,
        OnboardingStep.trainingDays => trainingDays.isNotEmpty,
        _ => true,
      };

  OnboardingData copyWith({
    String? gender,
    OnboardingGoal? goal,
    Set<FocusArea>? focus,
    HealthConsent? healthConsent,
    int? birthDay,
    int? birthMonth,
    int? birthYear,
    double? heightCm,
    bool? heightMetric,
    double? weightKg,
    double? targetWeightKg,
    bool? weightMetric,
    HealthIssue? issue,
    Set<InjuryArea>? injuries,
    bool? noInjuries,
    int? restDays,
    ExperienceLevel? experience,
    Set<int>? trainingDays,
    bool? reminder,
  }) =>
      OnboardingData(
        gender: gender ?? this.gender,
        goal: goal ?? this.goal,
        focus: focus ?? this.focus,
        healthConsent: healthConsent ?? this.healthConsent,
        birthDay: birthDay ?? this.birthDay,
        birthMonth: birthMonth ?? this.birthMonth,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        heightMetric: heightMetric ?? this.heightMetric,
        weightKg: weightKg ?? this.weightKg,
        targetWeightKg: targetWeightKg ?? this.targetWeightKg,
        weightMetric: weightMetric ?? this.weightMetric,
        issue: issue ?? this.issue,
        injuries: injuries ?? this.injuries,
        noInjuries: noInjuries ?? this.noInjuries,
        restDays: restDays ?? this.restDays,
        experience: experience ?? this.experience,
        trainingDays: trainingDays ?? this.trainingDays,
        reminder: reminder ?? this.reminder,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setGender(String gender) => state = state.copyWith(gender: gender);

  void setGoal(OnboardingGoal goal) => state = state.copyWith(goal: goal);

  /// Multi-select; [FocusArea.fullBody] is exclusive — picking it clears the
  /// rest, picking any single area clears it.
  void toggleFocus(FocusArea area) {
    final next = {...state.focus};
    if (area == FocusArea.fullBody) {
      final wasOn = next.contains(FocusArea.fullBody);
      next.clear();
      if (!wasOn) next.add(FocusArea.fullBody);
    } else {
      next.remove(FocusArea.fullBody);
      if (!next.remove(area)) next.add(area);
    }
    state = state.copyWith(focus: next);
  }

  /// The consent checkbox: ticked ⇔ granted, unticked ⇔ unanswered.
  void toggleHealthConsent() => state = state.copyWith(
        healthConsent: state.hasHealthConsent
            ? HealthConsent.unanswered
            : HealthConsent.granted,
      );

  /// "Continue without health data".
  void declineHealthConsent() =>
      state = state.copyWith(healthConsent: HealthConsent.declined);

  void setBirthDay(int day) => state = state.copyWith(birthDay: day);
  void setBirthMonth(int month) => state = state.copyWith(birthMonth: month);
  void setBirthYear(int year) => state = state.copyWith(birthYear: year);

  void setHeightCm(double cm) => state = state.copyWith(heightCm: cm);

  void setHeightMetric({required bool metric}) =>
      state = state.copyWith(heightMetric: metric);

  void setWeightKg(double kg) => state = state.copyWith(weightKg: kg);

  void setTargetWeightKg(double kg) =>
      state = state.copyWith(targetWeightKg: kg);

  void setWeightMetric({required bool metric}) =>
      state = state.copyWith(weightMetric: metric);

  void setIssue(HealthIssue issue) => state = state.copyWith(issue: issue);

  /// Multi-select; "None" is exclusive the same way as full-body focus.
  void toggleInjury(InjuryArea area) {
    final next = {...state.injuries};
    if (!next.remove(area)) next.add(area);
    state = state.copyWith(injuries: next, noInjuries: false);
  }

  void toggleNoInjuries() => state = state.copyWith(
        injuries: const {},
        noInjuries: !state.noInjuries,
      );

  void setRestDays(int days) => state = state.copyWith(restDays: days);

  void setExperience(ExperienceLevel level) =>
      state = state.copyWith(experience: level);

  void toggleTrainingDay(int weekday) {
    final next = {...state.trainingDays};
    if (!next.remove(weekday)) next.add(weekday);
    state = state.copyWith(trainingDays: next);
  }

  void setReminder({required bool on}) =>
      state = state.copyWith(reminder: on);
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>(
  (ref) => OnboardingNotifier(),
);
