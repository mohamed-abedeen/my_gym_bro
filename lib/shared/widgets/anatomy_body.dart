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
  'Chest': ['chest'],

  // ── Back ──
  'Lats': ['upper_lats', 'lower_lats'],
  // Dedicated upper/mid-back artwork (2026-08 vector set). Must NOT reuse the
  // lats overlay — an overhead press crediting 'upper back' would paint the
  // entire lats red on a push day.
  'Upper Back': ['upper_back', 'mid_back'],
  'Lower Back': ['lower_back'],
  'Traps': ['traps'],

  // ── Shoulders ──
  'Shoulders':   ['front_delt', 'side_delt', 'rear_delt'], // all 3 heads
  'Front Delt':  ['front_delt'],
  'Side Delt':   ['side_delt'],
  'Rear Delt':   ['rear_delt'],

  // ── Arms ──
  'Biceps': ['biceps', 'brachialis'],
  'Triceps': ['triceps'],
  'Forearms': ['forearm_flexors', 'forearm_extensors'],

  // ── Legs ──
  'Quads': ['quads', 'adductors'],
  'Hamstrings': ['hamstrings'],
  'Glutes': ['glutes', 'glute_medius', 'abductors'],
  'Calves': ['calves'],

  // ── Core ──
  'Core': ['abs', 'obliques', 'external_obliques'],

  // ── Neck ──
  'Neck': ['neck'],

  // 'Cardio' has no anatomy SVG
};

String _svgPath(AnatomyGender gender, String base) =>
    'assets/anatomy/${gender == AnatomyGender.male ? 'male' : 'female'}_$base.svg';

/// Renders the anatomy body with colored muscle overlays.
///
/// Supports both male and female body types via [gender].
class AnatomyBody extends StatelessWidget {

  const AnatomyBody({
    required this.muscleStates, required this.height, super.key,
    this.gender = AnatomyGender.female,
    this.basePngPath,
    this.highlightColor,
    this.tintFor,
    this.focusedMuscle,
  });
  final List<MuscleStateInfo> muscleStates;
  final double height;
  final AnatomyGender gender;

  /// Optional per-muscle tint override. Takes precedence over [highlightColor]
  /// and the muscle's own recovery colour. Used by the recovery sheet to match
  /// the HSL tint shared between the body and the list.
  final Color Function(MuscleStateInfo muscle)? tintFor;

  /// When set, that muscle's overlay pops to 0.95 opacity and every other
  /// muscle dims to 0.12 (focus mode). Null → all muscles at the default 0.85.
  /// Transitions animate over 250ms.
  final String? focusedMuscle;

  /// Optional override for the base body PNG.
  ///
  /// When supplied (e.g. from `activeSkinPathProvider`) the skin image is used
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
            ? 'assets/anatomy/male_base.png'
            : 'assets/anatomy/female_base.png');

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

    final color = tintFor?.call(muscle) ?? highlightColor ?? muscle.color;
    final opacity = focusedMuscle == null
        ? 0.85
        : (muscle.muscleGroup == focusedMuscle ? 0.95 : 0.12);

    // Bake opacity into the srcIn alpha (NOT a wrapping Opacity widget): for
    // BlendMode.color the alpha must scale the *blend*, letting the skin's
    // shading show through. A full-alpha blend + widget Opacity over-saturates.
    return [
      for (final base in bases)
        BlendMask(
          blendMode: BlendMode.color,
          child: SvgPicture.asset(
            _svgPath(gender, base),
            height: height,
            colorFilter: ColorFilter.mode(
              color.withValues(alpha: opacity),
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
