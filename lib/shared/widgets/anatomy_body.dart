import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';

/// Gender selection for anatomy rendering.
enum AnatomyGender { female, male }

/// Maps muscle group names (from DB) to SVG base names.
///
/// Both genders share the same base names — the file on disk is
/// `assets/anatomy/{female,male}_<base>.svg`. Use [_svgPath] to resolve.
const _muscleGroupToSvgs = <String, List<String>>{
  // ── Chest ──
  'Chest': ['chest', 'serratus'],

  // ── Back ──
  'Lats': ['lats', 'teres_major'],
  'Upper Back': ['lats', 'teres_major'],
  'Lower Back': ['lowerback'],
  'Traps': ['traps'],

  // ── Shoulders ──
  'Shoulders':   ['front_shoulder', 'side_shoulder', 'rear_shoulder'], // all 3 heads
  'Front Delt':  ['front_shoulder'],
  'Side Delt':   ['side_shoulder'],
  'Rear Delt':   ['rear_shoulder'],

  // ── Arms ──
  'Biceps': ['biceps'],
  'Triceps': ['triceps'],
  'Forearms': ['forearms'],

  // ── Legs ──
  'Quads': ['quadriceps', 'adductor'],
  'Hamstrings': ['hamstings'],
  'Glutes': ['glutes', 'abductors'],
  'Calves': ['calves', 'tibialis_anterior'],

  // ── Core ──
  'Core': ['abs', 'obliques'],

  // ── Neck ──
  'Neck': ['nick'],

  // 'Cardio' has no anatomy SVG
};

String _svgPath(AnatomyGender gender, String base) =>
    'assets/anatomy/${gender == AnatomyGender.male ? 'male' : 'female'}_$base.svg';

/// Extra SVG bases that only exist for the male body.
const _maleExtraSvgBases = <String, List<String>>{
  'Core': ['obliques2'],
};

/// Renders the anatomy body with colored muscle overlays.
///
/// Supports both male and female body types via [gender].
class AnatomyBody extends StatelessWidget {

  const AnatomyBody({
    required this.muscleStates, required this.height, super.key,
    this.gender = AnatomyGender.female,
    this.basePngPath,
    this.highlightColor,
  });
  final List<MuscleStateInfo> muscleStates;
  final double height;
  final AnatomyGender gender;

  /// Optional override for the base body PNG.
  ///
  /// When supplied (e.g. from [activeSkinPathProvider]) the skin image is used
  /// instead of the default anatomy PNG.  Falls back to the built-in default
  /// when `null`.
  final String? basePngPath;

  /// Optional override tint for every drawn muscle overlay. When `null`
  /// (default) each muscle keeps its own recovery-state colour; callers like
  /// the share card pass the brand accent so worked muscles read as "trained"
  /// rather than recovery-red.
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final isMale = gender == AnatomyGender.male;
    final resolvedBasePng = basePngPath ??
        (isMale
            ? 'assets/anatomy/male_black.png'
            : 'assets/anatomy/Female Black.png');

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base body PNG (default or selected skin)
          Image.asset(resolvedBasePng, height: height, fit: BoxFit.contain),

          // Muscle overlays — only trained/recovering muscles
          for (final muscle in muscleStates)
            if (muscle.recoveryPercent != null) ..._buildMuscleLayers(muscle),
        ],
      ),
    );
  }

  List<Widget> _buildMuscleLayers(MuscleStateInfo muscle) {
    final bases = _muscleGroupToSvgs[muscle.muscleGroup];
    if (bases == null || bases.isEmpty) return [];

    final isMale = gender == AnatomyGender.male;
    final allBases = <String>[
      ...bases,
      if (isMale) ...?_maleExtraSvgBases[muscle.muscleGroup],
    ];

    return [
      for (final base in allBases)
        BlendMask(
          blendMode: BlendMode.color,
          child: SvgPicture.asset(
            _svgPath(gender, base),
            height: height,
            colorFilter: ColorFilter.mode(
              (highlightColor ?? muscle.color).withValues(alpha: 0.85),
              BlendMode.srcIn,
            ),
          ),
        ),
    ];
  }
}

class BlendMask extends SingleChildRenderObjectWidget {

  const BlendMask({
    required this.blendMode, super.key,
    super.child,
  });
  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBlendMask(blendMode);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class RenderBlendMask extends RenderProxyBox {

  RenderBlendMask(this.blendMode);
  BlendMode blendMode;

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
