import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/paywall/paywall_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// The paywall inside a real localized MaterialApp with the app's color
/// theme extension (AppColors.of requires it) and the gate overridden.
Widget _app({required bool locked}) => ProviderScope(
      overrides: [subscriptionLockedProvider.overrideWithValue(locked)],
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
      'identifier': 'mgb_yearly',
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
  /// paywall calls purchasePackage.
  void mockPurchases({Object? Function()? onPurchase}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isConfigured':
          return false; // skips the initState price fetch
        case 'getOfferings':
          return _offeringsJson();
        case 'purchasePackage':
          return onPurchase?.call();
        default:
          return null;
      }
    });
  }

  group('paywall gate copy', () {
    testWidgets('locked shows subscribe copy, no trial badge, no close',
        (tester) async {
      await tester.pumpWidget(_app(locked: true));
      await tester.pumpAndSettle();

      // Headline + CTA both carry the expired copy.
      expect(find.text(l10n.subscribeToContinue), findsNWidgets(2));
      expect(find.text(l10n.trialBadge), findsNothing);
      expect(find.text(l10n.startTrial), findsNothing);
      expect(find.text(l10n.cancelAnytime), findsNothing);
      // Gate active — the paywall must not be dismissible.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('unlocked shows start-trial copy with badge and close button',
        (tester) async {
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      expect(find.text(l10n.startTrial), findsNWidgets(2));
      expect(find.text(l10n.trialBadge), findsOneWidget);
      expect(find.text(l10n.cancelAnytime), findsOneWidget);
      expect(find.text(l10n.subscribeToContinue), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('purchase error handling', () {
    testWidgets('user cancelling the purchase sheet shows no error',
        (tester) async {
      // PurchasesErrorCode index 1 == purchaseCancelledError.
      mockPurchases(
        onPurchase: () =>
            throw PlatformException(code: '1', message: 'cancelled'),
      );
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(ElevatedButton, l10n.startTrial);
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text(l10n.purchaseFailed), findsNothing);
      // The CTA recovered from its loading state.
      expect(find.text(l10n.startTrial), findsNWidgets(2));
    });

    testWidgets('a real purchase failure shows the error message',
        (tester) async {
      // PurchasesErrorCode index 2 == storeProblemError.
      mockPurchases(
        onPurchase: () =>
            throw PlatformException(code: '2', message: 'store problem'),
      );
      await tester.pumpWidget(_app(locked: false));
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(ElevatedButton, l10n.startTrial);
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text(l10n.purchaseFailed), findsOneWidget);
    });
  });
}
