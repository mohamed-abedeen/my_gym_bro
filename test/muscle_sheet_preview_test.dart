import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_detail_sheet.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/muscle_volume.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// MANUAL PREVIEW HARNESS — not part of the normal suite (skip: true).
///
/// Renders the redesigned Muscle Recovery sheet at the Figma design size
/// (440×956) with staged fake data, and writes PNGs to `build/preview/` for
/// visual comparison against the handoff frames:
///
///   flutter test test/muscle_sheet_preview_test.dart --run-skipped
///
/// If anatomy assets changed since the last test run, clear the stale bundle
/// first: `rm -rf build/unit_test_assets`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render muscle recovery sheet previews', skip: true,
      (tester) async {
    // The gender notifier reads SecureStorage on construction; give the
    // plugin channel a null-returning handler so the async load is a no-op.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    // Real glyphs instead of the boxy test font.
    await tester.runAsync(() async {
      final loader = FontLoader('Archivo')
        ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'));
      await loader.load();
    });

    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // ── Staged data (mirrors the handoff frames) ──
    final recoveryStates = <MuscleStateInfo>[
      for (final g in MuscleRecoveryService.allMuscleGroups)
        if (g != 'Cardio')
          MuscleStateInfo(
            muscleGroup: g,
            state: switch (g) {
              'Rear Delt' || 'Traps' => MuscleState.recovering,
              'Upper Back' || 'Biceps' => MuscleState.recovering,
              'Chest' || 'Lats' || 'Quads' || 'Glutes' =>
                MuscleState.recovered,
              _ => MuscleState.undertrained,
            },
            lastTrainedAt: DateTime.now().subtract(const Duration(hours: 20)),
            recoveryPercent: switch (g) {
              'Rear Delt' => 0.10,
              'Traps' => 0.35,
              'Upper Back' => 0.65,
              'Biceps' => 0.80,
              'Chest' || 'Lats' || 'Quads' || 'Glutes' => 1.0,
              _ => null,
            },
          ),
    ];
    final volumeInfos = buildMuscleVolumeInfos(
      totals: {
        'Chest': 4,
        'Side Delt': 6,
        'Traps': 5,
        'Upper Back': 7,
        'Lats': 12,
        'Quads': 14,
        'Biceps': 10,
        'Hamstrings': 24,
      },
      allGroups: MuscleRecoveryService.allMuscleGroups,
      weeksInWindow: 1,
    );

    final shotKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          muscleRecoveryProvider.overrideWith((ref) => recoveryStates),
          muscleVolumeProvider.overrideWith((ref, window) => volumeInfos),
          activeSkinPathProvider
              .overrideWithValue('assets/anatomy/male_base.png'),
        ],
        child: RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              extensions: const [AppColorsTheme.dark],
              textTheme: ThemeData.dark()
                  .textTheme
                  .apply(fontFamily: 'Archivo'),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: TextButton(
                    onPressed: () => showMuscleDetailSheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> settleAssets() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump(const Duration(milliseconds: 80));
      }
    }

    Future<void> shoot(String name) async {
      await settleAssets();
      final boundary = shotKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data =
            await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!;
      });
      final file = File('build/preview/$name.png')
        ..createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      debugPrint('wrote ${file.path}');
    }

    // Open the sheet → recovery mode.
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
    await shoot('recovery');

    // Volume mode (back view foreground).
    await tester.tap(find.text('Volume'));
    await tester.pump(const Duration(milliseconds: 400));
    await shoot('volume_back');

    // Drag to the front view.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await shoot('volume_front');
  });
}
