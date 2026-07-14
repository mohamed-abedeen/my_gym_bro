import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/share/widgets/anatomy_geometry.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Which figure(s) the Anatomy card shows: a single cropped view when every
/// worked muscle is visible from one side, or the whole sheet (front + back
/// side by side) when the workout spans both — e.g. leg day (quads front,
/// hamstrings/glutes back).
enum AnatomyFigureView { front, back, both }

// ── Figure geometry (405×720 design space) ──
// Single view (per the handoff): the BODY box is 620 tall with its head at
// y≈130, bleeding off the card's right and bottom edges. The skin sheets
// carry transparent padding around the body (~2% top, 9–12% bottom depending
// on the skin), so the sheet renders taller than the body box and anchors by
// TOP (the consistent edge); the feet crop past the card edge.
const _sheetAspect = 900 / 1140;
const _singleSheetHeight = 700.0;
const _singleSheetTop = 130.0 - 0.019 * _singleSheetHeight;
const _singleRightEdge = 405.0 + 38;

/// Each view occupies ~47.5% of the sheet width (front left, back right).
/// Clipping the composited [AnatomyBody] (base PNG + muscle SVGs share one
/// canvas) keeps the highlights aligned for every skin without shipping
/// cropped asset copies.
const _viewWidthFactor = 0.475;

// Both-views mode: the whole sheet, smaller, sitting between the title and a
// horizontal stat row so neither figure collides with text.
const _dualSheetHeight = 370.0;
const _dualSheetTop = 224.0;
const _dualRightEdge = 405.0 + 10;

const _calloutLeft = 30.0;
const _calloutMinGap = 20.0;
const _maxCallouts = 5;

/// A group is considered visible from a side when at least this fraction of
/// its highlight pixels are on that side (filters slivers like the biceps
/// edge seen from the back).
const _visibleShare = 0.3;

/// Anatomy template — figure hero with metallic gradient title and one lime
/// callout per worked muscle group, pointing at the measured centroid of the
/// muscle's highlight ([muscleGeometryMale]/[muscleGeometryFemale]).
class AnatomyShareCard extends ConsumerWidget {
  const AnatomyShareCard({required this.data, super.key});

  final ShareCardData data;

  /// Picks the figure view: a single side only when it shows EVERY worked
  /// group; both figures otherwise. Ties go to the side with more coverage;
  /// no groups → back (the handoff's hero view).
  static AnatomyFigureView viewFor(
    Set<String> groups,
    Map<String, MuscleGeometry> geo,
  ) {
    final known = [
      for (final g in groups)
        if (geo.containsKey(g)) g,
    ];
    if (known.isEmpty) return AnatomyFigureView.back;
    bool frontOk(String g) =>
        geo[g]!.front != null && geo[g]!.frontShare >= _visibleShare;
    bool backOk(String g) =>
        geo[g]!.back != null && 1 - geo[g]!.frontShare >= _visibleShare;
    final canFront = known.every(frontOk);
    final canBack = known.every(backOk);
    if (canFront && canBack) {
      final frontSum =
          known.fold<double>(0, (sum, g) => sum + geo[g]!.frontShare);
      return frontSum >= known.length / 2
          ? AnatomyFigureView.front
          : AnatomyFigureView.back;
    }
    if (canFront) return AnatomyFigureView.front;
    if (canBack) return AnatomyFigureView.back;
    return AnatomyFigureView.both;
  }

  /// Maps a sheet-fraction point to 405×720 card coordinates for [view].
  static Offset _toCard(Offset frac, AnatomyFigureView view) {
    if (view == AnatomyFigureView.both) {
      const sheetW = _dualSheetHeight * _sheetAspect;
      return Offset(
        _dualRightEdge - sheetW + frac.dx * sheetW,
        _dualSheetTop + frac.dy * _dualSheetHeight,
      );
    }
    const sheetW = _singleSheetHeight * _sheetAspect;
    const winW = _viewWidthFactor * sheetW;
    final winStart = view == AnatomyFigureView.back ? 1 - _viewWidthFactor : 0.0;
    return Offset(
      _singleRightEdge - winW + (frac.dx - winStart) * sheetW,
      _singleSheetTop + frac.dy * _singleSheetHeight,
    );
  }

  /// Worked groups resolved to callout rows whose dot lands on the muscle's
  /// measured centroid in the shown view. Rows are sorted by height and only
  /// nudged apart when labels would collide, capped at [_maxCallouts].
  static List<({String label, double y, double dotX})> layoutCallouts(
    Set<String> groups,
    Map<String, MuscleGeometry> geo,
    AnatomyFigureView view,
  ) {
    final targets = <({String label, Offset point})>[];
    for (final g in groups) {
      final m = geo[g];
      if (m == null) continue;
      // In single view point within that view; in dual point at the figure
      // that shows the muscle best.
      final frac = switch (view) {
        AnatomyFigureView.front => m.front,
        AnatomyFigureView.back => m.back,
        AnatomyFigureView.both =>
          m.frontShare >= 0.5 ? (m.front ?? m.back) : (m.back ?? m.front),
      };
      if (frac == null) continue;
      targets.add((label: g, point: _toCard(frac, view)));
    }
    targets.sort((a, b) => a.point.dy.compareTo(b.point.dy));

    final rows = <({String label, double y, double dotX})>[];
    var prevY = double.negativeInfinity;
    for (final t in targets.take(_maxCallouts)) {
      var y = t.point.dy;
      if (y < prevY + _calloutMinGap) y = prevY + _calloutMinGap;
      rows.add((label: t.label, y: y, dotX: t.point.dx));
      prevY = y;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit = ref.watch(weightUnitProvider);
    final gender = ref.watch(anatomyGenderProvider);
    final title = splitShareTitle(data.workoutName);
    final geo = gender == AnatomyGender.male
        ? muscleGeometryMale
        : muscleGeometryFemale;
    final groups = data.workedMuscleGroups;
    final view = viewFor(groups, geo);
    final callouts = layoutCallouts(groups, geo, view);

    return ShareCardFrame(
      gradient: const RadialGradient(
        center: Alignment(0.6, -0.1), // ≈ "at 80% 45%"
        radius: 1.2,
        colors: [Color(0xFF131316), kShareCardBg],
        stops: [0, 0.65],
      ),
      child: Stack(
        children: [
          // Figure(s), bleeding off the right (and bottom in single view).
          Positioned(
            top: view == AnatomyFigureView.both
                ? _dualSheetTop
                : _singleSheetTop,
            right: view == AnatomyFigureView.both
                ? _dualRightEdge - 405
                : _singleRightEdge - 405,
            child: _AnatomyFigure(groups: groups, view: view),
          ),

          // Callout rows — the dot's centre lands on the muscle centroid.
          for (final c in callouts)
            Positioned(
              top: c.y - 6,
              left: _calloutLeft,
              right: ShareCardFrame.designSize.width - c.dotX - 2.5,
              child: _CalloutRow(label: c.label),
            ),

          // Content overlay.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShareMasthead(data: data),
                  const SizedBox(height: 22),

                  // Title: metallic line + outlined line + date.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ShareMetallicText(
                      title.line1.toUpperCase(),
                      style: shareArchivo(
                        41,
                        width: 112,
                        letterSpacing: -1.2,
                        height: 0.94,
                      ),
                    ),
                  ),
                  if (title.line2 != null)
                    Text(
                      title.line2!.toUpperCase(),
                      maxLines: 1,
                      style: shareOutlinedArchivo(41),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    shareDateLine(data.date ?? DateTime.now(), locale),
                    style: shareMono(
                      10,
                      letterSpacing: 2,
                      color: kShareTextTertiary,
                    ),
                  ),

                  const Spacer(),

                  // Stats: a left column beside the single figure; a full-
                  // width row under the pair in both-views mode.
                  if (view == AnatomyFigureView.both)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _VolumeStat(data: data, unit: unit)),
                        _MiniStat(
                          value: '${data.totalSets}',
                          label: l10n.sets,
                        ),
                        const SizedBox(width: 24),
                        _MiniStat(
                          value: formatShareDuration(data.durationSeconds),
                          label: l10n.duration,
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: 172,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _VolumeStat(data: data, unit: unit),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _MiniStat(
                                value: '${data.totalSets}',
                                label: l10n.sets,
                              ),
                              const SizedBox(width: 24),
                              _MiniStat(
                                value:
                                    formatShareDuration(data.durationSeconds),
                                label: l10n.duration,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const ShareFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The anatomy composite ([AnatomyBody]: skin PNG + tinted muscle SVGs on a
/// shared canvas), clipped to one view — or the whole sheet in
/// [AnatomyFigureView.both] mode.
class _AnatomyFigure extends ConsumerWidget {
  const _AnatomyFigure({required this.groups, required this.view});

  final Set<String> groups;
  final AnatomyFigureView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = AnatomyBody(
      height: view == AnatomyFigureView.both
          ? _dualSheetHeight
          : _singleSheetHeight,
      gender: ref.watch(anatomyGenderProvider),
      basePngPath: ref.watch(activeSkinPathProvider),
      highlightColor: kShareAccent,
      muscleStates: [
        for (final g in groups)
          MuscleStateInfo(
            muscleGroup: g,
            state: MuscleState.recovering,
            recoveryPercent: 0,
          ),
      ],
    );
    if (view == AnatomyFigureView.both) return body;
    return ClipRect(
      child: Align(
        alignment: view == AnatomyFigureView.back
            ? Alignment.centerRight
            : Alignment.centerLeft,
        widthFactor: _viewWidthFactor,
        child: body,
      ),
    );
  }
}

class _CalloutRow extends StatelessWidget {
  const _CalloutRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: shareMono(10, color: kShareAccent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xB3F0FF00), Color(0x26F0FF00)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: kShareAccent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// The lime volume figure with its small unit suffix + mono label.
class _VolumeStat extends StatelessWidget {
  const _VolumeStat({required this.data, required this.unit});

  final ShareCardData data;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final volume = shareVolumeParts(data.totalVolumeKg, unit);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: volume.number,
              style: shareArchivo(
                38,
                weight: 800,
                letterSpacing: -1.2,
                height: 1,
                color: kShareAccent,
              ),
              children: [
                TextSpan(
                  text: ' ${volume.unit}',
                  style: shareArchivo(
                    18,
                    weight: 600,
                    height: 1,
                    color: kShareAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _StatLabel(l10n.volume),
      ],
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: shareMono(9, letterSpacing: 2),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: shareArchivo(
            24,
            weight: 800,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        _StatLabel(label),
      ],
    );
  }
}
