import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';

void main() {
  group('flow', () {
    test('rest days only appear after a real injury', () {
      const none = OnboardingData(noInjuries: true);
      expect(none.flow, isNot(contains(OnboardingStep.restDays)));

      const hurt = OnboardingData(injuries: {InjuryArea.knee});
      final flow = hurt.flow;
      expect(flow, contains(OnboardingStep.restDays));
      expect(
        flow.indexOf(OnboardingStep.restDays),
        flow.indexOf(OnboardingStep.injuries) + 1,
      );
    });

    test('runs welcome → paywall with both section interstitials', () {
      final flow = const OnboardingData().flow;
      expect(flow.first, OnboardingStep.welcome);
      expect(flow.last, OnboardingStep.paywall);
      expect(flow.where((s) => s.isSection), hasLength(2));
    });

    test('consent comes before the body-data section', () {
      final flow = const OnboardingData().flow;
      expect(
        flow.indexOf(OnboardingStep.healthConsent),
        flow.indexOf(OnboardingStep.section2) - 1,
      );
    });

    test('declining consent drops every health step, nothing else', () {
      const declined = OnboardingData(
        healthConsent: HealthConsent.declined,
        injuries: {InjuryArea.knee},
      );
      final flow = declined.flow;
      for (final s in OnboardingStep.healthSteps) {
        expect(flow, isNot(contains(s)), reason: '$s');
      }
      // Birthdate stays: age isn't health data and gates the flow.
      expect(flow, containsAll([
        OnboardingStep.healthConsent,
        OnboardingStep.section2,
        OnboardingStep.birthdate,
        OnboardingStep.section3,
        OnboardingStep.recovery,
        OnboardingStep.experience,
        OnboardingStep.compete,
        OnboardingStep.trainingDays,
        OnboardingStep.paywall,
      ]));
    });

    test('progress climbs monotonically and ends full', () {
      final values = [
        for (final s in const OnboardingData(injuries: {InjuryArea.back}).flow)
          if (s.progress != null) s.progress!,
      ];
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
      expect(values.last, 4);
    });

    test('Continue waits for an answer on the choice steps only', () {
      const empty = OnboardingData();
      for (final step in [
        OnboardingStep.gender,
        OnboardingStep.goal,
        OnboardingStep.focus,
        OnboardingStep.healthConsent,
        OnboardingStep.issues,
        OnboardingStep.injuries,
        OnboardingStep.experience,
        OnboardingStep.trainingDays,
      ]) {
        expect(empty.canContinue(step), isFalse, reason: '$step');
      }
      for (final step in [
        OnboardingStep.birthdate,
        OnboardingStep.height,
        OnboardingStep.weight,
        OnboardingStep.target,
        OnboardingStep.timeline1,
        OnboardingStep.recovery,
        OnboardingStep.compete,
      ]) {
        expect(empty.canContinue(step), isTrue, reason: '$step');
      }

      const answered = OnboardingData(
        gender: 'female',
        goal: OnboardingGoal.stayFit,
        focus: {FocusArea.legs},
        healthConsent: HealthConsent.granted,
        issue: HealthIssue.healthy,
        noInjuries: true,
        experience: ExperienceLevel.rookie,
        trainingDays: {2},
      );
      for (final step in OnboardingStep.values) {
        expect(answered.canContinue(step), isTrue, reason: '$step');
      }
    });
  });

  group('consent and age', () {
    test('the box ticks and unticks; declining is its own answer', () {
      final n = OnboardingNotifier()..toggleHealthConsent();
      expect(n.state.healthConsent, HealthConsent.granted);
      expect(n.state.canContinue(OnboardingStep.healthConsent), isTrue);

      n.toggleHealthConsent();
      expect(n.state.healthConsent, HealthConsent.unanswered);
      expect(n.state.canContinue(OnboardingStep.healthConsent), isFalse);

      n.declineHealthConsent();
      expect(n.state.healthConsent, HealthConsent.declined);
      // Coming back and ticking the box brings the questions back.
      n.toggleHealthConsent();
      expect(n.state.healthConsent, HealthConsent.granted);
      expect(n.state.flow, contains(OnboardingStep.weight));
    });

    test('16 on the birthday itself, 15 the day before', () {
      const born = OnboardingData(birthDay: 30, birthMonth: 9, birthYear: 2010);
      expect(born.ageOn(DateTime(2026, 9, 30)), 16);
      expect(born.ageOn(DateTime(2026, 9, 29)), 15);
      expect(born.isOldEnough(DateTime(2026, 9, 30)), isTrue);
      expect(born.isOldEnough(DateTime(2026, 9, 29)), isFalse);
    });

    test('the birthdate step blocks under-16s', () {
      final now = DateTime.now();
      final tooYoung = OnboardingData(
        birthDay: 1,
        birthMonth: 1,
        birthYear: now.year - OnboardingData.minAge + 1,
      );
      expect(tooYoung.canContinue(OnboardingStep.birthdate), isFalse);
      expect(
        const OnboardingData().canContinue(OnboardingStep.birthdate),
        isTrue,
        reason: 'the default (8 April 2008) is 18+',
      );
      // The wheel's newest year is the minimum age's year.
      expect(ObUnits.lastBirthYear(now), now.year - OnboardingData.minAge);
    });
  });

  group('exclusive choices', () {
    test('All Body clears single areas, and a single area clears All Body',
        () {
      final n = OnboardingNotifier()
        ..toggleFocus(FocusArea.back)
        ..toggleFocus(FocusArea.chest);
      expect(n.state.focus, {FocusArea.back, FocusArea.chest});

      n.toggleFocus(FocusArea.fullBody);
      expect(n.state.focus, {FocusArea.fullBody});

      n.toggleFocus(FocusArea.arms);
      expect(n.state.focus, {FocusArea.arms});

      n
        ..toggleFocus(FocusArea.fullBody)
        ..toggleFocus(FocusArea.fullBody);
      expect(n.state.focus, isEmpty);
    });

    test('"None" clears injuries, and an injury clears "None"', () {
      final n = OnboardingNotifier()
        ..toggleInjury(InjuryArea.knee)
        ..toggleInjury(InjuryArea.wrist);
      expect(n.state.injuries, {InjuryArea.knee, InjuryArea.wrist});

      n.toggleNoInjuries();
      expect(n.state.injuries, isEmpty);
      expect(n.state.noInjuries, isTrue);

      n.toggleInjury(InjuryArea.back);
      expect(n.state.noInjuries, isFalse);
      expect(n.state.injuries, {InjuryArea.back});
    });
  });

  group('prediction', () {
    final today = DateTime(2026, 9, 29, 15, 30);

    test('0.55 kg a week, never under four weeks', () {
      final big = OnboardingPrediction.of(
        currentKg: 72,
        targetKg: 88,
        from: today,
      );
      // 16 kg / 0.55 kg per week × 7 = 203.6 → 204 days.
      expect(big.days, 204);
      expect(big.date, DateTime(2027, 4, 21));

      final tiny = OnboardingPrediction.of(
        currentKg: 72,
        targetKg: 71,
        from: today,
      );
      expect(tiny.days, OnboardingPrediction.minDays);
    });

    test('the optimized date is ~4% sooner, at least four days', () {
      final p = OnboardingPrediction.of(
        currentKg: 72,
        targetKg: 88,
        from: today,
      );
      expect(p.soonerDays, 8); // round(204 × .04)
      expect(p.optimizedDate, DateTime(2027, 4, 13));

      final floor = OnboardingPrediction.of(
        currentKg: 72,
        targetKg: 72,
        from: today,
      );
      expect(floor.soonerDays, 4);
    });

    test('counts from midnight regardless of the hour', () {
      final p = OnboardingPrediction.of(
        currentKg: 80,
        targetKg: 80,
        from: today,
      );
      expect(p.from, DateTime(2026, 9, 29));
    });
  });

  group('answers', () {
    test('target defaults point the right way for the goal', () {
      expect(
        const OnboardingData(weightKg: 80, goal: OnboardingGoal.loseWeight)
            .effectiveTargetKg,
        75,
      );
      expect(
        const OnboardingData(weightKg: 80, goal: OnboardingGoal.buildMuscle)
            .effectiveTargetKg,
        85,
      );
      expect(
        const OnboardingData(weightKg: 80, goal: OnboardingGoal.stayFit)
            .effectiveTargetKg,
        80,
      );
      // A picked target wins; both stay inside the wheel's range.
      expect(
        const OnboardingData(weightKg: 80, targetWeightKg: 90)
            .effectiveTargetKg,
        90,
      );
      expect(
        const OnboardingData(weightKg: 32, goal: OnboardingGoal.loseWeight)
            .effectiveTargetKg,
        OnboardingData.minWeightKg,
      );
    });

    test('birth date clamps the day to the month', () {
      const feb = OnboardingData(birthDay: 31, birthMonth: 2, birthYear: 2012);
      expect(feb.birthDate, DateTime(2012, 2, 29));
      const jun = OnboardingData(birthDay: 31, birthMonth: 6, birthYear: 2001);
      expect(jun.birthDate, DateTime(2001, 6, 30));
    });

    test('wire values round-trip', () {
      for (final g in OnboardingGoal.values) {
        expect(OnboardingGoal.fromWire(g.wire), g);
      }
      for (final a in FocusArea.values) {
        expect(FocusArea.fromWire(a.wire), a);
      }
      for (final i in HealthIssue.values) {
        expect(HealthIssue.fromWire(i.wire), i);
      }
      for (final e in ExperienceLevel.values) {
        expect(ExperienceLevel.fromWire(e.wire), e);
      }
      // Experience reuses the rivals matcher's buckets (migration 015).
      expect(
        ExperienceLevel.values.map((e) => e.wire),
        ['beginner', 'intermediate', 'advanced'],
      );
    });
  });

  group('units', () {
    test('weight wheels round-trip kg and lb at 0.1 precision', () {
      for (final kg in [30.0, 72.0, 72.7, 157.9, 200.0]) {
        final (whole, dec) = ObUnits.weightIndexes(kg, metric: true);
        expect(
          ObUnits.kgFromIndexes(whole, dec, metric: true),
          closeTo(kg, 1e-9),
        );
      }
      // 72 kg = 158.7 lb; picking 158.7 lb comes back as ~72 kg.
      final (whole, dec) = ObUnits.weightIndexes(72, metric: false);
      expect(ObUnits.weightMin(metric: false) + whole, 158);
      expect(dec, 7);
      expect(
        ObUnits.kgFromIndexes(whole, dec, metric: false),
        closeTo(72, 0.05),
      );
    });

    test('height wheel converts between cm and feet/inches', () {
      final i = ObUnits.heightIndex(170, metric: false);
      expect(ObUnits.heightLabel(i, metric: false), '5′ 7″');
      expect(ObUnits.cmFromIndex(i, metric: false), closeTo(170.18, 0.01));
      expect(
        ObUnits.heightLabel(ObUnits.heightIndex(200, metric: true),
            metric: true),
        '200 cm',
      );
    });

    test('labels group digits and drop a trailing .0', () {
      expect(ObUnits.weightLabel(72, metric: true), '72 kg');
      expect(ObUnits.weightLabel(157.94, metric: true), '157.9 kg');
      expect(ObUnits.headlineWeight(88.6, metric: true), '88Kg');
      expect(ObUnits.deltaLabel(72, 88, metric: true), '16.0 kg');
    });
  });
}
