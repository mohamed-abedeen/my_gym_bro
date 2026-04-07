import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/workout/muscle_recovery_service.dart';

/// Gender selection for anatomy rendering.
enum AnatomyGender { female, male }

/// Maps muscle group names (from DB) to SVG asset filenames.
///
/// Female files use their own naming convention (with spaces, mixed case, etc.).
/// Male files use `male_` prefix with underscored names.
///
/// Each entry: muscleGroup → list of (femaleSvg, maleSvg) pairs.
class _SvgPair {
  final String female;
  final String male;
  const _SvgPair(this.female, this.male);
}

const _muscleGroupToSvgs = <String, List<_SvgPair>>{
  // ── Chest ──
  'Chest': [
    _SvgPair('Chest', 'male_chest'),
    _SvgPair('Serratus', 'male_serratus'),
  ],

  // ── Back ──
  'Lats': [
    _SvgPair('Lats', 'male_lats'),
    _SvgPair('Teres Major', 'male_teres_major'),
  ],
  'Upper Back': [
    _SvgPair('Lats', 'male_lats'),
    _SvgPair('Teres Major', 'male_teres_major'),
  ],
  'Lower Back': [_SvgPair('Lowerback', 'male_lowerback')],
  'Traps': [_SvgPair('Traps', 'male_traps')],

  // ── Shoulders ──
  'Shoulders': [
    _SvgPair('front sh', 'male_front_shoulder'),
    _SvgPair('side sh', 'male_side_shoulder'),
    _SvgPair('rear sh', 'male_rear_shoulder'),
  ],

  // ── Arms ──
  'Biceps': [_SvgPair('bi', 'male_biceps')],
  'Triceps': [_SvgPair('tri', 'male_triceps')],
  'Forearms': [_SvgPair('forearms', 'male_forearms')],

  // ── Legs ──
  'Quads': [
    _SvgPair('quadriceps', 'male_quadriceps'),
    _SvgPair('Adductor', 'male_adductor'),
  ],
  'Hamstrings': [_SvgPair('Hamstings', 'male_hamstings')],
  'Glutes': [
    _SvgPair('Glutes', 'male_glutes'),
    _SvgPair('Abductors', 'male_abductors'),
  ],
  'Calves': [
    _SvgPair('calvs', 'male_calves'),
    _SvgPair('Tibialis Anterior', 'male_tibialis_anterior'),
  ],

  // ── Core ──
  'Core': [
    _SvgPair('ABS', 'male_abs'),
    _SvgPair('Obliques', 'male_obliques'),
  ],

  // ── Neck ──
  'Neck': [_SvgPair('nick', 'male_nick')],

  // 'Cardio' has no anatomy SVG
};

/// Extra SVGs that only exist for the male body.
const _maleExtraSvgFiles = <String, List<String>>{
  'Core': ['male_obliques2'],
};

/// Renders the anatomy body with colored muscle overlays.
///
/// Supports both male and female body types via [gender].
class AnatomyBody extends StatelessWidget {
  final List<MuscleStateInfo> muscleStates;
  final double height;
  final AnatomyGender gender;

  const AnatomyBody({
    super.key,
    required this.muscleStates,
    required this.height,
    this.gender = AnatomyGender.female,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = gender == AnatomyGender.male;
    final basePng = isMale
        ? 'assets/anatomy/male_black.png'
        : 'assets/anatomy/Female Black.png';

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base body PNG
          Image.asset(basePng, height: height, fit: BoxFit.contain),

          // Muscle overlays — only trained/recovering muscles
          for (final muscle in muscleStates)
            if (muscle.recoveryPercent != null) ..._buildMuscleLayers(muscle),
        ],
      ),
    );
  }

  List<Widget> _buildMuscleLayers(MuscleStateInfo muscle) {
    final isMale = gender == AnatomyGender.male;
    final pairs = _muscleGroupToSvgs[muscle.muscleGroup];
    if (pairs == null || pairs.isEmpty) return [];

    final widgets = <Widget>[];

    // Main SVGs for this muscle group
    for (final pair in pairs) {
      final svgName = isMale ? pair.male : pair.female;
      widgets.add(
        BlendMask(
          blendMode: BlendMode.color,
          child: SvgPicture.asset(
            'assets/anatomy/$svgName.svg',
            height: height,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              muscle.color.withValues(alpha: 0.85),
              BlendMode.srcIn,
            ),
          ),
        ),
      );
    }

    // Male-only extra SVGs
    if (isMale) {
      final extras = _maleExtraSvgFiles[muscle.muscleGroup];
      if (extras != null) {
        for (final svgName in extras) {
          widgets.add(
            BlendMask(
              blendMode: BlendMode.color,
              child: SvgPicture.asset(
                'assets/anatomy/$svgName.svg',
                height: height,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  muscle.color.withValues(alpha: 0.85),
                  BlendMode.srcIn,
                ),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }
}

class BlendMask extends SingleChildRenderObjectWidget {
  final BlendMode blendMode;

  const BlendMask({
    super.key,
    required this.blendMode,
    super.child,
  });

  @override
  RenderObject createRenderObject(context) {
    return RenderBlendMask(blendMode);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class RenderBlendMask extends RenderProxyBox {
  BlendMode blendMode;

  RenderBlendMask(this.blendMode);

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = blendMode,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}
