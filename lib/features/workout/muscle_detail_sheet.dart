import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/muscle_volume.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Shows the "Recovery Hub" bottom sheet: a tap-to-focus anatomy body with a
/// Recovery|Volume lens toggle. Recovery shows the "Ready now" chip row and a
/// status-grouped muscle list; Volume colours muscles by weekly weighted sets
/// against the 10–20 guideline over a selectable window.
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
  AnatomyViewMode _mode = AnatomyViewMode.recovery;
  VolumeWindow _window = VolumeWindow.thisWeek;

  void _toggleFocus(String muscle) =>
      setState(() => _focused = _focused == muscle ? null : muscle);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recovery = _mode == AnatomyViewMode.recovery;
    final muscleStates = ref.watch(muscleRecoveryProvider);
    final volumeInfos =
        recovery ? null : ref.watch(muscleVolumeProvider(_window));

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
                    recovery ? l10n.muscleRecovery : l10n.trainingVolume,
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
                    width: AppSizes.headerActionBtn.w,
                    height: AppSizes.headerActionBtn.w,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colors.textPrimary,
                      size: AppSizes.headerActionIcon.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recovery|Volume lens pills, plus the window switch under the
          // volume lens. Horizontally scrollable so long locales never
          // overflow the row.
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  _SelectorPill(
                    label: l10n.anatomyModeRecovery,
                    active: recovery,
                    colors: colors,
                    onTap: () =>
                        setState(() => _mode = AnatomyViewMode.recovery),
                  ),
                  SizedBox(width: 8.w),
                  _SelectorPill(
                    label: l10n.volume,
                    active: !recovery,
                    colors: colors,
                    onTap: () =>
                        setState(() => _mode = AnatomyViewMode.volume),
                  ),
                  if (!recovery) ...[
                    SizedBox(width: 14.w),
                    Container(width: 1, height: 22.h, color: colors.separator),
                    SizedBox(width: 14.w),
                    _SelectorPill(
                      label: l10n.thisWeek,
                      active: _window == VolumeWindow.thisWeek,
                      colors: colors,
                      compact: true,
                      onTap: () =>
                          setState(() => _window = VolumeWindow.thisWeek),
                    ),
                    SizedBox(width: 6.w),
                    _SelectorPill(
                      label: l10n.volumeWindowFourWeeks,
                      active: _window == VolumeWindow.fourWeeks,
                      colors: colors,
                      compact: true,
                      onTap: () =>
                          setState(() => _window = VolumeWindow.fourWeeks),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Hint line
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                recovery ? l10n.tapMuscleToFocus : l10n.volumeTargetHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
              ),
            ),
          ),

          // Anatomy body (tap the body to clear focus). Cross-fades when the
          // lens or window changes.
          GestureDetector(
            onTap: () => setState(() => _focused = null),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey('$_mode-$_window'),
                  child: recovery
                      ? muscleStates.when(
                          data: (states) => AnatomyBody(
                            muscleStates: states,
                            height: 280.h,
                            gender: ref.watch(anatomyGenderProvider),
                            basePngPath: ref.watch(activeSkinPathProvider),
                            focusedMuscle: _focused,
                          ),
                          loading: _bodyLoading,
                          error: (_, __) => SizedBox(height: 280.h),
                        )
                      : volumeInfos!.when(
                          data: _volumeBody,
                          loading: _bodyLoading,
                          error: (_, __) => SizedBox(height: 280.h),
                        ),
                ),
              ),
            ),
          ),

          // Chips + grouped list (scrolls as one)
          Expanded(
            child: recovery
                ? muscleStates.when(
                    data: (states) =>
                        _buildContent(context, colors, l10n, states),
                    loading: _listLoading,
                    error: (_, __) => const SizedBox.shrink(),
                  )
                : volumeInfos!.when(
                    data: (infos) => _buildVolumeContent(colors, l10n, infos),
                    loading: _listLoading,
                    error: (_, __) => const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bodyLoading() {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 280.h,
      child: Center(
        child: CircularProgressIndicator(
          color: colors.accent,
          strokeWidth: 2.w,
        ),
      ),
    );
  }

  Widget _listLoading() {
    final colors = AppColors.of(context);
    return Center(
      child: CircularProgressIndicator(
        color: colors.accent,
        strokeWidth: 2.w,
      ),
    );
  }

  /// The body under the volume lens: only muscles with work in the window get
  /// an overlay, tinted by the volume colour scale. `recoveryPercent` is just
  /// the overlay gate here — the tint carries the meaning.
  Widget _volumeBody(List<MuscleVolumeInfo> infos) {
    final tint = {for (final v in infos) v.muscleGroup: v.color};
    return AnatomyBody(
      muscleStates: [
        for (final v in infos)
          if (v.setsInWindow > 0)
            MuscleStateInfo(
              muscleGroup: v.muscleGroup,
              state: MuscleState.recovering,
              recoveryPercent: 1,
            ),
      ],
      height: 280.h,
      gender: ref.watch(anatomyGenderProvider),
      basePngPath: ref.watch(activeSkinPathProvider),
      tintFor: (m) => tint[m.muscleGroup] ?? AppColors.muscleUntrained,
      focusedMuscle: _focused,
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
      _groupHeader(colors, label, dot, rows.length),
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

  /// "● LABEL n" section header shared by the recovery and volume lists.
  Widget _groupHeader(
    AppColorsTheme colors,
    String label,
    Color dot,
    int count,
  ) {
    return Padding(
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
            '$count',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeContent(
    AppColorsTheme colors,
    AppLocalizations l10n,
    List<MuscleVolumeInfo> infos,
  ) {
    // Buckets ordered by attention: overshoot first, then on-target, then
    // under-target, then untrained.
    final groups = <(VolumeLevel, String, Color)>[
      (VolumeLevel.high, l10n.volumeAboveTarget, colors.danger),
      (VolumeLevel.optimal, l10n.volumeOnTarget, colors.success),
      (VolumeLevel.low, l10n.volumeBelowTarget, colors.amber),
      (VolumeLevel.none, l10n.notTrainedYet, colors.muscleUntrained),
    ];

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
          for (final (level, label, dot) in groups)
            ..._buildVolumeGroup(colors, l10n, infos, level, label, dot),
        ],
      ),
    );
  }

  List<Widget> _buildVolumeGroup(
    AppColorsTheme colors,
    AppLocalizations l10n,
    List<MuscleVolumeInfo> infos,
    VolumeLevel level,
    String label,
    Color dot,
  ) {
    final rows = infos.where((v) => v.level == level).toList()
      // Highest volume first within a bucket.
      ..sort((a, b) => b.weeklySets.compareTo(a.weeklySets));
    if (rows.isEmpty) return const [];

    return [
      _groupHeader(colors, label, dot, rows.length),
      for (final v in rows) ...[
        _VolumeCard(
          volume: v,
          l10n: l10n,
          colors: colors,
          window: _window,
          levelLabel: label,
          focused: _focused == v.muscleGroup,
          onTap: () => _toggleFocus(v.muscleGroup),
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

/// Small selector pill shared by the lens toggle and the volume-window
/// switch — same visual language as [_ReadyChip].
class _SelectorPill extends StatelessWidget {
  const _SelectorPill({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final bool active;
  final AppColorsTheme colors;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12.w : 15.w,
          vertical: compact ? 6.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: active ? colors.cardElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: active ? colors.accent : colors.separator,
            width: active ? 2.w : 1.w,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: compact ? 12.sp : 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Volume-lens list row: progress ring toward the top of the 10–20 band,
/// muscle name, window subtitle, and a level pill. Mirrors [_MuscleCard].
class _VolumeCard extends StatelessWidget {
  const _VolumeCard({
    required this.volume,
    required this.l10n,
    required this.colors,
    required this.window,
    required this.levelLabel,
    required this.focused,
    required this.onTap,
  });
  final MuscleVolumeInfo volume;
  final AppLocalizations l10n;
  final AppColorsTheme colors;
  final VolumeWindow window;
  final String levelLabel;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final untrained = volume.level == VolumeLevel.none;
    final tint = volume.color;
    final weeklySets = formatWeightedSets(volume.weeklySets);

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
              fraction: (volume.weeklySets / volumeTargetHigh).clamp(0.0, 1.0),
              tint: tint,
              track: colors.separator,
              discColor: colors.cardElevated,
              label: untrained ? '--' : weeklySets,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    volume.muscleGroup,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    untrained
                        ? l10n.notTrainedYet
                        : window == VolumeWindow.thisWeek
                            ? l10n.volumeSetsThisWeek(
                                formatWeightedSets(volume.setsInWindow),
                              )
                            : l10n.volumeSetsPerWeek(weeklySets),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  // Status pill — tinted text + inset border.
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(color: tint, width: 1.5.w),
                    ),
                    child: Text(
                      levelLabel,
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
}
