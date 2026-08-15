import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/units.dart';
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

enum _RecordFilter { heaviest, oneRepMax, bestSetVolume }

// ═══════════════════════════════════════════════════════════════════
// ExerciseDetailScreen — tabbed detail with Summary, History, How to
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
  _RecordFilter _recordFilter = _RecordFilter.heaviest;
  bool _setRecordsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime? get _fromDate {
    final now = DateTime.now();
    switch (_timePeriod) {
      case _TimePeriod.last3Months:
        return DateTime(now.year, now.month - 3, now.day);
      case _TimePeriod.last6Months:
        return DateTime(now.year, now.month - 6, now.day);
      case _TimePeriod.allTime:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final exercise = widget.exercise;

    final volumeAsync = ref.watch(exerciseVolumeWithDatesProvider(
      ExerciseVolumeParams(exercise.exerciseId, from: _fromDate),
    ));
    final recordsAsync =
        ref.watch(exercisePersonalRecordsProvider(exercise.exerciseId));
    final historyAsync =
        ref.watch(exerciseSessionHistoryProvider(exercise.exerciseId));
    final liftRankAsync = ref.watch(liftRankProvider(exercise.exerciseId));
    final unit = ref.watch(weightUnitProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, colors, exercise),
            _buildTabBar(context, colors, l10n),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SummaryTab(
                    exercise: exercise,
                    colors: colors,
                    l10n: l10n,
                    unit: unit,
                    timePeriod: _timePeriod,
                    recordFilter: _recordFilter,
                    setRecordsExpanded: _setRecordsExpanded,
                    volumeAsync: volumeAsync,
                    recordsAsync: recordsAsync,
                    liftRankAsync: liftRankAsync,
                    onTimePeriodChanged: (p) =>
                        setState(() => _timePeriod = p),
                    onRecordFilterChanged: (f) =>
                        setState(() => _recordFilter = f),
                    onSetRecordsToggled: () => setState(
                        () => _setRecordsExpanded = !_setRecordsExpanded),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, AppColorsTheme colors, Exercise exercise) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSizes.contentPaddingH.w, 10.h, AppSizes.contentPaddingH.w, 0),
      child: Row(
        children: [
          LiquidGlassButton(
            width: AppSizes.headerActionBtn.w,
            height: AppSizes.headerActionBtn.w,
            opacity: 0.15,
            radius: (AppSizes.headerActionBtn / 2).r,
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.arrow_back_rounded,
                color: colors.textPrimary, size: AppSizes.headerActionIcon.sp),
          ),
          Expanded(
            child: Text(
              exercise.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          LiquidGlassButton(
            width: AppSizes.headerActionBtn.w,
            height: AppSizes.headerActionBtn.w,
            opacity: 0.15,
            radius: (AppSizes.headerActionBtn / 2).r,
            // Opens the exercise share card with all-time stats. The reads
            // resolve instantly when the summary tab already loaded them;
            // the volume history is re-read unwindowed (from: null) so the
            // card's trend is all-time regardless of the selected period.
            onTap: () async {
              final records = await ref.read(
                exercisePersonalRecordsProvider(exercise.exerciseId).future,
              );
              final rank =
                  await ref.read(liftRankProvider(exercise.exerciseId).future);
              final history = await ref.read(
                exerciseVolumeWithDatesProvider(
                  ExerciseVolumeParams(exercise.exerciseId),
                ).future,
              );
              if (!context.mounted) return;
              unawaited(context.push(
                AppRoutes.shareExercise,
                extra: ExerciseShareData.fromStats(
                  exerciseName: exercise.name,
                  muscleGroup: exercise.muscleGroup,
                  records: records,
                  rank: rank,
                  volumeHistory: history,
                ),
              ));
            },
            child: Icon(Icons.ios_share_rounded,
                color: colors.textPrimary, size: AppSizes.headerActionIcon.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(
      BuildContext context, AppColorsTheme colors, AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: TabBar(
        controller: _tabController,
        indicatorColor: colors.accent,
        labelColor: colors.accent,
        unselectedLabelColor: colors.textSecondary,
        labelStyle:
            TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
        dividerColor: colors.separator,
        tabs: [
          Tab(text: l10n.tabSummary),
          Tab(text: l10n.tabHistory),
          Tab(text: l10n.howTo),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════
// Tab 1 — Summary
// ═══════════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.exercise,
    required this.colors,
    required this.l10n,
    required this.unit,
    required this.timePeriod,
    required this.recordFilter,
    required this.setRecordsExpanded,
    required this.volumeAsync,
    required this.recordsAsync,
    required this.liftRankAsync,
    required this.onTimePeriodChanged,
    required this.onRecordFilterChanged,
    required this.onSetRecordsToggled,
  });

  final Exercise exercise;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final WeightUnit unit;
  final _TimePeriod timePeriod;
  final _RecordFilter recordFilter;
  final bool setRecordsExpanded;
  final AsyncValue<List<({DateTime date, double volume})>> volumeAsync;
  final AsyncValue<ExercisePersonalRecords> recordsAsync;
  final AsyncValue<LiftRank?> liftRankAsync;
  final ValueChanged<_TimePeriod> onTimePeriodChanged;
  final ValueChanged<_RecordFilter> onRecordFilterChanged;
  final VoidCallback onSetRecordsToggled;

  @override
  Widget build(BuildContext context) {
    final primaryMuscles = _parseList(exercise.targetMuscles);
    final secondaryMuscles = _parseList(exercise.secondaryMuscles);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),

          // GIF
          if (exercise.gifUrl != null) _buildGif(context),
          SizedBox(height: 16.h),

          // Name + muscles
          Text(
            exercise.name,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          if (primaryMuscles.isNotEmpty)
            Text(
              '${l10n.primaryLabel}: ${primaryMuscles.join(', ')}',
              style: TextStyle(
                  color: colors.accent,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500),
            ),
          if (secondaryMuscles.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              '${l10n.secondaryLabel}: ${secondaryMuscles.join(', ')}',
              style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500),
            ),
          ],
          SizedBox(height: 20.h),

          // Time period dropdown
          _buildTimePeriodDropdown(context),
          SizedBox(height: 16.h),

          // Volume bar chart
          _buildChart(context),
          SizedBox(height: 20.h),

          // Filter chips
          _buildFilterChips(context),
          SizedBox(height: 20.h),

          // Lift rank (classic barbell lifts only — hidden otherwise)
          _buildLiftRank(context),

          // Personal Records
          _buildPersonalRecords(context),
          SizedBox(height: 16.h),

          // Set Records expandable
          _buildSetRecords(context),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _buildGif(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.howtoGif.r),
      child: Container(
        width: double.infinity,
        height: AppSizes.howtoGifH.h,
        color: colors.panelBackground,
        child: CachedNetworkImage(
          cacheManager: ExerciseGifCache.instance,
          imageUrl: exercise.gifUrl!,
          fit: BoxFit.contain,
          placeholder: (_, __) => Center(
            child: CircularProgressIndicator(
                color: colors.accent, strokeWidth: 2),
          ),
          errorWidget: (_, __, ___) => Center(
            child: Icon(Icons.broken_image_rounded,
                color: colors.textSecondary, size: 48.sp),
          ),
        ),
      ),
    );
  }

  String _periodLabel(_TimePeriod p) {
    switch (p) {
      case _TimePeriod.last3Months:
        return l10n.last3Months;
      case _TimePeriod.last6Months:
        return l10n.last6Months;
      case _TimePeriod.allTime:
        return l10n.allTime;
    }
  }

  Widget _buildTimePeriodDropdown(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_TimePeriod>(
          value: timePeriod,
          isDense: true,
          dropdownColor: colors.cardElevated,
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: colors.textSecondary, size: 18.sp),
          items: _TimePeriod.values
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(_periodLabel(p)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onTimePeriodChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    return volumeAsync.when(
      loading: () => Container(
        height: 160.h,
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) {
          return Container(
            height: 160.h,
            decoration: BoxDecoration(
              color: colors.panelBackground,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(l10n.noData,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 13.sp)),
            ),
          );
        }
        return _VolumeBarChart(data: data, colors: colors, unit: unit);
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final chips = [
      (_RecordFilter.heaviest, l10n.heaviestWeight),
      (_RecordFilter.oneRepMax, l10n.oneRepMax),
      (_RecordFilter.bestSetVolume, l10n.bestSetVolumeLabel),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final selected = recordFilter == chip.$1;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => onRecordFilterChanged(chip.$1),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.accent
                      : colors.panelBackground,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: selected
                        ? colors.accent
                        : colors.separator,
                  ),
                ),
                child: Text(
                  chip.$2,
                  style: TextStyle(
                    color: selected ? Colors.black : colors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLiftRank(BuildContext context) {
    final liftRank = liftRankAsync.valueOrNull;
    if (liftRank == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: _LiftRankCard(
        liftRank: liftRank,
        colors: colors,
        l10n: l10n,
        unit: unit,
      ),
    );
  }

  Widget _buildPersonalRecords(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.yourRecords,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12.h),
        recordsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
                color: colors.accent, strokeWidth: 2),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (records) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _RecordCard(
                      label: l10n.heaviestWeight,
                      value: records.maxWeight != null
                          ? formatWeight(records.maxWeight, unit,
                              withUnit: true)
                          : '—',
                      isHighlighted: recordFilter == _RecordFilter.heaviest,
                      colors: colors,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _RecordCard(
                      label: l10n.oneRepMax,
                      value: records.best1rm != null
                          ? formatWeight(records.best1rm, unit,
                              withUnit: true)
                          : '—',
                      isHighlighted:
                          recordFilter == _RecordFilter.oneRepMax,
                      colors: colors,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _RecordCard(
                      label: l10n.bestSetVolumeLabel,
                      value: records.bestSetVolume != null
                          ? formatWeight(records.bestSetVolume, unit,
                              decimals: 0, withUnit: true)
                          : '—',
                      isHighlighted:
                          recordFilter == _RecordFilter.bestSetVolume,
                      colors: colors,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _RecordCard(
                      label: l10n.bestSessionVolumeLabel,
                      value: records.bestSessionVolume != null
                          ? formatWeight(records.bestSessionVolume, unit,
                              decimals: 0, withUnit: true)
                          : '—',
                      isHighlighted: false,
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetRecords(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onSetRecordsToggled,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  Text(
                    l10n.setRecords,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: setRecordsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: colors.textSecondary, size: 20.sp),
                  ),
                ],
              ),
            ),
          ),
          if (setRecordsExpanded) ...[
            Container(height: 1, color: colors.separator),
            recordsAsync.when(
              loading: () => Padding(
                padding: EdgeInsets.all(16.h),
                child: Center(
                  child: CircularProgressIndicator(
                      color: colors.accent, strokeWidth: 2),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) => Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    _SetRecordRow(
                      label: l10n.heaviestWeight,
                      value: records.maxWeight != null
                          ? formatWeight(records.maxWeight, unit,
                              withUnit: true)
                          : '—',
                      colors: colors,
                    ),
                    _SetRecordRow(
                      label: l10n.oneRepMax,
                      value: records.best1rm != null
                          ? formatWeight(records.best1rm, unit,
                              withUnit: true)
                          : '—',
                      colors: colors,
                    ),
                    _SetRecordRow(
                      label: l10n.bestSetVolumeLabel,
                      value: records.bestSetVolume != null
                          ? formatWeight(records.bestSetVolume, unit,
                              decimals: 0, withUnit: true)
                          : '—',
                      colors: colors,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _parseList(String? csv) {
    if (csv == null || csv.isEmpty) return [];
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
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
    return historyAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
      ),
      error: (_, __) => Center(
        child: Text(l10n.retry,
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded,
                    color: colors.textSecondary, size: 48.sp),
                SizedBox(height: 12.h),
                Text(l10n.noHistoryYet,
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 14.sp)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.contentPaddingH.w, vertical: 16.h),
          itemCount: entries.length,
          itemBuilder: (ctx, i) => _SessionHistoryCard(
              entry: entries[i], colors: colors, l10n: l10n, unit: unit),
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
            padding:
                EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: colors.accent, size: 14.sp),
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
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 11.sp),
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
                  child: Text(l10n.sets,
                      style: TextStyle(
                          color: colors.subtitleText,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Text('${l10n.weight} & ${l10n.reps}',
                      style: TextStyle(
                          color: colors.subtitleText,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),

          // Set rows
          ...entry.sets.map(
              (s) => _SetRow(set: s, colors: colors, unit: unit)),
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

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),

          // GIF
          if (exercise.gifUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.howtoGif.r),
              child: Container(
                width: double.infinity,
                height: AppSizes.howtoGifH.h,
                color: colors.panelBackground,
                child: CachedNetworkImage(
                  cacheManager: ExerciseGifCache.instance,
                  imageUrl: exercise.gifUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Center(
                    child: CircularProgressIndicator(
                        color: colors.accent, strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: colors.textSecondary, size: 48.sp),
                  ),
                ),
              ),
            ),
          SizedBox(height: 20.h),

          // Name row with thumb
          Row(
            children: [
              ClipOval(
                child: exercise.gifUrl != null
                    ? CachedNetworkImage(
                        cacheManager: ExerciseGifCache.instance,
                        imageUrl: exercise.gifUrl!,
                        width: 44.w,
                        height: 44.w,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _thumbPlaceholder(),
                        errorWidget: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  exercise.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Numbered instructions
          if (instructions.isNotEmpty)
            ...instructions.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: 14.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28.w,
                        child: Text(
                          '${e.key + 1}.',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
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
                )),

          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 44.w,
        height: 44.w,
        color: colors.separator,
        child: Icon(Icons.fitness_center_rounded,
            color: colors.textSecondary, size: 20.sp),
      );

  List<String> _parseInstructions(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    var cleaned = raw;
    if (cleaned.startsWith('[')) cleaned = cleaned.substring(1);
    if (cleaned.endsWith(']')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned
        .split(RegExp(r'["\n]'))
        .map((s) => s.trim().replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), ''))
        .where((s) => s.isNotEmpty && s != ',')
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared sub-widgets
// ═══════════════════════════════════════════════════════════════════

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.label,
    required this.value,
    required this.isHighlighted,
    required this.colors,
  });

  final String label;
  final String value;
  final bool isHighlighted;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colors.accent.withValues(alpha: 0.12)
            : colors.panelBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: isHighlighted
            ? Border.all(color: colors.accent.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: isHighlighted ? colors.accent : colors.textPrimary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (!isLast)
          Container(height: 1, color: colors.separator),
      ],
    );
  }
}

/// Compact, polished bar chart for per-session volume.
///
/// Layout (inside a rounded panelBackground card):
///   ┌──────────────────────────────────────────┐
///   │  1 240 kg ·                              │
///   │          ┊            ████               │
///   │          ┊      ████  ████  ████         │
///   │  ─ ─ ─ ─ ┊ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │
///   │    ████  ████  ████  ████  ████  ████   │
///   │  ─ ─ ─ ─ ┊ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │
///   │  Jan 1 ·  ·  ·  ·  ·  ·  ·  ·  Mar 4   │
///   └──────────────────────────────────────────┘
class _VolumeBarChart extends StatelessWidget {
  const _VolumeBarChart({
    required this.data,
    required this.colors,
    required this.unit,
  });

  final List<({DateTime date, double volume})> data;
  final AppColorsTheme colors;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final maxVol = data.isEmpty ? 0.0 : data.map((d) => d.volume).reduce(math.max);
    final fmt =
        DateFormat('MMM d', Localizations.localeOf(context).toString());

    // Format the peak volume label neatly, in the user's display unit
    final maxVolDisplay = convertFromKg(maxVol, unit);
    String peakLabel;
    if (maxVolDisplay >= 1000) {
      peakLabel =
          '${(maxVolDisplay / 1000).toStringAsFixed(1)}k ${weightUnitLabel(unit)}';
    } else {
      peakLabel =
          '${maxVolDisplay.toStringAsFixed(0)} ${weightUnitLabel(unit)}';
    }

    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Peak label top-left
          Text(
            peakLabel,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),

          // Chart body
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(
                data: data,
                barColor: colors.accent,
                gridColor: colors.separator,
              ),
            ),
          ),
          SizedBox(height: 6.h),

          // X-axis: first and last date only
          if (data.length >= 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fmt.format(data.first.date),
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 9.sp),
                ),
                Text(
                  fmt.format(data.last.date),
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 9.sp),
                ),
              ],
            )
          else if (data.length == 1)
            Text(
              fmt.format(data.first.date),
              style:
                  TextStyle(color: colors.textSecondary, fontSize: 9.sp),
            ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.gridColor,
  });

  final List<({DateTime date, double volume})> data;
  final Color barColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVol = data.isEmpty ? 0.0 : data.map((d) => d.volume).reduce(math.max);
    if (maxVol == 0) return;

    // ── Grid lines (at 33 % and 66 % height) ──────────────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final frac in [0.33, 0.66]) {
      final y = size.height * (1 - frac);
      // Dashed line via short segments
      const dashW = 4.0;
      const gapW = 4.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dashW, size.width), y),
          gridPaint,
        );
        x += dashW + gapW;
      }
    }

    // ── Bars ──────────────────────────────────────────────────────
    final count = data.length;
    // Each bar slot is equal-width; bar occupies 60 % of slot
    final slotW = size.width / count;
    final rawBarW = slotW * 0.55;
    final barW = rawBarW < 4 ? 4.0 : rawBarW;
    const cornerR = Radius.circular(4);
    const minBarH = 3.0; // always show at least a sliver

    final barPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final barH = math.max(
        (data[i].volume / maxVol) * size.height,
        minBarH,
      );
      final left = i * slotW + (slotW - barW) / 2;
      final top = size.height - barH;
      final rect = Rect.fromLTWH(left, top, barW, barH);

      // Gradient: full accent at top → 70 % opacity at bottom
      barPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          barColor,
          barColor.withValues(alpha: 0.65),
        ],
      ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: cornerR,
          topRight: cornerR,
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data ||
      old.barColor != barColor ||
      old.gridColor != gridColor;
}

// ═══════════════════════════════════════════════════════════════════
// Lift rank card — Bronze→Elite standing for the classic barbell lifts
// ═══════════════════════════════════════════════════════════════════

class _LiftRankCard extends StatelessWidget {
  const _LiftRankCard({
    required this.liftRank,
    required this.colors,
    required this.l10n,
    required this.unit,
  });

  final LiftRank liftRank;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final rank = liftRank.rank;
    final next = rank.next;
    final tint = rankColors(rank.tier);
    return GlassSurface(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankBadge(rank, size: 64.w),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.liftRankCardTitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      rank.label(l10n),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${formatWeight(liftRank.e1RmKg, unit, withUnit: true)} '
                      '${l10n.oneRepMax}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: SizedBox(
              height: 6.h,
              child: Stack(
                children: [
                  Container(color: colors.separator),
                  FractionallySizedBox(
                    widthFactor:
                        next == null ? 1 : liftRank.progressToNext.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: tint.gradient),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (next != null) ...[
            SizedBox(height: 6.h),
            Text(
              l10n.rankNext(next.label(l10n)),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
