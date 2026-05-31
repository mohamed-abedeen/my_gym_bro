import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
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
                    timePeriod: _timePeriod,
                    recordFilter: _recordFilter,
                    setRecordsExpanded: _setRecordsExpanded,
                    volumeAsync: volumeAsync,
                    recordsAsync: recordsAsync,
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
            width: 40.w,
            height: 40.w,
            opacity: 0.15,
            radius: 20.r,
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.arrow_back_rounded,
                color: colors.textPrimary, size: 20.sp),
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
            width: 40.w,
            height: 40.w,
            opacity: 0.15,
            radius: 20.r,
            child: Icon(Icons.ios_share_rounded,
                color: colors.textPrimary, size: 18.sp),
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
    required this.timePeriod,
    required this.recordFilter,
    required this.setRecordsExpanded,
    required this.volumeAsync,
    required this.recordsAsync,
    required this.onTimePeriodChanged,
    required this.onRecordFilterChanged,
    required this.onSetRecordsToggled,
  });

  final Exercise exercise;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final _TimePeriod timePeriod;
  final _RecordFilter recordFilter;
  final bool setRecordsExpanded;
  final AsyncValue<List<({DateTime date, double volume})>> volumeAsync;
  final AsyncValue<ExercisePersonalRecords> recordsAsync;
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
              child: Text('No data',
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 13.sp)),
            ),
          );
        }
        return _VolumeBarChart(data: data, colors: colors);
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
                          ? '${records.maxWeight!.toStringAsFixed(1)} kg'
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
                          ? '${records.best1rm!.toStringAsFixed(1)} kg'
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
                          ? '${records.bestSetVolume!.toStringAsFixed(0)} kg'
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
                          ? '${records.bestSessionVolume!.toStringAsFixed(0)} kg'
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
                          ? '${records.maxWeight!.toStringAsFixed(1)} kg'
                          : '—',
                      colors: colors,
                    ),
                    _SetRecordRow(
                      label: l10n.oneRepMax,
                      value: records.best1rm != null
                          ? '${records.best1rm!.toStringAsFixed(1)} kg'
                          : '—',
                      colors: colors,
                    ),
                    _SetRecordRow(
                      label: l10n.bestSetVolumeLabel,
                      value: records.bestSetVolume != null
                          ? '${records.bestSetVolume!.toStringAsFixed(0)} kg'
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
    required this.historyAsync,
  });

  final AppColorsTheme colors;
  final AppLocalizations l10n;
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
          itemBuilder: (ctx, i) =>
              _SessionHistoryCard(entry: entries[i], colors: colors, l10n: l10n),
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
  });

  final ExerciseHistoryEntry entry;
  final AppColorsTheme colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy').format(entry.session.startedAt.toLocal());
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
          ...entry.sets.map((s) => _SetRow(set: s, colors: colors)),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.colors});

  final WorkoutSet set;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    final isFailure = set.isFailure;
    Color indicatorColor;
    String indicator;

    if (set.isWarmup) {
      indicator = 'W';
      indicatorColor = colors.amber;
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
        ? '${set.weight!.toStringAsFixed(set.weight! % 1 == 0 ? 0 : 1)} kg'
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
  const _VolumeBarChart({required this.data, required this.colors});

  final List<({DateTime date, double volume})> data;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    final maxVol = data.isEmpty ? 0.0 : data.map((d) => d.volume).reduce(math.max);
    final fmt = DateFormat('MMM d');

    // Format the peak volume label neatly
    String peakLabel;
    if (maxVol >= 1000) {
      peakLabel = '${(maxVol / 1000).toStringAsFixed(1)}k kg';
    } else {
      peakLabel = '${maxVol.toStringAsFixed(0)} kg';
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
// ExerciseStatusScreen — post-workout view (unchanged)
// ═══════════════════════════════════════════════════════════════════

class ExerciseStatusScreen extends StatelessWidget {
  const ExerciseStatusScreen({
    required this.exercise,
    super.key,
    this.setsData = const [],
    this.duration = '5m',
    this.volume = '37170 lbs',
    this.avgStrength = '86',
    this.records = '5',
    this.calBurned = '250 cal',
    this.sessionLabel,
    this.nextSessionInfo,
  });

  final Exercise exercise;
  final List<Map<String, dynamic>> setsData;
  final String duration;
  final String volume;
  final String avgStrength;
  final String records;
  final String calBurned;
  final String? sessionLabel;
  final String? nextSessionInfo;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 7.w),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.panelBackground,
                borderRadius: BorderRadius.circular(55.r),
              ),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10.h),

                  Row(
                    children: [
                      LiquidGlassButton(
                        width: 48.w,
                        height: 48.w,
                        opacity: 0.15,
                        radius: 24.r,
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.arrow_back_rounded,
                            color: colors.textPrimary, size: 22.sp),
                      ),
                      const Spacer(),
                      LiquidGlassButton(
                        width: 48.w,
                        height: 48.w,
                        opacity: 0.15,
                        radius: 24.r,
                        child: Icon(Icons.ios_share_rounded,
                            color: colors.textPrimary, size: 20.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      ClipOval(
                        child: exercise.gifUrl != null
                            ? CachedNetworkImage(
                                cacheManager: ExerciseGifCache.instance,
                                imageUrl: exercise.gifUrl!,
                                width: 83.w,
                                height: 83.w,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _circPlaceholder(colors, 83.w),
                                errorWidget: (_, __, ___) =>
                                    _circPlaceholder(colors, 83.w),
                              )
                            : _circPlaceholder(colors, 83.w),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _currentTime(),
                              style: TextStyle(
                                color: colors.subtitleText,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        duration,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        _setsHeaderRow(colors),
                        SizedBox(height: 8.h),
                        ...(_effectiveSets().asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50.w,
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700)),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text('${s['weight'] ?? '-'}',
                                        style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                SizedBox(
                                  width: 50.w,
                                  child: Text('${s['reps'] ?? '-'}',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                        })),
                        Container(
                            height: 1,
                            color: colors.divider,
                            margin: EdgeInsets.symmetric(vertical: 12.h)),
                        Row(
                          children: [
                            Expanded(
                                child: _statBlock(
                                    colors, 'Volume', volume, colors.success)),
                            Expanded(
                                child: _statBlock(colors, 'Avg Strength',
                                    avgStrength, colors.success)),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(
                                child: _statBlock(colors, 'Total Duration',
                                    duration, colors.success)),
                            Expanded(
                                child: _statBlock(
                                    colors, 'Records', records, colors.success)),
                          ],
                        ),
                        Container(
                            height: 1,
                            color: colors.divider,
                            margin: EdgeInsets.symmetric(vertical: 12.h)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text('🔥',
                                      style: TextStyle(fontSize: 28.sp)),
                                  SizedBox(width: 8.w),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Cal Burned',
                                          style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 10.sp)),
                                      Text(calBurned,
                                          style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PROGRESS',
                                      style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4.h),
                                  Container(
                                    width: double.infinity,
                                    height: 26.h,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.of(context)
                                              .white
                                              .withValues(alpha: 0.35),
                                          AppColors.of(context)
                                              .white
                                              .withValues(alpha: 0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setsHeaderRow(AppColorsTheme colors) {
    return Row(
      children: [
        SizedBox(
          width: 50.w,
          child: Text('Sets',
              style: TextStyle(
                  color: colors.subtitleText,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Center(
            child: Text('weights kg',
                style: TextStyle(
                    color: colors.subtitleText,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        SizedBox(
          width: 50.w,
          child: Text('Rips',
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: colors.subtitleText,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _statBlock(AppColorsTheme colors, String label, String value,
      Color changeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: colors.textPrimary, fontSize: 10.sp)),
        SizedBox(height: 2.h),
        Text(value,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  List<Map<String, dynamic>> _effectiveSets() {
    if (setsData.isNotEmpty) return setsData;
    return [
      {'weight': 90, 'reps': 8},
      {'weight': 80, 'reps': 10},
      {'weight': 70, 'reps': 12},
      {'weight': 60, 'reps': 4},
      {'weight': 50, 'reps': '-'},
    ];
  }

  String _currentTime() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'am' : 'pm';
    return '$hour:$minute$period';
  }

  Widget _circPlaceholder(AppColorsTheme colors, double size) => Container(
        width: size,
        height: size,
        color: colors.separator,
        child: Icon(Icons.fitness_center_rounded,
            color: colors.textSecondary, size: size * 0.4),
      );
}
