import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// On iOS 26 the onboarding buttons are Apple's native Liquid Glass
/// (`CNButton`, the tab bar's glass). That can't render on this toolchain, so
/// these pin how the buttons configure it; elsewhere they're Flutter glass.
void main() {
  tearDown(() => debugObNativeGlassOverride = null);

  Future<void> pump(WidgetTester tester, Widget button) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObFrameScope(
            child: Center(
              child: SizedBox(width: 374, height: 79, child: button),
            ),
          ),
        ),
      ),
    );
  }

  CNButton native(WidgetTester tester) =>
      tester.widget<CNButton>(find.byType(CNButton));

  group('iOS 26: native Liquid Glass', () {
    setUp(() => debugObNativeGlassOverride = true);

    testWidgets('Continue is clear glass, filling its pill', (tester) async {
      var taps = 0;
      await pump(
        tester,
        ObGlassButton(label: 'Continue', onTap: () => taps++),
      );

      final b = native(tester);
      expect(b.label, 'Continue');
      expect(b.config.style, CNButtonStyle.glass);
      expect(b.config.minHeight, 79);
      expect(b.config.labelFontSize, 30);
      expect(b.config.labelFontWeight, FontWeight.w700);
      expect(b.config.labelColor, AppOnboarding.textPrimary);
      expect(b.tint, Colors.white);
      // The onboarding is black in every theme: dark glass.
      final theme = tester.widget<CupertinoTheme>(
        find.ancestor(
          of: find.byType(CNButton),
          matching: find.byType(CupertinoTheme),
        ).first,
      );
      expect(theme.data.brightness, Brightness.dark);

      b.onPressed!();
      expect(taps, 1);
      expect(find.byType(ObLiquidGlass), findsNothing);
    });

    testWidgets('disabled Continue: grey label, no tap', (tester) async {
      await pump(
        tester,
        ObGlassButton(label: 'Continue', onTap: () {}, enabled: false),
      );
      expect(native(tester).onPressed, isNull);
      expect(native(tester).config.labelColor, AppOnboarding.textDisabled);
    });

    testWidgets('paywall CTA is lime prominent glass; loading swallows taps',
        (tester) async {
      var taps = 0;
      await pump(
        tester,
        ObLiquidGlassButton(
          label: 'Free Trial',
          labelColor: Colors.black,
          tint: AppOnboarding.lime,
          loading: true,
          onTap: () => taps++,
        ),
      );

      final b = native(tester);
      expect(b.config.style, CNButtonStyle.prominentGlass);
      expect(b.tint, AppOnboarding.lime);
      expect(b.label, isEmpty, reason: 'the spinner stands in for it');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      b.onPressed!();
      expect(taps, 0);
    });

    testWidgets('a long label shrinks to fit its pill', (tester) async {
      await pump(
        tester,
        ObDarkButton(
          label: 'Commencez votre entraînement maintenant',
          onTap: () {},
        ),
      );
      // (The package's own non-iOS stand-in can't fit this label; only the
      // native config matters here.)
      tester.takeException();
      expect(native(tester).config.labelFontSize, lessThan(26));
    });

    testWidgets('provider icons pass through at the handoff size',
        (tester) async {
      await pump(
        tester,
        ObDarkButton(
          label: 'Google',
          fontSize: 22,
          icon: Icons.g_mobiledata,
          onTap: () {},
        ),
      );
      tester.takeException(); // the package's non-iOS stand-in, as above
      final b = native(tester);
      expect(b.customIcon, Icons.g_mobiledata);
      expect(b.config.customIconSize, 36);
      expect(b.config.labelFontSize, 22);
    });
  });

  testWidgets('elsewhere: the Flutter glass', (tester) async {
    debugObNativeGlassOverride = false;
    await pump(tester, ObGlassButton(label: 'Continue', onTap: () {}));
    expect(find.byType(CNButton), findsNothing);
    expect(find.byType(ObLiquidGlass), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('a fade-free entrance stays hidden through its delay',
      (tester) async {
    await pump(
      tester,
      const ObEntrance(
        delay: Duration(milliseconds: 400),
        fade: false,
        child: Text('Start training'),
      ),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Start training').hitTestable(), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Start training').hitTestable(), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });
}
