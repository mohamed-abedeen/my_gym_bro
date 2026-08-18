// Measurement harness for `anatomy_geometry.dart` (skipped by default).
//
// Rasterises each muscle group's SVGs on the shared 900×1140 anatomy canvas,
// scans pixels, and writes ready-to-paste `muscleGeometryMale/Female` const
// maps to build/muscle_geometry.dart.txt. Re-run whenever the muscle SVG
// artwork changes, then replace the maps in
// lib/features/workout/share/widgets/anatomy_geometry.dart:
//
//   flutter test test/measure_muscle_bounds_test.dart --run-skipped
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _outFile = 'build/muscle_geometry.dart.txt';

// Mirror of anatomy_body.dart's group → SVG-base mapping (private there).
const _groups = <String, List<String>>{
  'Chest': ['chest'],
  'Lats': ['upper_lats', 'lower_lats'],
  'Upper Back': ['upper_back', 'mid_back'],
  'Lower Back': ['lower_back'],
  'Traps': ['traps'],
  'Shoulders': ['front_delt', 'side_delt', 'rear_delt'],
  'Front Delt': ['front_delt'],
  'Side Delt': ['side_delt'],
  'Rear Delt': ['rear_delt'],
  'Biceps': ['biceps', 'brachialis'],
  'Triceps': ['triceps'],
  'Forearms': ['forearm_flexors', 'forearm_extensors'],
  'Quads': ['quads', 'adductors'],
  'Hamstrings': ['hamstrings'],
  'Glutes': ['glutes', 'glute_medius', 'abductors'],
  'Calves': ['calves'],
  'Core': ['abs', 'obliques', 'external_obliques'],
  'Neck': ['neck'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Manual harness — see the header comment for when/how to run.
  testWidgets('measure muscle bounds', skip: true, (tester) async {
    tester.view.physicalSize = const Size(900, 1140);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final out = StringBuffer();
    for (final gender in ['male', 'female']) {
      out.writeln(
        'const muscleGeometry${gender == 'male' ? 'Male' : 'Female'} = '
        '<String, MuscleGeometry>{',
      );
      for (final entry in _groups.entries) {
        final bases = entry.value;
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 900,
                    height: 1140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final b in bases)
                          SvgPicture.asset(
                            'assets/anatomy/${gender}_$b.svg',
                            height: 1140,
                            // The 2026-08 vectors carry fills in a <style>
                            // block flutter_svg doesn't parse, so bare paths
                            // paint black — invisible on the black probe bg.
                            // The app always tints via ColorFilter (srcIn),
                            // so do the same here to measure coverage.
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }

        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!;
        });

        // Non-black pixels = muscle coverage (SVGs paint over black bg).
        var frontN = 0;
        var backN = 0;
        var fl = 900;
        var ft = 1140;
        var fr = -1;
        var fb = -1;
        var bl = 900;
        var bt = 1140;
        var br = -1;
        var bb = -1;
        final buf = pixels!.buffer.asUint8List();
        bool covered(int x, int y) {
          final o = (y * 900 + x) * 4;
          return buf[o] + buf[o + 1] + buf[o + 2] >= 24;
        }

        // 2026-08 art set: BACK view on the left half (x < 450), FRONT on
        // the right half — inverted from the original sheets.
        for (var y = 0; y < 1140; y++) {
          for (var x = 0; x < 900; x++) {
            if (!covered(x, y)) continue;
            if (x >= 450) {
              frontN++;
              if (x < fl) fl = x;
              if (x > fr) fr = x;
              if (y < ft) ft = y;
              if (y > fb) fb = y;
            } else {
              backN++;
              if (x < bl) bl = x;
              if (x > br) br = x;
              if (y < bt) bt = y;
              if (y > bb) bb = y;
            }
          }
        }
        final total = frontN + backN;
        final frontShare = total == 0 ? 0.0 : frontN / total;

        // Centroid of the LEFT UNIT of the view's coverage (pixels left of
        // the bbox midline) — for bilateral muscles this is the left pec /
        // left delt / left glute, which is where an annotation points.
        String centroid(int l, int r, int x0, int x1, int n) {
          if (total == 0 || n / total < 0.03) return 'null';
          final midX = (l + r) ~/ 2;
          var cx = 0.0;
          var cy = 0.0;
          var m = 0;
          for (var y = 0; y < 1140; y++) {
            for (var x = x0; x <= midX && x < x1; x++) {
              if (!covered(x, y)) continue;
              cx += x;
              cy += y;
              m++;
            }
          }
          if (m == 0) return 'null';
          return 'Offset(${(cx / m / 900).toStringAsFixed(4)}, '
              '${(cy / m / 1140).toStringAsFixed(4)})';
        }

        out.writeln(
          "  '${entry.key}': "
          '(front: ${centroid(fl, fr, 450, 900, frontN)}, '
          'back: ${centroid(bl, br, 0, 450, backN)}, '
          'frontShare: ${frontShare.toStringAsFixed(3)}),',
        );
      }
      out.writeln('};');
    }
    File(_outFile).writeAsStringSync(out.toString());
  });
}
