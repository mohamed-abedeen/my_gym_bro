import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Shows the "Recovery Hub" bottom sheet: a tap-to-focus anatomy body, a
/// "Ready now" chip row, and a status-grouped muscle list with recovery rings.
void showMuscleDetailSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MuscleDetailSheet(),
  );
}

/// Recovery status buckets, derived from recovery percent (design 1b):
/// null → untrained, ≥100% → ready, ≥50% → recovering, else sore.
enum _Bucket { sore, recovering, ready, untrained }

_Bucket _bucketOf(MuscleStateInfo m) {
  final p = m.recoveryPercent;
  if (p == null) return _Bucket.untrained;
  if (p >= 1.0) return _Bucket.ready;
  if (p >= 0.5) return _Bucket.recovering;
  return _Bucket.sore;
}

class _MuscleDetailSheet extends ConsumerStatefulWidget {
  const _MuscleDetailSheet();

  @override
  ConsumerState<_MuscleDetailSheet> createState() => _MuscleDetailSheetState();
}

class _MuscleDetailSheetState extends ConsumerState<_MuscleDetailSheet> {
  String? _focused;

  void _toggleFocus(String muscle) =>
      setState(() => _focused = _focused == muscle ? null : muscle);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muscleStates = ref.watch(muscleRecoveryProvider);

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: EdgeInsets.only(top: 14.h, bottom: 6.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: isDark ? 0.24 : 0.18),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.muscleRecovery,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.02 * 26.sp,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colors.textPrimary,
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Hint line
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.tapMuscleToFocus,
                style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
              ),
            ),
          ),

          // Anatomy body (tap the body to clear focus)
          GestureDetector(
            onTap: () => setState(() => _focused = null),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: muscleStates.when(
                data: (states) => AnatomyBody(
                  muscleStates: states,
                  height: 280.h,
                  gender: ref.watch(anatomyGenderProvider),
                  basePngPath: ref.watch(activeSkinPathProvider),
                  focusedMuscle: _focused,
                ),
                loading: () => SizedBox(
                  height: 280.h,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colors.accent,
                      strokeWidth: 2.w,
                    ),
                  ),
                ),
                error: (_, __) => SizedBox(height: 280.h),
              ),
            ),
          ),

          // Ready-now chips + grouped list (scrolls as one)
          Expanded(
            child: muscleStates.when(
              data: (states) => _buildContent(context, colors, l10n, states),
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColorsTheme colors,
    AppLocalizations l10n,
    List<MuscleStateInfo> states,
  ) {
    // Cardio has no anatomy — exclude it from the recovery view.
    final muscles = states.where((m) => m.muscleGroup != 'Cardio').toList();
    final recovered =
        muscles.where((m) => _bucketOf(m) == _Bucket.ready).toList();

    // Recovered muscles live in the "Ready now" chips, not the list.
    final groups = <(_Bucket, String, Color)>[
      (_Bucket.sore, l10n.sore, colors.danger),
      (_Bucket.recovering, l10n.recovering, colors.amber),
      (_Bucket.untrained, l10n.notTrainedYet, colors.muscleUntrained),
    ];

    // Everything under the body scrolls together — chips + grouped list —
    // fading out at the bottom edge.
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.92, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 40.h),
        children: [
          if (recovered.isNotEmpty)
            _ReadyNowChips(
              recovered: recovered,
              l10n: l10n,
              colors: colors,
              focused: _focused,
              onTap: _toggleFocus,
            ),
          for (final (bucket, label, dot) in groups)
            ..._buildGroup(colors, l10n, muscles, bucket, label, dot),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(
    AppColorsTheme colors,
    AppLocalizations l10n,
    List<MuscleStateInfo> muscles,
    _Bucket bucket,
    String label,
    Color dot,
  ) {
    final rows = muscles.where((m) => _bucketOf(m) == bucket).toList();
    if (bucket != _Bucket.untrained) {
      // Most-sore first within a bucket.
      rows.sort((a, b) =>
          (a.recoveryPercent ?? 0).compareTo(b.recoveryPercent ?? 0));
    }
    if (rows.isEmpty) return const [];

    return [
      Padding(
        padding: EdgeInsets.fromLTRB(2.w, 16.h, 2.w, 8.h),
        child: Row(
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.08 * 12.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '${rows.length}',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      for (final m in rows) ...[
        _MuscleCard(
          muscle: m,
          l10n: l10n,
          colors: colors,
          tint: m.color,
          focused: _focused == m.muscleGroup,
          onTap: () => _toggleFocus(m.muscleGroup),
        ),
        SizedBox(height: 8.h),
      ],
    ];
  }
}

/// "READY NOW" header + wrap of fully-recovered muscle chips. Tapping a chip
/// focuses that muscle on the body (same single-select behaviour as list rows).
class _ReadyNowChips extends StatelessWidget {
  const _ReadyNowChips({
    required this.recovered,
    required this.l10n,
    required this.colors,
    required this.focused,
    required this.onTap,
  });
  final List<MuscleStateInfo> recovered;
  final AppLocalizations l10n;
  final AppColorsTheme colors;
  final String? focused;
  final void Function(String muscle) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.readyNow.toUpperCase(),
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1 * 12.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(child: Container(height: 1, color: colors.separator)),
            ],
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.w,
            children: [
              for (final m in recovered)
                _ReadyChip(
                  label: m.muscleGroup,
                  colors: colors,
                  focused: focused == m.muscleGroup,
                  onTap: () => onTap(m.muscleGroup),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadyChip extends StatelessWidget {
  const _ReadyChip({
    required this.label,
    required this.colors,
    required this.focused,
    required this.onTap,
  });
  final String label;
  final AppColorsTheme colors;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: focused ? colors.cardElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: focused ? colors.accent : colors.separator,
            width: focused ? 2.w : 1.w,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({
    required this.muscle,
    required this.l10n,
    required this.colors,
    required this.tint,
    required this.focused,
    required this.onTap,
  });
  final MuscleStateInfo muscle;
  final AppLocalizations l10n;
  final AppColorsTheme colors;
  final Color tint;
  final bool focused;
  final VoidCallback onTap;

  String _stateLabel() => switch (_bucketOf(muscle)) {
        _Bucket.sore => l10n.sore,
        _Bucket.recovering => l10n.recovering,
        _ => l10n.notTrainedYet,
      };

  @override
  Widget build(BuildContext context) {
    final untrained = muscle.recoveryPercent == null;
    final pct = ((muscle.recoveryPercent ?? 0) * 100).clamp(0, 100).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(18.r),
          border: focused ? Border.all(color: colors.accent, width: 2.w) : null,
        ),
        child: Row(
          children: [
            _RecoveryRing(
              fraction: pct / 100,
              tint: tint,
              track: colors.separator,
              discColor: colors.cardElevated,
              label: untrained ? '--' : '${pct.toInt()}%',
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    muscle.muscleGroup,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _restText(l10n),
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                  ),
                  SizedBox(height: 5.h),
                  // Status pill — tinted text + inset border.
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(color: tint, width: 1.5.w),
                    ),
                    child: Text(
                      _stateLabel(),
                      style: TextStyle(
                        color: tint,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _restText(AppLocalizations l10n) {
    if (muscle.state == MuscleState.undertrained || muscle.lastTrainedAt == null) {
      return l10n.notTrainedYet;
    }
    if (muscle.state == MuscleState.recovered) {
      return l10n.fullyRecovered;
    }

    final recoveryH = muscle.recoveryHours ??
        MuscleRecoveryService.recoveryHoursFor(muscle.muscleGroup);
    final recoveredAt = muscle.recoveredAt;
    final hoursRemaining = recoveredAt == null
        ? 0.0
        : (recoveredAt.difference(DateTime.now()).inMinutes / 60.0)
            .clamp(0.0, recoveryH);

    if (hoursRemaining < 1) {
      return l10n.lessThanOneHourRecovery;
    } else if (hoursRemaining < 24) {
      return l10n.hoursRestNeeded(hoursRemaining.toInt());
    }
    final days = (hoursRemaining / 24).floor();
    final hours = (hoursRemaining % 24).toInt();
    return hours == 0
        ? l10n.daysRestNeeded(days)
        : l10n.daysHoursRestNeeded(days, hours);
  }
}

/// A 58px conic donut: [tint] sweeps [fraction] of the ring (from 12 o'clock),
/// the rest is [track]; a [discColor] inner disc holds the percent [label].
class _RecoveryRing extends StatelessWidget {
  const _RecoveryRing({
    required this.fraction,
    required this.tint,
    required this.track,
    required this.discColor,
    required this.label,
  });
  final double fraction;
  final Color tint;
  final Color track;
  final Color discColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Container(
      width: 58.w,
      height: 58.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          transform: const GradientRotation(-math.pi / 2),
          colors: [tint, tint, track, track],
          stops: [0, f, f, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(color: discColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
