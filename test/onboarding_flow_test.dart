import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_flow_screen.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<ProviderContainer> pumpFlow(
    WidgetTester tester,
    OnboardingStep step,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingFlowScreen(initialStep: step),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  /// Push transitions take .42s; pump past them (no pumpAndSettle — some
  /// steps pulse forever).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text(l10n.continueButton));
    await settle(tester);
  }

  testWidgets('Continue waits for a gender, then moves on to goals',
      (tester) async {
    final container = await pumpFlow(tester, OnboardingStep.gender);

    await tapContinue(tester);
    expect(find.text(l10n.selectGender), findsOneWidget);
    expect(find.text(l10n.obGoalsTitle), findsNothing);

    await tester.tap(find.text(l10n.male));
    await tester.pump();
    expect(container.read(onboardingProvider).gender, 'male');

    await tapContinue(tester);
    expect(find.text(l10n.obGoalsTitle), findsOneWidget);
    expect(find.text(l10n.selectGender), findsNothing);

    // Header back returns to the previous step.
    await tester.tap(find.byType(ObBackButton));
    await settle(tester);
    expect(find.text(l10n.selectGender), findsOneWidget);
  });

  testWidgets('a real injury inserts the rest-days step; "None" skips it',
      (tester) async {
    await pumpFlow(tester, OnboardingStep.injuries);

    await tester.tap(find.text(l10n.obInjuryKnee));
    await tester.pump();
    await tapContinue(tester);
    expect(find.text(l10n.obRestTitle), findsOneWidget);

    await tester.tap(find.byType(ObBackButton));
    await settle(tester);
    await tester.tap(find.text(l10n.obInjuryNone));
    await tester.pump();
    await tapContinue(tester);
    expect(find.text(l10n.obRestTitle), findsNothing);
    expect(find.text(l10n.obRecoveryTitle), findsOneWidget);
  });

  testWidgets('back skips the section interstitial', (tester) async {
    await pumpFlow(tester, OnboardingStep.birthdate);

    await tester.tap(find.byType(ObBackButton));
    await settle(tester);

    expect(find.text(l10n.obSectionBodyData), findsNothing);
    expect(find.text(l10n.obConsentTitle), findsOneWidget);
  });

  testWidgets('consent: Continue needs the box ticked', (tester) async {
    await pumpFlow(tester, OnboardingStep.healthConsent);

    await tapContinue(tester);
    expect(find.text(l10n.obConsentTitle), findsOneWidget);

    // The test font's glyphs are wide, so the middle block scrolls here
    // (as it would with large system text).
    await tester.ensureVisible(find.text(l10n.obConsentAgree));
    await tester.pump();
    await tester.tap(find.text(l10n.obConsentAgree));
    await tester.pump();
    await tapContinue(tester);
    expect(find.text(l10n.obConsentTitle), findsNothing);
    expect(find.text(l10n.obSectionBodyData), findsOneWidget);
  });

  testWidgets('declining consent skips every health question',
      (tester) async {
    final container = await pumpFlow(tester, OnboardingStep.healthConsent);

    await tester.tap(find.text(l10n.obConsentDecline));
    await settle(tester);
    expect(
      container.read(onboardingProvider).healthConsent,
      HealthConsent.declined,
    );

    // Section 2 → birthdate (age isn't health data), then straight on to
    // section 3 and the recovery explainer — no height/weight/issues.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text(l10n.obBirthdateTitle), findsOneWidget);

    await tapContinue(tester);
    expect(find.text(l10n.obSectionAboutYou), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text(l10n.obRecoveryTitle), findsOneWidget);
  });

  testWidgets('under-16s can’t get past the birthdate', (tester) async {
    final container = await pumpFlow(tester, OnboardingStep.birthdate);
    final now = DateTime.now();
    container.read(onboardingProvider.notifier)
      ..setBirthDay(1)
      ..setBirthMonth(1)
      ..setBirthYear(now.year - OnboardingData.minAge + 1);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text(l10n.obAgeTooYoung(OnboardingData.minAge)),
      findsOneWidget,
    );
    await tapContinue(tester);
    expect(find.text(l10n.obBirthdateTitle), findsOneWidget);
    expect(find.text(l10n.obHeightTitle), findsNothing);
  });

  testWidgets('a section interstitial moves on by itself', (tester) async {
    final container = await pumpFlow(tester, OnboardingStep.healthConsent);
    container.read(onboardingProvider.notifier).toggleHealthConsent();
    await tester.pump();

    await tapContinue(tester);
    expect(find.text(l10n.obSectionBodyData), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text(l10n.obBirthdateTitle), findsOneWidget);
  });
}
