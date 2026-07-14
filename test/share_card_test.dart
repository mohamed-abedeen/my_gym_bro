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
import 'package:my_gym_bro/features/workout/share/widgets/anatomy_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/anatomy_geometry.dart';
import 'package:my_gym_bro/features/workout/share/widgets/editorial_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/hype_card.dart';
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
  /// surface squeezes the 9:16 cards far narrower than any real device.
  void usePhonePortrait(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final data = ShareCardData(
    workoutName: 'Chest Day',
    totalVolumeKg: 8310,
    totalSets: 12,
    durationSeconds: 3480,
    avgStrength: 90,
    workoutNumber: 58,
    exercises: const [],
    // Empty keeps cards raster-light (no SVG muscle overlays) — these tests
    // only care that the screens compose.
    workedMuscleGroups: const {},
    hasPr: true,
    date: DateTime(2026, 7, 13),
  );

  List<Override> overrides() => [
        userProfileProvider.overrideWith(
          (ref) => Stream<UserProfile?>.value(null),
        ),
        weightUnitProvider.overrideWith((ref) => WeightUnit.kg),
        activeSkinPathProvider.overrideWith(
          (ref) => 'assets/anatomy/male_black.png',
        ),
        myRankProvider.overrideWith((ref) => null),
      ];

  Widget host(Widget child) => ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  testWidgets('ShareCardScreen builds with the 3 templates and v2 chrome', (
    tester,
  ) async {
    usePhonePortrait(tester);
    await tester.pumpWidget(host(ShareCardScreen(data: data)));
    await tester.pump();

    expect(tester.takeException(), isNull);

    // Header + subline.
    expect(find.text('Nice work.'), findsOneWidget);
    expect(find.text('CHEST DAY · WORKOUT #58'), findsOneWidget);

    // Carousel showing the first template.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(EditorialShareCard), findsOneWidget);

    // Named template chips replace the page dots.
    expect(find.text('Editorial'), findsOneWidget);
    expect(find.text('Anatomy'), findsOneWidget);
    expect(find.text('Hype'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('share_chip_$i')), findsOneWidget);
    }

    // Dark/Sticker toggle + actions.
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.byKey(const Key('share_save_btn')), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Tapping a chip pages the carousel.
    await tester.tap(find.byKey(const Key('share_chip_2')));
    await tester.pumpAndSettle();
    expect(find.byType(HypeShareCard), findsOneWidget);
  });

  testWidgets('EditorialShareCard splits the title and lists the ledger', (
    tester,
  ) async {
    usePhonePortrait(tester);
    await tester.pumpWidget(
      host(Scaffold(body: Center(child: EditorialShareCard(data: data)))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Two-line title: last word outlined on its own line.
    expect(find.text('CHEST'), findsOneWidget);
    expect(find.text('DAY'), findsOneWidget);
    expect(find.text('MON · JUL 13 2026'), findsOneWidget);
    // Ledger labels.
    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('SETS'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('MYGYMBRO.APP'), findsOneWidget);
  });

  testWidgets('AnatomyShareCard renders callouts for worked groups', (
    tester,
  ) async {
    usePhonePortrait(tester);
    final legDay = ShareCardData(
      workoutName: 'Hamstrings Day',
      totalVolumeKg: 8310,
      totalSets: 12,
      durationSeconds: 3480,
      avgStrength: 90,
      workoutNumber: 58,
      exercises: const [],
      workedMuscleGroups: const {'Glutes', 'Hamstrings', 'Calves'},
      hasPr: false,
      date: DateTime(2026, 7, 13),
    );
    await tester.pumpWidget(
      host(Scaffold(body: Center(child: AnatomyShareCard(data: legDay)))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('GLUTES'), findsOneWidget);
    // Callout + the card title's first line.
    expect(find.text('HAMSTRINGS'), findsNWidgets(2));
    expect(find.text('CALVES'), findsOneWidget);
  });

  test('AnatomyShareCard.viewFor picks the side showing every muscle', () {
    // Leg day spans both sides: quads front, hamstrings/glutes back.
    expect(
      AnatomyShareCard.viewFor(
        {'Quads', 'Hamstrings', 'Glutes', 'Calves'},
        muscleGeometryMale,
      ),
      AnatomyFigureView.both,
    );
    expect(
      AnatomyShareCard.viewFor(
        {'Chest', 'Biceps', 'Core'},
        muscleGeometryMale,
      ),
      AnatomyFigureView.front,
    );
    expect(
      AnatomyShareCard.viewFor(
        {'Lats', 'Traps', 'Rear Delt'},
        muscleGeometryMale,
      ),
      AnatomyFigureView.back,
    );
    expect(AnatomyShareCard.viewFor({}, muscleGeometryMale),
        AnatomyFigureView.back);
  });

  test('AnatomyShareCard.layoutCallouts spaces and caps rows', () {
    final rows = AnatomyShareCard.layoutCallouts(
      {
        'Traps',
        'Rear Delt',
        'Lats',
        'Lower Back',
        'Triceps',
        'Hamstrings',
        'Glutes',
        'Calves',
      },
      muscleGeometryMale,
      AnatomyFigureView.back,
    );
    expect(rows.length, 5); // capped
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].y - rows[i - 1].y, greaterThanOrEqualTo(20));
    }
  });

  testWidgets('HypeShareCard shows the comparison scale', (tester) async {
    usePhonePortrait(tester);
    await tester.pumpWidget(
      host(Scaffold(body: Center(child: HypeShareCard(data: data)))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('TOTAL VOLUME LIFTED'), findsOneWidget);
    expect(find.text('8,310'), findsOneWidget);
    // 8,310 kg out-lifts the 6,000 kg elephant tier.
    expect(find.text('Heavier than a full-grown elephant.'), findsOneWidget);
    expect(find.text('YOU · 8,310 KG'), findsOneWidget);
    expect(find.text('ELEPHANT · 6,000 KG'), findsOneWidget);
    // Mini stats line.
    expect(find.text('12 SETS · 58M · CHEST DAY'), findsOneWidget);
  });
}
