import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/features/paywall/paywall_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// The paywall inside a real localized MaterialApp with the app's color
/// theme extension, the gate overridden and no local profile.
Widget _app({required bool locked}) => ProviderScope(
      overrides: [
        subscriptionLockedProvider.overrideWithValue(locked),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColorsTheme.dark]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PaywallScreen(),
      ),
    );

/// A minimal RevenueCat offerings payload: one annual package whose product
/// id matches the paywall's default (yearly) selection.
Map<String, Object?> _offeringsJson() {
  final package = <String, Object?>{
    'identifier': r'$rc_annual',
    'packageType': 'ANNUAL',
    'product': <String, Object?>{
      'identifier': 'mgb_premium_annual',
      'description': 'Yearly plan',
      'title': 'Yearly',
      'price': 49.99,
      'priceString': r'$49.99',
      'currencyCode': 'USD',
    },
    'presentedOfferingContext': <String, Object?>{
      'offeringIdentifier': 'default',
      'placementIdentifier': null,
      'targetingContext': null,
    },
  };
  final offering = <String, Object?>{
    'identifier': 'default',
    'serverDescription': 'Default offering',
    'metadata': <String, Object>{},
    'availablePackages': <Object?>[package],
    'annual': package,
  };
  return {
    'all': {'default': offering},
    'current': offering,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Mocks the purchases_flutter channel; [onPurchase] runs when the
  /// paywall calls purchasePackage. [configured] gates every Purchases call
  /// (mirroring the SDK): false skips the initState price fetch AND makes
  /// the purchase/restore flows bail out before reaching the store.
  void mockPurchases({
    Object? Function()? onPurchase,
    bool configured = false,
    int eligibility = 2, // IntroEligibilityStatus index: 2 = eligible
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isConfigured':
          return configured;
        case 'getOfferings':
          return _offeringsJson();
        case 'checkTrialOrIntroductoryPriceEligibility':
          return {
            'mgb_premium_annual': {
              'status': eligibility,
              'description': 'test',
            },
          };
        case 'purchasePackage':
          return onPurchase?.call();
        default:
          return null;
      }
    });
  }

  group('paywall gate copy', () {
    testWidgets('locked shows subscribe CTA, no free-trial copy, no back',
        (tester) async {
      await tester.pumpWidget(_app(locked: true));
      await tester.pumpAndSettle();

      // The CTA carries the expired copy; no free-trial framing.
      expect(find.text(l10n.subscribeToContinue), findsOneWidget);
      expect(find.text(l10n.freeTrial), findsNothing);
      expect(find.text(l10n.obNotChargedUntil), findsNothing);
      // Gate active — the paywall must not be dismissible.
      expect(find.byType(ObBackButton), findsNothing);
      // Store disclosures are always on the page (Apple 3.1.2).
      expect(find.text(l10n.restoreSubscription), findsOneWidget);
      expect(find.text(l10n.termsOfUse), findsOneWidget);
      expect(find.text(l10n.privacyPolicy), findsOneWidget);
      expect(find.text(l10n.autoRenewDisclosure), findsOneWidget);
    });

    testWidgets('unlocked shows free-trial CTA, trial terms and a back button',
        (tester) async {
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      expect(find.text(l10n.freeTrial), findsOneWidget);
      expect(find.text(l10n.obNotChargedUntil), findsOneWidget);
      expect(find.text(l10n.subscribeToContinue), findsNothing);
      expect(find.byType(ObBackButton), findsOneWidget);
    });

    testWidgets('no trial copy for users the store says are ineligible',
        (tester) async {
      mockPurchases(configured: true, eligibility: 1); // 1 = ineligible
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      expect(find.text(l10n.freeTrial), findsNothing);
      expect(find.text(l10n.obSubscribe), findsOneWidget);
      expect(find.text(l10n.obNotChargedUntil), findsNothing);
    });
  });

  group('purchase error handling', () {
    testWidgets('user cancelling the purchase sheet shows no error',
        (tester) async {
      // PurchasesErrorCode index 1 == purchaseCancelledError.
      mockPurchases(
        configured: true,
        onPurchase: () =>
            throw PlatformException(code: '1', message: 'cancelled'),
      );
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.freeTrial));
      await tester.pumpAndSettle();

      expect(find.text(l10n.purchaseFailed), findsNothing);
      // The CTA recovered from its loading state.
      expect(find.text(l10n.freeTrial), findsOneWidget);
    });

    testWidgets('a real purchase failure shows the error message',
        (tester) async {
      // PurchasesErrorCode index 2 == storeProblemError.
      mockPurchases(
        configured: true,
        onPurchase: () =>
            throw PlatformException(code: '2', message: 'store problem'),
      );
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.freeTrial));
      await tester.pumpAndSettle();

      expect(find.text(l10n.purchaseFailed), findsOneWidget);
    });
  });

  group('personal target plan', () {
    test('rebuilds from the persisted onboarding answers', () {
      final plan = PaywallPlan.fromProfile(
        const UserProfile(
          localId: 1,
          syncStatus: 'synced',
          weightUnit: 'lbs',
          heightUnit: 'cm',
          preferredLanguage: 'system',
          subscriptionStatus: 'expired',
          defaultRestSeconds: 90,
          notificationTone: 'balanced',
          gender: 'female',
          goal: 'lose_weight',
          bodyWeightKg: 80,
        ).copyWith(
          targetWeightKg: const Value(70),
          trainingDays: Value(jsonEncode([1, 3, 5])),
          focusAreas: Value(jsonEncode(['glutes', 'legs', 'nope'])),
        ),
      )!;
      expect(plan.metric, isFalse);
      expect(plan.female, isTrue);
      expect(plan.goal, OnboardingGoal.loseWeight);
      expect(plan.trainingDays, 3);
      // Unknown wire values are skipped, not fatal.
      expect(plan.focus, [FocusArea.glutes, FocusArea.legs]);
      expect(plan.prediction.days, 127); // 10 kg / 0.55 kg a week × 7
    });

    test('no target recorded → no personal slide', () {
      expect(PaywallPlan.fromProfile(null), isNull);
      expect(
        PaywallPlan.fromProfile(
          const UserProfile(
            localId: 1,
            syncStatus: 'synced',
            weightUnit: 'kg',
            heightUnit: 'cm',
            preferredLanguage: 'system',
            subscriptionStatus: 'trial',
            defaultRestSeconds: 90,
            notificationTone: 'balanced',
            bodyWeightKg: 80,
          ),
        ),
        isNull,
      );
    });
  });
}
