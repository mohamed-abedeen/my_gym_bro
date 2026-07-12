import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_gym_bro/core/database/app_database.dart' show UserProfile;
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_screen.dart';
import 'package:my_gym_bro/features/workout/share/widgets/hero_stats_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/weekly_progress_card.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The real anatomy-gender notifier reads flutter_secure_storage on
    // construction; stub the channel so it returns null instead of throwing.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  /// Renders at a realistic phone-portrait size. The default 800x600 landscape
  /// surface squeezes the 9:16 cards far narrower than any real device, which
  /// makes tight stat rows overflow — not a device bug, a test-surface one.
  void usePhonePortrait(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('ShareCardScreen builds and shows the 5 template pages', (
    tester,
  ) async {
    usePhonePortrait(tester);
    // Empty exercises + muscle groups keep the card raster-light (no SVG
    // muscle overlays) — we only care that the screen composes.
    const data = ShareCardData(
      workoutName: 'Chest Day',
      totalVolumeKg: 5000,
      totalSets: 12,
      durationSeconds: 3600,
      avgStrength: 90,
      workoutNumber: 5,
      exercises: [],
      workedMuscleGroups: {},
      hasPr: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(null),
          ),
          weightUnitProvider.overrideWith((ref) => WeightUnit.kg),
          activeSkinPathProvider.overrideWith(
            (ref) => 'assets/anatomy/male_black.png',
          ),
          myRankProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShareCardScreen(data: data),
        ),
      ),
    );
    await tester.pump();

    // Built without throwing.
    expect(tester.takeException(), isNull);

    // Header + carousel + first template.
    expect(find.text('Nice work!'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(HeroStatsCard), findsOneWidget);

    // Five page dots ⇒ five template pages.
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('share_dot_$i')), findsOneWidget);
    }

    // Action buttons + the Normal/Transparent style toggle present.
    // (Save isn't tapped — gal would need channel mocking; just assert it
    // renders alongside Share/Done.)
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Transparent'), findsOneWidget);
  });

  testWidgets('WeeklyProgressCard shows this session stat grid', (
    tester,
  ) async {
    usePhonePortrait(tester);
    // Empty muscle groups keep it raster-light.
    const data = ShareCardData(
      workoutName: 'Leg Day',
      totalVolumeKg: 8000,
      totalSets: 15,
      durationSeconds: 4200,
      avgStrength: 118,
      workoutNumber: 9,
      exercises: [],
      workedMuscleGroups: {},
      hasPr: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(null),
          ),
          weightUnitProvider.overrideWith((ref) => WeightUnit.kg),
          activeSkinPathProvider.overrideWith(
            (ref) => 'assets/anatomy/male_black.png',
          ),
          myRankProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: WeeklyProgressCard(data: data))),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(WeeklyProgressCard), findsOneWidget);
    // Centred workout name (the brand mark is now the MGB logo image, not text).
    expect(find.text('Leg Day'), findsOneWidget);
    // This-session 2×2 grid labels (uppercased by ShareStatTile).
    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('AVG STRENGTH'), findsOneWidget);
    expect(find.text('SETS'), findsOneWidget);
  });
}
