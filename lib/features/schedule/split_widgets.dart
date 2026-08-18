import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Frosted circle header button (shared 48pt header-action spec) used across
/// the split-switcher screens.
class SplitHeaderButton extends StatelessWidget {
  const SplitHeaderButton({required this.icon, this.onTap, super.key});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LiquidGlassButton(
      width: AppSizes.headerActionBtn.w,
      height: AppSizes.headerActionBtn.w,
      onTap: onTap,
      child: Icon(icon,
          color: colors.textPrimary, size: AppSizes.headerActionIcon.sp),
    );
  }
}

/// The anatomy base renders back and front bodies side by side (2026-08 art
/// set: back left, front right); the source PNG is 900×1140, so the front
/// body's vertical axis sits at 75% of the rendered width.
const _bodyAspect = 900 / 1140;

/// Cropped anatomy hero anchored top-right behind the title block: a
/// ~240×340 window onto a much taller body render, shifted so only the
/// FRONT body's upper half shows, with the day's muscles highlighted in
/// the accent color.
class SplitHeroBody extends ConsumerWidget {
  const SplitHeroBody({required this.muscles, super.key});
  final List<String> muscles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final windowW = 240.w;
    final windowH = 340.h;
    final bodyH = 620.h;
    // Center the front body (right half of the render) in the window.
    final bodyW = bodyH * _bodyAspect;
    final dx = windowW / 2 - bodyW * 0.75;

    return IgnorePointer(
      child: SizedBox(
        width: windowW,
        height: windowH,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(dx, -6.h),
              child: AnatomyBody(
                height: bodyH,
                gender: ref.watch(anatomyGenderProvider),
                basePngPath: ref.watch(activeSkinPathProvider),
                highlightColor: colors.accent,
                muscleStates: [
                  for (final m in muscles)
                    MuscleStateInfo(
                      muscleGroup: m,
                      state: MuscleState.recovering,
                      recoveryPercent: 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _legMuscles = {'Quads', 'Hamstrings', 'Glutes', 'Calves'};
const _pullMuscles = {
  'Lats',
  'Upper Back',
  'Lower Back',
  'Traps',
  'Biceps',
  'Rear Delt',
  'Forearms',
};

/// Icon for a training day, picked from its dominant muscle groups
/// (legs → run, pull → gymnastics, everything else → dumbbell).
IconData splitDayIcon(Iterable<String> muscleGroups) {
  var legs = 0;
  var pull = 0;
  var other = 0;
  for (final m in muscleGroups) {
    if (_legMuscles.contains(m)) {
      legs++;
    } else if (_pullMuscles.contains(m)) {
      pull++;
    } else {
      other++;
    }
  }
  if (legs > 0 && legs >= pull && legs >= other) {
    return Icons.directions_run_rounded;
  }
  if (pull > 0 && pull >= other) return Icons.sports_gymnastics_rounded;
  return Icons.fitness_center_rounded;
}
