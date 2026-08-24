import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/muscle_volume.dart';
import 'package:my_gym_bro/features/workout/share/widgets/anatomy_geometry.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Shows the "Muscle Recovery" bottom sheet (2026-08 redesign, built from the
/// Figma handoff):
///
/// - **Recovery lens** — the full anatomy sheet (back + front side by side)
///   with a status-grouped muscle list underneath; tapping a list row focuses
///   that muscle on the body.
/// - **Volume lens** — the body goes immersive and interactive: one view
///   fills the sheet while the other peeks in from the edge, blurred; drag
///   horizontally to swap views, tap a muscle on the body itself to focus
///   it, and below-target muscles get lime callout lines.
///
/// The mode/window chips sit pinned at the bottom under the hint caption,
/// per the design.
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

  void _setMode(AnatomyViewMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _focused = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final recovery = _mode == AnatomyViewMode.recovery;
    final muscleStates = ref.watch(muscleRecoveryProvider);
    final volumeInfos =
        recovery ? null : ref.watch(muscleVolumeProvider(_window));

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36.r)),
      ),
      child: Column(
        children: [
          // Header — title + circular close, per the handoff.
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 22.h, 20.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.muscleRecovery,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02 * 24.sp,
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

          // Body area. Recovery: the dual-view body at fixed height, with the
          // caption + chips directly under it and the grouped list filling
          // the rest (handoff frame 1). Volume: the immersive pager fills all
          // space, pushing caption + chips to the bottom edge (frames 2-4).
          if (recovery)
            GestureDetector(
              onTap: () => setState(() => _focused = null),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: muscleStates.when(
                  data: (states) => AnatomyBody(
                    muscleStates: states,
                    height: 400.h,
                    gender: ref.watch(anatomyGenderProvider),
                    basePngPath: ref.watch(activeSkinPathProvider),
                    focusedMuscle: _focused,
                  ),
                  loading: () => SizedBox(height: 400.h, child: _loading()),
                  error: (_, __) => SizedBox(height: 400.h),
                ),
              ),
            )
          else
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_window),
                  child: volumeInfos!.when(
                    data: (infos) => _VolumeBodyPager(
                      infos: infos,
                      gender: ref.watch(anatomyGenderProvider),
                      skinPath: ref.watch(activeSkinPathProvider),
                      focused: _focused,
                      onFocus: _toggleFocus,
                      colors: colors,
                      l10n: l10n,
                    ),
                    loading: _loading,
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // Hint caption — centered above the chip bar, per the handoff.
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
            child: Text(
              recovery ? l10n.tapMuscleToFocus : l10n.volumeTargetHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Bottom chip bar: lens chips always, window chips in volume mode.
          // Scrollable so long locales never overflow.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                _ModeChip(
                  label: l10n.anatomyModeRecovery,
                  active: recovery,
                  colors: colors,
                  onTap: () => _setMode(AnatomyViewMode.recovery),
                ),
                SizedBox(width: 8.w),
                _ModeChip(
                  label: l10n.volume,
                  active: !recovery,
                  colors: colors,
                  onTap: () => _setMode(AnatomyViewMode.volume),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: recovery
                      ? const SizedBox.shrink()
                      : Row(
                          children: [
                            SizedBox(width: 16.w),
                            _ModeChip(
                              label: l10n.thisWeek,
                              active: _window == VolumeWindow.thisWeek,
                              colors: colors,
                              onTap: () => setState(
                                  () => _window = VolumeWindow.thisWeek),
                            ),
                            SizedBox(width: 8.w),
                            _ModeChip(
                              label: l10n.volumeWindowFourWeeks,
                              active: _window == VolumeWindow.fourWeeks,
                              colors: colors,
                              onTap: () => setState(
                                  () => _window = VolumeWindow.fourWeeks),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Recovery: the grouped list fills the space under the chip bar.
          if (recovery)
            Expanded(
              child: muscleStates.when(
                data: (states) => _buildList(colors, l10n, states),
                loading: _loading,
                error: (_, __) => const SizedBox.shrink(),
              ),
            )
          else
            SizedBox(height: 14.h),
        ],
      ),
    );
  }

  Widget _loading() {
    final colors = AppColors.of(context);
    return Center(
      child: CircularProgressIndicator(
        color: colors.accent,
        strokeWidth: 2.w,
      ),
    );
  }

  Widget _buildList(
    AppColorsTheme colors,
    AppLocalizations l10n,
    List<MuscleStateInfo> states,
  ) {
    // Cardio has no anatomy — exclude it from the recovery view.
    final muscles = states.where((m) => m.muscleGroup != 'Cardio').toList();

    // Grouped rows, most-urgent bucket first (handoff frame 1: the list
    // opens on "Sore" with its ring rows).
    final groups = <(_Bucket, String, Color)>[
      (_Bucket.sore, l10n.sore, colors.danger),
      (_Bucket.recovering, l10n.recovering, colors.amber),
      (_Bucket.ready, l10n.readyTitle, colors.success),
      (_Bucket.untrained, l10n.notTrainedYet, colors.muscleUntrained),
    ];

    // The grouped list fades out at the bottom edge.
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.92, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 40.h),
        children: [
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

  /// "● LABEL n" section header for the grouped recovery list.
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Volume lens — immersive draggable body
// ─────────────────────────────────────────────────────────────────────────────

/// Fraction of the anatomy sheet's width one view (back or front) occupies —
/// same crop the share card uses (2026-08 art: back left, front right).
const double _viewWidthFactor = 0.475;
const double _sheetAspect = 900 / 1140;

/// Page 0 = back view, page 1 = front view (the art sheet's left → right
/// order, so dragging matches the underlying canvas).
class _VolumeBodyPager extends StatefulWidget {
  const _VolumeBodyPager({
    required this.infos,
    required this.gender,
    required this.skinPath,
    required this.focused,
    required this.onFocus,
    required this.colors,
    required this.l10n,
  });

  final List<MuscleVolumeInfo> infos;
  final AnatomyGender gender;
  final String skinPath;
  final String? focused;
  final void Function(String muscle) onFocus;
  final AppColorsTheme colors;
  final AppLocalizations l10n;

  @override
  State<_VolumeBodyPager> createState() => _VolumeBodyPagerState();
}

class _VolumeBodyPagerState extends State<_VolumeBodyPager> {
  // viewportFraction < 1 keeps the other view peeking in from the edge,
  // blurred — the handoff's "drag between sides" interaction. The fraction
  // depends on the actual body width vs viewport width, so the controller is
  // created (and on resize, replaced) inside the LayoutBuilder.
  PageController? _controller;
  int _current = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// (Re)builds the controller for the given viewport fraction.
  PageController _controllerFor(double fraction) {
    final existing = _controller;
    if (existing != null &&
        (existing.viewportFraction - fraction).abs() < 0.05) {
      return existing;
    }
    // Replace on first build or a real size change; dispose the detached one
    // after this frame.
    if (existing != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => existing.dispose());
    }
    return _controller = PageController(
      viewportFraction: fraction,
      initialPage: _current,
    );
  }

  Map<String, MuscleGeometry> get _geo => widget.gender == AnatomyGender.male
      ? muscleGeometryMale
      : muscleGeometryFemale;

  /// Sheet-fraction centroid of [group] in the view shown on [page], or null
  /// when the muscle isn't visible from that side.
  Offset? _pointFor(String group, int page) {
    final m = _geo[group];
    if (m == null) return null;
    return page == 0 ? m.back : m.front;
  }

  void _handleTap(
    TapUpDetails details,
    int page,
    double sheetW,
    double slotW,
    double h,
  ) {
    // Local position inside the cropped view box → sheet fractions. Page 0
    // (back) shows the sheet's left edge; page 1 (front) its right edge.
    final local = details.localPosition;
    final fx = page == 0
        ? local.dx / sheetW
        : (sheetW - slotW + local.dx) / sheetW;
    final fy = local.dy / h;

    // Nearest muscle centroid within a generous thumb radius.
    String? best;
    var bestDist = double.infinity;
    for (final v in widget.infos) {
      final p = _pointFor(v.muscleGroup, page);
      if (p == null) continue;
      final dx = (p.dx - fx) * sheetW;
      final dy = (p.dy - fy) * h;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        best = v.muscleGroup;
      }
    }
    final threshold = h * 0.08;
    if (best != null && bestDist <= threshold * threshold) {
      widget.onFocus(best);
    } else if (widget.focused != null) {
      // Tap on empty body space clears the focus.
      widget.onFocus(widget.focused!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = {for (final v in widget.infos) v.muscleGroup: v.color};
    final trained = [
      for (final v in widget.infos)
        if (v.setsInWindow > 0)
          MuscleStateInfo(
            muscleGroup: v.muscleGroup,
            state: MuscleState.recovering,
            recoveryPercent: 1,
          ),
    ];
    final focusedInfo = widget.focused == null
        ? null
        : widget.infos
            .where((v) => v.muscleGroup == widget.focused)
            .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight - 8.h;
        final sheetW = h * _sheetAspect;
        final viewW = sheetW * _viewWidthFactor;
        // The page slot is slightly narrower than the natural view crop —
        // neighbouring views overlap a little and a generous slice of the
        // other side peeks in at the edge, like the handoff frames. slotW is
        // the real on-screen box width every coordinate below uses.
        final fraction =
            ((viewW - 44.w) / constraints.maxWidth).clamp(0.35, 0.92);
        final slotW = fraction * constraints.maxWidth;
        final controller = _controllerFor(fraction);

        return Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: 2,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final page = controller.hasClients &&
                            controller.position.haveDimensions
                        ? controller.page ?? _current.toDouble()
                        : _current.toDouble();
                    final d = (page - index).abs().clamp(0.0, 1.0);
                    // The non-foreground view blurs and recedes slightly.
                    final body = Transform.scale(
                      scale: 1 - 0.06 * d,
                      child: child,
                    );
                    return Center(
                      child: d < 0.01
                          ? body
                          : ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 9 * d,
                                sigmaY: 9 * d,
                              ),
                              child: body,
                            ),
                    );
                  },
                  child: SizedBox(
                    width: slotW,
                    height: h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (t) => _handleTap(t, index, sheetW, slotW, h),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // OverflowBox lets the full-width anatomy sheet lay
                          // out at its natural size inside the narrow view
                          // crop — a plain Align would constrain its width
                          // and shrink the whole figure to fit.
                          ClipRect(
                            child: OverflowBox(
                              minWidth: sheetW,
                              maxWidth: sheetW,
                              alignment: index == 0
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: AnatomyBody(
                                muscleStates: trained,
                                height: h,
                                gender: widget.gender,
                                basePngPath: widget.skinPath,
                                tintFor: (m) =>
                                    tint[m.muscleGroup] ??
                                    AppColors.muscleUntrained,
                                focusedMuscle: widget.focused,
                              ),
                            ),
                          ),
                          // Below-target callouts on the foreground view only.
                          if (_current == index)
                            ..._buildCallouts(index, sheetW, slotW, h),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Focused muscle detail — floating pill, since the volume lens
            // has no list to carry the numbers.
            if (focusedInfo != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 6.h,
                child: Center(child: _focusPill(focusedInfo)),
              ),
          ],
        );
      },
    );
  }

  /// Lime dot + connector line + label for every below-target muscle visible
  /// in this view, stacked with a minimum vertical gap (handoff style).
  List<Widget> _buildCallouts(
    int page,
    double sheetW,
    double slotW,
    double h,
  ) {
    // Sheet fractions → pixel coords inside the slot box (the inverse of
    // [_handleTap]'s mapping).
    final xShift = page == 0 ? 0.0 : sheetW - slotW;
    final targets = <({String group, Offset point})>[];
    for (final v in widget.infos) {
      if (v.level != VolumeLevel.low) continue;
      final p = _pointFor(v.muscleGroup, page);
      if (p == null) continue;
      targets.add((
        group: v.muscleGroup,
        point: Offset(p.dx * sheetW - xShift, p.dy * h),
      ));
    }
    if (targets.isEmpty) return const [];
    targets.sort((a, b) => a.point.dy.compareTo(b.point.dy));

    const maxCallouts = 4;
    final minGap = 36.h;
    // The dot sits at a fixed x with the label text growing to its right
    // (past the crop edge, over the blurred neighbour — handoff style); the
    // connector line runs dot → muscle so it never crosses the text.
    final dotX = slotW - 96.w;

    final rows = <({String group, Offset point, double y})>[];
    var prevY = double.negativeInfinity;
    for (final t in targets.take(maxCallouts)) {
      var y = (t.point.dy - 60.h).clamp(8.0, h - 60.h);
      if (y < prevY + minGap) y = prevY + minGap;
      rows.add((group: t.group, point: t.point, y: y));
      prevY = y;
    }

    return [
      // Connector lines under the labels.
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _CalloutLinePainter(
              color: widget.colors.accent,
              lines: [
                for (final r in rows)
                  (from: Offset(dotX + 4.w, r.y + 10.h), to: r.point),
              ],
            ),
          ),
        ),
      ),
      for (final r in rows)
        Positioned(
          top: r.y,
          left: dotX,
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: widget.colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                SizedBox(
                  width: 110.w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.colors.textPrimary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.l10n.volumeBelowTarget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.colors.accent,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _focusPill(MuscleVolumeInfo info) {
    final untrained = info.level == VolumeLevel.none;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: widget.colors.cardElevated,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: info.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            untrained
                ? '${info.muscleGroup} · ${widget.l10n.notTrainedYet}'
                : '${info.muscleGroup} · ${widget.l10n.volumeSetsPerWeek(
                    formatWeightedSets(info.weeklySets),
                  )}',
            style: TextStyle(
              color: widget.colors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin connector lines from each callout label to its muscle centroid.
class _CalloutLinePainter extends CustomPainter {
  const _CalloutLinePainter({required this.color, required this.lines});
  final Color color;
  final List<({Offset from, Offset to})> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final l in lines) {
      canvas.drawLine(l.from, l.to, paint);
      canvas.drawCircle(l.to, 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CalloutLinePainter old) =>
      old.color != color || old.lines != lines;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom-bar chip (handoff style): filled accent when active, elevated dark
/// when idle.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
  });
  final String label;
  final bool active;
  final AppColorsTheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: active ? colors.accent : colors.cardElevated,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : colors.textPrimary,
            fontSize: 11.sp,
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
        _Bucket.ready => l10n.readyTitle,
        _Bucket.untrained => l10n.notTrainedYet,
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
