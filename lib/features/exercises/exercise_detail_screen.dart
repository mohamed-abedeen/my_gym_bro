import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// `show DateFormat` keeps intl's own TextDirection from shadowing Flutter's.
import 'package:intl/intl.dart' show DateFormat;
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/exercises/exercise_detail_format.dart';
import 'package:my_gym_bro/features/exercises/lift_rank/lift_rank_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/share/exercise_share_data.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

enum _TimePeriod { last3Months, last6Months, allTime }

// ═══════════════════════════════════════════════════════════════════
// Brand typography — the share cards' Archivo / IBM Plex Mono voice
// ═══════════════════════════════════════════════════════════════════

/// Archivo display style. [tracking] is letter-spacing in em (-0.02 = -2 %).
TextStyle _archivo(
  double size, {
  required Color color,
  double weight = 800,
  double? tracking,
  double height = 1,
}) =>
    TextStyle(
      fontFamily: 'Archivo',
      fontSize: size,
      color: color,
      fontWeight: FontWeight.values[weight ~/ 100 - 1],
      fontVariations: [FontVariation('wght', weight)],
      letterSpacing: tracking == null ? null : tracking * size,
      height: height,
    );

/// IBM Plex Mono label style. [tracking] is letter-spacing in em.
TextStyle _mono(
  double size, {
  required Color color,
  FontWeight weight = FontWeight.w400,
  double tracking = 0,
}) =>
    TextStyle(
      fontFamily: 'IBMPlexMono',
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: tracking * size,
    );

// ═══════════════════════════════════════════════════════════════════
// ExerciseDetailScreen — full-bleed GIF header, Summary / History / How to
// ═══════════════════════════════════════════════════════════════════

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({
    required this.exercise,
    super.key,
  });

  final Exercise exercise;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _TimePeriod _timePeriod = _TimePeriod.last3Months;

  /// Baseline cutoff for the "vs last month" delta. Fixed once so the
  /// provider key — and its query — stays stable while the screen is open.
  late final DateTime _monthAgo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    final now = DateTime.now();
    _monthAgo = DateTime(now.year, now.month - 1, now.day);
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  DateTime? get _fromDate {
    final now = DateTime.now();
    return switch (_timePeriod) {
      _TimePeriod.last3Months => DateTime(now.year, now.month - 3, now.day),
      _TimePeriod.last6Months => DateTime(now.year, now.month - 6, now.day),
      _TimePeriod.allTime => null,
    };
  }

  /// Opens the exercise share card with all-time stats. The reads resolve
  /// instantly when the summary tab already loaded them; the volume history
  /// is re-read unwindowed so the card's trend ignores the selected period.
  Future<void> _share() async {
    final exercise = widget.exercise;
    final records = await ref.read(
      exercisePersonalRecordsProvider(exercise.exerciseId).future,
    );
    final rank = await ref.read(liftRankProvider(exercise.exerciseId).future);
    final history = await ref.read(
      exerciseVolumeWithDatesProvider(
        ExerciseVolumeParams(exercise.exerciseId),
      ).future,
    );
    if (!mounted) return;
    unawaited(
      context.push(
        AppRoutes.shareExercise,
        extra: ExerciseShareData.fromStats(
          exerciseName: exercise.name,
          muscleGroup: exercise.muscleGroup,
          records: records,
          rank: rank,
          volumeHistory: history,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final exercise = widget.exercise;
    final unit = ref.watch(weightUnitProvider);

    final volumeAsync = ref.watch(
      exerciseVolumeWithDatesProvider(
        ExerciseVolumeParams(exercise.exerciseId, from: _fromDate),
      ),
    );
    final recordsAsync =
        ref.watch(exercisePersonalRecordsProvider(exercise.exerciseId));
    final historyAsync =
        ref.watch(exerciseSessionHistoryProvider(exercise.exerciseId));
    final liftRankAsync = ref.watch(liftRankProvider(exercise.exerciseId));
    final prior1rmAsync = ref.watch(
      exerciseBest1rmBeforeProvider(
        (exerciseId: exercise.exerciseId, before: _monthAgo),
      ),
    );

    return Scaffold(
      backgroundColor: colors.background,
      // No top SafeArea: the GIF header runs under the status bar and the
      // floating buttons offset themselves by the inset.
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _Header(
              exercise: exercise,
              colors: colors,
              l10n: l10n,
              tabController: _tabController,
              onBack: () => Navigator.of(context).pop(),
              onShare: () => unawaited(_share()),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _SummaryTab(
              colors: colors,
              l10n: l10n,
              unit: unit,
              timePeriod: _timePeriod,
              volumeAsync: volumeAsync,
              recordsAsync: recordsAsync,
              liftRankAsync: liftRankAsync,
              prior1rmAsync: prior1rmAsync,
              onTimePeriodChanged: (p) => setState(() => _timePeriod = p),
            ),
            _HistoryTab(
              colors: colors,
              l10n: l10n,
              unit: unit,
              historyAsync: historyAsync,
            ),
            _HowToTab(
              exercise: exercise,
              colors: colors,
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header — full-bleed GIF, title block, glass segmented control
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.exercise,
    required this.colors,
    required this.l10n,
    required this.tabController,
    required this.onBack,
    required this.onShare,
  });

  final Exercise exercise;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final TabController tabController;
  final VoidCallback onBack;
  final VoidCallback onShare;

  static const _imageHeight = 400.0;

  /// How far the title block rises into the image's bottom fade.
  static const _titleOverlap = 56.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final imageH = _imageHeight.h;

    return Stack(
      children: [
        SizedBox(
          height: imageH,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: colors.panelBackground,
                child: _gif(),
              ),
              // Dim the status-bar zone, then fade the image into the page.
              // Each transparent stop matches its solid neighbour so the
              // interpolation never passes through a muddy grey.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.3, 0.55, 1],
                    colors: [
                      Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      Colors.black.withValues(alpha: 0),
                      colors.background.withValues(alpha: 0),
                      colors.background,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.contentPaddingH.w,
            imageH - _titleOverlap.h,
            AppSizes.contentPaddingH.w,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _muscleLine(),
              SizedBox(height: 6.h),
              Text(
                titleCase(exercise.name),
                style: _archivo(
                  34.sp,
                  tracking: -0.02,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 20.h),
              _SegmentedTabs(
                controller: tabController,
                colors: colors,
                l10n: l10n,
              ),
            ],
          ),
        ),
        Positioned(
          top: topInset + 10.h,
          left: AppSizes.contentPaddingH.w,
          right: AppSizes.contentPaddingH.w,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderButton(
                icon: Icons.arrow_back_rounded,
                colors: colors,
                onTap: onBack,
              ),
              _HeaderButton(
                icon: Icons.ios_share_rounded,
                colors: colors,
                onTap: onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gif() {
    final url = exercise.gifUrl;
    if (url == null) {
      return Center(
        child: Icon(
          Icons.fitness_center_rounded,
          color: colors.textSecondary,
          size: 48.sp,
        ),
      );
    }
    return CachedNetworkImage(
      cacheManager: ExerciseGifCache.instance,
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.4),
      placeholder: (_, __) => Center(
        child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
      ),
      errorWidget: (_, __, ___) => Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: colors.textSecondary,
          size: 48.sp,
        ),
      ),
    );
  }

  /// `PECTORALS · TRICEPS, SHOULDERS · BARBELL` — primary muscles in accent,
  /// then secondary muscles and equipment in secondary text.
  Widget _muscleLine() {
    final primary = _csv(exercise.targetMuscles);
    final secondary = _csv(exercise.secondaryMuscles);
    final equipment = _csv(exercise.equipments);
    final lead = primary.isNotEmpty
        ? primary.join(', ')
        : (exercise.muscleGroup ?? '');
    final rest = [
      if (secondary.isNotEmpty) secondary.join(', '),
      if (equipment.isNotEmpty) equipment.join(', '),
    ].join(' · ');
    if (lead.isEmpty && rest.isEmpty) return const SizedBox.shrink();

    return Text.rich(
      TextSpan(
        children: [
          if (lead.isNotEmpty)
            TextSpan(
              text: lead.toUpperCase(),
              style: _mono(
                11.sp,
                weight: FontWeight.w500,
                tracking: 0.08,
                color: colors.accent,
              ),
            ),
          if (rest.isNotEmpty)
            TextSpan(
              text: '${lead.isEmpty ? '' : ' · '}${rest.toUpperCase()}',
              style: _mono(
                11.sp,
                weight: FontWeight.w500,
                tracking: 0.08,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  static List<String> _csv(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final AppColorsTheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassButton(
      width: AppSizes.headerActionBtn.w,
      height: AppSizes.headerActionBtn.w,
      opacity: 0.15,
      radius: (AppSizes.headerActionBtn / 2).r,
      onTap: onTap,
      child: Icon(
        icon,
        color: colors.textPrimary,
        size: AppSizes.headerActionIcon.sp,
      ),
    );
  }
}

/// Three-way glass segmented control bound to the [TabController]. The
/// accent pill follows the controller's animation, so it slides on a tap
/// (200 ms, ease-out) and tracks the finger during a swipe.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.controller,
    required this.colors,
    required this.l10n,
  });

  final TabController controller;
  final AppColorsTheme colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final labels = [l10n.tabSummary, l10n.tabHistory, l10n.howTo];
    final animation = controller.animation!;

    return GlassSurface(
      radius: AppRadius.button,
      padding: EdgeInsets.all(4.w),
      child: SizedBox(
        height: 38.h,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Align(
                alignment: Alignment(
                  (animation.value / (labels.length - 1) * 2 - 1)
                      .clamp(-1.0, 1.0),
                  0,
                ),
                child: child,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.animateTo(
                        i,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: controller.index == i
                                ? FontWeight.w700
                                : FontWeight.w600,
                            // Text on the accent pill is black in both themes.
                            color: controller.index == i
                                ? colors.black
                                : colors.textSecondary,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 1 — Summary
// ═══════════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.colors,
    required this.l10n,
    required this.unit,
    required this.timePeriod,
    required this.volumeAsync,
    required this.recordsAsync,
    required this.liftRankAsync,
    required this.prior1rmAsync,
    required this.onTimePeriodChanged,
  });

  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final WeightUnit unit;
  final _TimePeriod timePeriod;
  final AsyncValue<List<({DateTime date, double volume})>> volumeAsync;
  final AsyncValue<ExercisePersonalRecords> recordsAsync;
  final AsyncValue<LiftRank?> liftRankAsync;
  final AsyncValue<double?> prior1rmAsync;
  final ValueChanged<_TimePeriod> onTimePeriodChanged;

  /// Weight in the display unit, or an em dash when never logged.
  String _weight(double? kg, {int decimals = 1, bool withUnit = true}) =>
      kg == null
          ? '—'
          : formatWeight(kg, unit, decimals: decimals, withUnit: withUnit);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 28.h),
          _SectionLabel(
            label: l10n.personalBests,
            trailing: l10n.allTime.toLowerCase(),
            colors: colors,
          ),
          SizedBox(height: 12.h),
          _buildHero(),
          SizedBox(height: 10.h),
          _buildTiles(context),
          SizedBox(height: 28.h),
          Row(
            children: [
              Expanded(
                child: _SectionLabel(
                  label: l10n.volumePerSession,
                  colors: colors,
                ),
              ),
              SizedBox(width: 12.w),
              _PeriodSwitch(
                value: timePeriod,
                colors: colors,
                l10n: l10n,
                onChanged: onTimePeriodChanged,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildChart(),
          SizedBox(height: 28.h),
          _SectionLabel(label: l10n.setRecords, colors: colors),
          SizedBox(height: 12.h),
          _buildSetRecords(),
          SizedBox(height: 60.h + bottomInset),
        ],
      ),
    );
  }

  // ── 1RM hero card ──────────────────────────────────────────────────

  Widget _buildHero() {
    return recordsAsync.when(
      loading: () => GlassSurface(
        height: 150.h,
        child: Center(
          child:
              CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (records) {
        final liftRank = liftRankAsync.valueOrNull;
        final best = records.best1rm;
        final prior = prior1rmAsync.valueOrNull;
        // Change against the best 1RM on record a month ago. A first month
        // has no baseline and an unchanged record has nothing to say, so
        // the chip hides in both cases.
        final delta = best == null || prior == null ? null : best - prior;

        return GlassSurface(
          padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.oneRepMaxEstimated.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _mono(
                        11.sp,
                        tracking: 0.06,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _weight(best, withUnit: false),
                              style: _archivo(
                                48.sp,
                                tracking: -0.03,
                                color: colors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' ${weightUnitLabel(unit)}',
                              style: _archivo(
                                18.sp,
                                weight: 600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (delta != null && delta.abs() >= 0.05) ...[
                      SizedBox(height: 8.h),
                      _DeltaChip(
                        deltaKg: delta,
                        unit: unit,
                        colors: colors,
                        l10n: l10n,
                      ),
                    ],
                  ],
                ),
              ),
              if (liftRank != null) ...[
                SizedBox(width: 16.w),
                _RankColumn(liftRank: liftRank, colors: colors, l10n: l10n),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── PB tiles ───────────────────────────────────────────────────────

  Widget _buildTiles(BuildContext context) {
    final records = recordsAsync.valueOrNull;
    final dateFmt =
        DateFormat.MMMd(Localizations.localeOf(context).toString());
    String dateOf(DateTime? d) =>
        d == null ? '' : dateFmt.format(d.toLocal());
    String caption(List<String> parts) =>
        parts.where((p) => p.isNotEmpty).join(' · ');

    final heaviest = records?.maxWeightSet;
    final bestSet = records?.bestSetVolumeSet;
    final bestSession = records?.bestSessionVolume;
    final session =
        bestSession == null ? null : compactVolume(bestSession, unit);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PbTile(
              label: l10n.pbHeaviest,
              value: _weight(records?.maxWeight, withUnit: false),
              unit: weightUnitLabel(unit),
              caption: heaviest == null
                  ? null
                  : caption(['× ${heaviest.reps}', dateOf(heaviest.date)]),
              colors: colors,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _PbTile(
              label: l10n.pbBestSet,
              value: _weight(
                records?.bestSetVolume,
                decimals: 0,
                withUnit: false,
              ),
              unit: weightUnitLabel(unit),
              caption: bestSet == null
                  ? null
                  : caption([
                      '${formatWeight(bestSet.weight, unit)} '
                          '× ${bestSet.reps}',
                      dateOf(bestSet.date),
                    ]),
              colors: colors,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _PbTile(
              label: l10n.pbBestSession,
              value: session?.value ?? '—',
              unit: session?.unit ?? weightUnitLabel(unit),
              caption: bestSession == null
                  ? null
                  : caption([
                      formatWeight(
                        bestSession,
                        unit,
                        decimals: 0,
                        withUnit: true,
                      ),
                      dateOf(records?.bestSessionDate),
                    ]),
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  // ── Volume chart ───────────────────────────────────────────────────

  Widget _buildChart() {
    return volumeAsync.when(
      loading: () => _ChartCard(
        height: 200.h,
        colors: colors,
        child: Center(
          child:
              CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) {
          return _ChartCard(
            height: 200.h,
            colors: colors,
            child: Center(
              child: Text(
                l10n.noData,
                style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
              ),
            ),
          );
        }
        return _VolumeChart(
          data: data,
          colors: colors,
          unit: unit,
          l10n: l10n,
        );
      },
    );
  }

  // ── Set records ────────────────────────────────────────────────────

  Widget _buildSetRecords() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
      ),
      child: recordsAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.all(16.h),
          child: Center(
            child: CircularProgressIndicator(
              color: colors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (records) => Column(
          children: [
            _SetRecordRow(
              label: l10n.heaviestWeight,
              value: _weight(records.maxWeight),
              colors: colors,
            ),
            _SetRecordRow(
              label: l10n.oneRepMax,
              value: _weight(records.best1rm),
              colors: colors,
            ),
            _SetRecordRow(
              label: l10n.bestSetVolumeLabel,
              value: _weight(records.bestSetVolume, decimals: 0),
              colors: colors,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono, uppercase section label with an optional right-aligned caption.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.colors,
    this.trailing,
  });

  final String label;
  final AppColorsTheme colors;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _mono(
        11.sp,
        weight: FontWeight.w600,
        tracking: 0.08,
        color: colors.textSecondary,
      ),
    );
    final caption = trailing;
    if (caption == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: text),
        Padding(
          padding: EdgeInsets.only(left: 12.w),
          child: Text(
            caption,
            style: _mono(11.sp, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// `▲ 2.5 kg vs last month` pill under the hero 1RM.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.deltaKg,
    required this.unit,
    required this.colors,
    required this.l10n,
  });

  final double deltaKg;
  final WeightUnit unit;
  final AppColorsTheme colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final up = deltaKg > 0;
    final tone = up ? colors.trendPositive : colors.trendNegative;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${up ? '▲' : '▼'} '
                  '${formatWeight(deltaKg.abs(), unit, withUnit: true)}',
              style: _mono(11.sp, weight: FontWeight.w600, color: tone),
            ),
            TextSpan(
              text: ' ${l10n.vsLastMonth}',
              style: _mono(11.sp, color: colors.textSecondary),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Badge, tier label and progress-to-next for a rankable lift.
class _RankColumn extends StatelessWidget {
  const _RankColumn({
    required this.liftRank,
    required this.colors,
    required this.l10n,
  });

  final LiftRank liftRank;
  final AppColorsTheme colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rank = liftRank.rank;
    final next = rank.next;
    final tint = rankColors(rank.tier);
    final progress =
        next == null ? 1.0 : liftRank.progressToNext.clamp(0.0, 1.0);

    return SizedBox(
      width: 96.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankBadge(rank, size: 72.w),
          SizedBox(height: 6.h),
          Text(
            rank.label(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _archivo(14.sp, color: colors.textPrimary, height: 1.2),
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: SizedBox(
              width: 80.w,
              height: 4.h,
              child: Stack(
                children: [
                  ColoredBox(
                    color: colors.separator,
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tint.gradient[0], tint.gradient[1]],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            next == null
                ? l10n.rankMax
                : l10n.rankProgressToNext(
                    (progress * 100).round(),
                    next.label(l10n),
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _mono(10.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One of the three personal-best tiles: label, big number + unit, caption.
class _PbTile extends StatelessWidget {
  const _PbTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.colors,
    this.caption,
  });

  final String label;
  final String value;
  final String unit;
  final AppColorsTheme colors;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final note = caption;
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mono(10.sp, tracking: 0.06, color: colors.textSecondary),
          ),
          SizedBox(height: 6.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: _archivo(
                      24.sp,
                      tracking: -0.02,
                      color: colors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: _archivo(
                      12.sp,
                      weight: 600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (note != null) ...[
            SizedBox(height: 6.h),
            Text(note, style: _mono(10.sp, color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// `3M / 6M / ALL` pill switch for the chart window.
class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({
    required this.value,
    required this.colors,
    required this.l10n,
    required this.onChanged,
  });

  final _TimePeriod value;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final ValueChanged<_TimePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (_TimePeriod.last3Months, l10n.periodShort3M),
      (_TimePeriod.last6Months, l10n.periodShort6M),
      (_TimePeriod.allTime, l10n.periodShortAll),
    ];
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: 2.w),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(options[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: value == options[i].$1
                      ? colors.cardElevated
                      : colors.cardElevated.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(
                  options[i].$2.toUpperCase(),
                  style: _mono(
                    11.sp,
                    weight: FontWeight.w600,
                    color: value == options[i].$1
                        ? colors.textPrimary
                        : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The rounded panel every chart state (loading / empty / data) sits in.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.colors,
    required this.child,
    this.height,
  });

  final AppColorsTheme colors;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
      ),
      child: child,
    );
  }
}

/// Per-session volume bars with a latest-session headline, y-axis ticks,
/// month labels and a legend.
///
///   4,180 kg  last session · Sep 6
///   4.2k ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈  PR
///        ▮  ▯  ▮  ▯  ▯  ▮  ▮
///   2.1k ┈┈▮┈┈▯┈┈▮┈┈▯┈┈▯┈┈▮┈┈▮┈
///        ▮  ▯  ▮  ▯  ▯  ▮  ▮
///      0 ───────────────────────
///        JUN     JUL     AUG  SEP
///   ■ latest / PR   ■ earlier sessions
class _VolumeChart extends StatelessWidget {
  const _VolumeChart({
    required this.data,
    required this.colors,
    required this.unit,
    required this.l10n,
  });

  final List<({DateTime date, double volume})> data;
  final AppColorsTheme colors;
  final WeightUnit unit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final volumes = [for (final d in data) d.volume];
    final maxVolume = volumes.reduce(math.max);
    final latest = data.last;
    final months = monthTicks([for (final d in data) d.date.toLocal()]);
    final monthFmt = DateFormat.MMM(locale);
    final axisW = 32.w;
    final axisGap = 8.w;
    final plotH = 150.h;
    final axisStyle = _mono(10.sp, color: colors.textSecondary);

    return _ChartCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatWeight(latest.volume, unit, decimals: 0, withUnit: true),
                style: _archivo(
                  26.sp,
                  tracking: -0.02,
                  color: colors.textPrimary,
                ),
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Text(
                    '${l10n.lastSession.toLowerCase()} · '
                    '${DateFormat.MMMd(locale).format(latest.date.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mono(11.sp, color: colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          SizedBox(
            height: plotH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y axis: max on the top grid line, half on the middle one,
                // zero on the baseline.
                SizedBox(
                  width: axisW,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 0,
                        top: -6.h,
                        child: Text(axisLabel(maxVolume, unit), style: axisStyle),
                      ),
                      Positioned(
                        right: 0,
                        top: plotH / 2 - 6.h,
                        child: Text(
                          axisLabel(maxVolume / 2, unit),
                          style: axisStyle,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: -4.h,
                        child: Text('0', style: axisStyle),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: axisGap),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _BarsPainter(
                      volumes: volumes,
                      highlighted: highlightedBars(volumes),
                      prIndex: prBarIndex(volumes),
                      maxVolume: maxVolume,
                      accent: colors.accent,
                      grid: colors.separator,
                      gap: 5.w,
                      prLabel: l10n.prTag.toUpperCase(),
                      prStyle: _mono(
                        9.sp,
                        weight: FontWeight.w600,
                        color: colors.accent,
                      ),
                      prLift: 16.h,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.only(left: axisW + axisGap),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final m in months)
                  Text(monthFmt.format(m).toUpperCase(), style: axisStyle),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _LegendItem(
                color: colors.accent,
                label: l10n.legendLatestPr,
                colors: colors,
              ),
              SizedBox(width: 14.w),
              _LegendItem(
                color: colors.accent.withValues(alpha: 0.35),
                label: l10n.legendEarlierSessions,
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.colors,
  });

  final Color color;
  final String label;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 5.w),
        Text(label, style: _mono(10.sp, color: colors.textSecondary)),
      ],
    );
  }
}

/// Grid lines plus equal-width bars. A bar is full accent when it set a
/// running PR or is the latest session, muted otherwise; the window's max
/// bar carries a `PR` tag drawn above the plot.
class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.volumes,
    required this.highlighted,
    required this.prIndex,
    required this.maxVolume,
    required this.accent,
    required this.grid,
    required this.gap,
    required this.prLabel,
    required this.prStyle,
    required this.prLift,
  });

  final List<double> volumes;
  final List<bool> highlighted;
  final int prIndex;
  final double maxVolume;
  final Color accent;
  final Color grid;
  final double gap;
  final String prLabel;
  final TextStyle prStyle;

  /// Distance from the top of the tagged bar to the top of the `PR` label.
  final double prLift;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    _dashed(canvas, 0.5, size.width, gridPaint);
    _dashed(canvas, size.height / 2, size.width, gridPaint);
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      gridPaint,
    );

    if (volumes.isEmpty || maxVolume <= 0) return;
    final n = volumes.length;
    final slotW = (size.width - gap * (n - 1)) / n;
    if (slotW <= 0) return;

    final full = Paint()..color = accent;
    final muted = Paint()..color = accent.withValues(alpha: 0.35);
    final topR = Radius.circular(math.min(5.0, slotW / 2));
    final bottomR = Radius.circular(math.min(2.0, slotW / 2));
    const minH = 2.0;

    for (var i = 0; i < n; i++) {
      final h = math.max(volumes[i] / maxVolume * size.height, minH);
      final left = i * (slotW + gap);
      final rect = Rect.fromLTWH(left, size.height - h, slotW, h);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: topR,
          topRight: topR,
          bottomLeft: bottomR,
          bottomRight: bottomR,
        ),
        highlighted[i] ? full : muted,
      );
      if (i == prIndex) {
        final tag = TextPainter(
          text: TextSpan(text: prLabel, style: prStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tag.paint(
          canvas,
          Offset(left + (slotW - tag.width) / 2, rect.top - prLift),
        );
        tag.dispose();
      }
    }
  }

  static void _dashed(Canvas canvas, double y, double width, Paint paint) {
    const dash = 4.0;
    const space = 4.0;
    var x = 0.0;
    while (x < width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, width), y),
        paint,
      );
      x += dash + space;
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      !listEquals(old.volumes, volumes) ||
      !listEquals(old.highlighted, highlighted) ||
      old.prIndex != prIndex ||
      old.maxVolume != maxVolume ||
      old.accent != accent ||
      old.grid != grid ||
      old.gap != gap ||
      old.prLabel != prLabel ||
      old.prStyle != prStyle ||
      old.prLift != prLift;
}

class _SetRecordRow extends StatelessWidget {
  const _SetRecordRow({
    required this.label,
    required this.value,
    required this.colors,
    this.isLast = false,
  });

  final String label;
  final String value;
  final AppColorsTheme colors;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                value,
                style: _archivo(
                  16.sp,
                  weight: 700,
                  color: colors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Container(height: 1, color: colors.separator),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 2 — History
// ═══════════════════════════════════════════════════════════════════

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.colors,
    required this.l10n,
    required this.unit,
    required this.historyAsync,
  });

  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final WeightUnit unit;
  final AsyncValue<List<ExerciseHistoryEntry>> historyAsync;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return historyAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
      ),
      error: (_, __) => Center(
        child: Text(
          l10n.retry,
          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  color: colors.textSecondary,
                  size: 48.sp,
                ),
                SizedBox(height: 12.h),
                Text(
                  l10n.noHistoryYet,
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AppSizes.contentPaddingH.w,
            16.h,
            AppSizes.contentPaddingH.w,
            60.h + bottomInset,
          ),
          itemCount: entries.length,
          itemBuilder: (ctx, i) => _SessionHistoryCard(
            entry: entries[i],
            colors: colors,
            l10n: l10n,
            unit: unit,
          ),
        );
      },
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  const _SessionHistoryCard({
    required this.entry,
    required this.colors,
    required this.l10n,
    required this.unit,
  });

  final ExerciseHistoryEntry entry;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'MMM d, yyyy',
      Localizations.localeOf(context).toString(),
    ).format(entry.session.startedAt.toLocal());
    final title = entry.scheduleName ?? dateStr;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session header
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: colors.accent,
                  size: 14.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.scheduleName != null) ...[
                  const Spacer(),
                  Text(
                    dateStr,
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 11.sp),
                  ),
                ],
              ],
            ),
          ),

          // Column headers
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                SizedBox(
                  width: 40.w,
                  child: Text(
                    l10n.sets,
                    style: TextStyle(
                      color: colors.subtitleText,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${l10n.weight} & ${l10n.reps}',
                    style: TextStyle(
                      color: colors.subtitleText,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),

          // Set rows
          ...entry.sets.map(
            (s) => _SetRow(set: s, colors: colors, unit: unit),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.colors, required this.unit});

  final WorkoutSet set;
  final AppColorsTheme colors;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final isFailure = set.isFailure;
    Color indicatorColor;
    String indicator;

    if (set.isWarmup) {
      indicator = 'W';
      indicatorColor = colors.amber;
    } else if (set.isDropset && isFailure) {
      // Superset — stored as the isDropset+isFailure combination.
      indicator = 'S';
      indicatorColor = const Color(0xFFE040D9);
    } else if (set.isDropset) {
      indicator = 'D';
      indicatorColor = colors.textSecondary;
    } else if (isFailure) {
      indicator = 'F';
      indicatorColor = colors.danger;
    } else {
      indicator = '${set.setIndex + 1}';
      indicatorColor = colors.textSecondary;
    }

    final weightStr = set.weight != null
        ? formatWeight(set.weight, unit, withUnit: true)
        : '—';
    final repsStr = set.reps != null ? '× ${set.reps}' : '—';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 3.h),
      child: Row(
        children: [
          SizedBox(
            width: 40.w,
            child: Container(
              width: 22.w,
              height: 22.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: indicatorColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                indicator,
                style: TextStyle(
                  color: indicatorColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Text(
            '$weightStr  $repsStr',
            style: TextStyle(
              color: isFailure ? colors.danger : colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 3 — How to
// ═══════════════════════════════════════════════════════════════════

class _HowToTab extends StatelessWidget {
  const _HowToTab({
    required this.exercise,
    required this.colors,
    required this.l10n,
  });

  final Exercise exercise;
  final AppColorsTheme colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final instructions = _parseInstructions(exercise.instructions);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // The GIF and the exercise name now live in the shared header above, so
    // this tab is just the numbered steps.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 28.h),
          if (instructions.isEmpty)
            Text(
              l10n.noData,
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
            ),
          for (final (i, step) in instructions.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28.w,
                    child: Text(
                      '${i + 1}.',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 60.h + bottomInset),
        ],
      ),
    );
  }

  /// The catalogue stores instructions as a JSON-ish list of quoted strings,
  /// each prefixed `Step:N ` — split them and drop the prefix.
  List<String> _parseInstructions(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    var cleaned = raw;
    if (cleaned.startsWith('[')) cleaned = cleaned.substring(1);
    if (cleaned.endsWith(']')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned
        .split(RegExp(r'["\n]'))
        .map(
          (s) => stripStepPrefix(
            s.trim().replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), ''),
          ),
        )
        .where((s) => s.isNotEmpty && s != ',')
        .toList();
  }
}
