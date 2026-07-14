import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/exercise_detail_sheet.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Show the Log bottom sheet — stats-forward session cards plus a month
/// heatmap date picker toggled from the header search button.
void showLogBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LogSheet(),
  );
}

class _LogSheet extends ConsumerStatefulWidget {
  const _LogSheet();

  @override
  ConsumerState<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<_LogSheet> {
  bool _showCalendar = false;
  DateTime? _selectedDay;
  late DateTime _visibleMonth;
  ScrollController? _sheetScrollController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _onDayTap(DateTime day) {
    setState(() {
      _selectedDay = day;
      _showCalendar = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _sheetScrollController;
      if (c != null && c.hasClients) c.jumpTo(0);
    });
  }

  /// Sessions that set a new all-time best set volume (weight × reps) for
  /// any exercise. Walked oldest→newest so the first time an exercise is
  /// ever performed counts as the baseline, not a PR.
  Set<int> _prSessionIds(List<EnrichedSession> newestFirst) {
    final best = <String, double>{};
    final prs = <int>{};
    for (final e in newestFirst.reversed) {
      var isPr = false;
      for (final ex in e.exercises) {
        for (final set in ex.setDetails) {
          if (set.isWarmup || set.weight == null || set.reps == null) continue;
          final vol = set.weight! * set.reps!;
          final prev = best[ex.exerciseId];
          if (prev == null || vol > prev) {
            best[ex.exerciseId] = vol;
            if (prev != null) isPr = true;
          }
        }
      }
      if (isPr) prs.add(e.session.localId);
    }
    return prs;
  }

  /// Volume trend (%) per session vs the previous session with the same
  /// derived workout name. Absent when there is nothing to compare.
  Map<int, double> _trendBySessionId(List<EnrichedSession> newestFirst) {
    final lastVol = <String, double>{};
    final out = <int, double>{};
    for (final e in newestFirst.reversed) {
      final vol = e.session.totalVolume ?? 0;
      final prev = lastVol[e.workoutName];
      if (prev != null && prev > 0 && vol > 0) {
        out[e.session.localId] = (vol - prev) / prev * 100;
      }
      if (vol > 0) lastVol[e.workoutName] = vol;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final enriched = ref.watch(enrichedAllSessionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        _sheetScrollController = scrollController;
        return Container(
          decoration: BoxDecoration(
            color: colors.panelBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet.r),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // ── Header: X | Sessions | search + check ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentPaddingH.w,
                  16.h,
                  AppSizes.contentPaddingH.w,
                  0,
                ),
                child: Row(
                  children: [
                    // Close: dismisses the calendar first if open.
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      onTap: () {
                        if (_showCalendar) {
                          setState(() => _showCalendar = false);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Icon(Icons.close_rounded,
                          color: colors.textPrimary, size: 22.sp),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.sessionLog,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // Search: toggles the heatmap date picker. Accent-tinted
                    // while the calendar is open.
                    if (_showCalendar) GestureDetector(
                            onTap: () =>
                                setState(() => _showCalendar = false),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 48.w,
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                              child: Icon(Icons.search_rounded,
                                  color: colors.accent, size: 22.sp),
                            ),
                          ) else LiquidGlassButton(
                            width: 48.w,
                            height: 48.h,
                            opacity: 0.15,
                            radius: 24.r,
                            onTap: () =>
                                setState(() => _showCalendar = true),
                            child: Icon(Icons.search_rounded,
                                color: colors.textPrimary, size: 22.sp),
                          ),
                    SizedBox(width: 10.w),
                    // Checkmark (accent glass circle)
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.25,
                      radius: 24.r,
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.check_rounded,
                          color: colors.accent, size: 22.sp),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _showCalendar
                    ? _buildCalendar(scrollController, enriched, l10n, colors)
                    : _buildList(scrollController, enriched, l10n, colors),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── List view (stats-forward cards) ──────────────────────────────

  Widget _buildList(
    ScrollController scrollController,
    AsyncValue<List<EnrichedSession>> enriched,
    AppLocalizations l10n,
    AppColorsTheme colors,
  ) {
    final unit = ref.watch(weightUnitProvider);
    final locale = Localizations.localeOf(context).languageCode;

    return enriched.when(
      data: (data) {
        if (data.isEmpty) {
          return Center(
            child: Text(
              l10n.noRecordsYet,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          );
        }

        final sessions = [...data];
        final prIds = _prSessionIds(data);
        final trends = _trendBySessionId(data);

        // Pin the selected day's session (or the nearest earlier one) to
        // the top and highlight it.
        int? highlightedId;
        final sel = _selectedDay;
        if (sel != null) {
          final endOfDay = DateTime(sel.year, sel.month, sel.day + 1);
          var idx = sessions.indexWhere((e) =>
              e.session.startedAt.year == sel.year &&
              e.session.startedAt.month == sel.month &&
              e.session.startedAt.day == sel.day);
          if (idx == -1) {
            // Fall back to the nearest earlier session (list is newest-first).
            idx = sessions
                .indexWhere((e) => e.session.startedAt.isBefore(endOfDay));
          }
          if (idx != -1) {
            final picked = sessions.removeAt(idx);
            sessions.insert(0, picked);
            highlightedId = picked.session.localId;
          }
        }

        final hasJumpLabel = highlightedId != null;
        return ListView.separated(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            AppSizes.contentPaddingH.w,
            18.h,
            AppSizes.contentPaddingH.w,
            30.h,
          ),
          itemCount: sessions.length + (hasJumpLabel ? 1 : 0),
          separatorBuilder: (_, __) => SizedBox(height: 14.h),
          itemBuilder: (_, i) {
            if (hasJumpLabel && i == 0) {
              return Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: Text(
                  l10n.jumpedToDay(DateFormat.MMMd(locale).format(sel!)),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }
            final e = sessions[i - (hasJumpLabel ? 1 : 0)];
            return _SessionCard(
              enriched: e,
              l10n: l10n,
              unit: unit,
              isPr: prIds.contains(e.session.localId),
              trendPct: trends[e.session.localId],
              highlighted: e.session.localId == highlightedId,
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: colors.accent,
          strokeWidth: 2,
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ── Calendar view (month heatmap date picker) ────────────────────

  Widget _buildCalendar(
    ScrollController scrollController,
    AsyncValue<List<EnrichedSession>> enriched,
    AppLocalizations l10n,
    AppColorsTheme colors,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    final streak = ref.watch(streakProvider).valueOrNull;
    final streakText = streak == null
        ? null
        : streak <= 0
            ? l10n.widgetStreakStart
            : streak == 1
                ? l10n.widgetStreakOneDay
                : l10n.widgetStreakDays(streak);

    // Volume per day of the visible month, normalized to its max.
    final sessions = enriched.valueOrNull ?? const <EnrichedSession>[];
    final dayVolumes = <int, double>{};
    for (final e in sessions) {
      final d = e.session.startedAt;
      if (d.year == _visibleMonth.year && d.month == _visibleMonth.month) {
        dayVolumes[d.day] =
            (dayVolumes[d.day] ?? 0) + (e.session.totalVolume ?? 0);
      }
    }
    var maxVolume = 0.0;
    for (final v in dayVolumes.values) {
      if (v > maxVolume) maxVolume = v;
    }

    final firstOfMonth = _visibleMonth;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday-first grid
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    // Localized one-letter weekday labels, Sunday-first.
    // 2023-01-01 is a Sunday.
    final weekdayLabels = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale)
            .format(DateTime(2023, 1, 1 + i))
            .substring(0, 1)
            .toUpperCase(),
    ];

    final noSessionCell = colors.cardElevated;

    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: 30.h),
      child: Column(
        children: [
          SizedBox(height: 18.h),
          // Streak row (hidden until the streak has loaded)
          SizedBox(
            height: 22.h,
            child: streakText == null
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: colors.amber, size: 17.sp),
                      SizedBox(width: 8.w),
                      Text(
                        streakText,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: 18.h),
          // Month header with chevrons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Icon(Icons.chevron_left_rounded,
                        color: colors.textSecondary, size: 24.sp),
                  ),
                ),
                Text(
                  DateFormat.yMMMM(locale).format(_visibleMonth),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Icon(Icons.chevron_right_rounded,
                        color: colors.textSecondary, size: 24.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Weekday labels
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                for (final label in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          // Heatmap grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6.h,
              crossAxisSpacing: 6.w,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (_, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = i - leadingBlanks + 1;
              final date =
                  DateTime(_visibleMonth.year, _visibleMonth.month, day);
              final volume = dayVolumes[day] ?? 0;
              final trained = volume > 0;

              Color bg;
              Color textColor;
              if (trained) {
                final norm = maxVolume > 0 ? volume / maxVolume : 0.0;
                final alpha = 0.2 + norm * 0.65;
                bg = colors.accent.withValues(alpha: alpha);
                // On a strong accent fill the day number needs to flip:
                // black on the bright lime (dark), white on orange (light).
                textColor = alpha > 0.5
                    ? (isDark ? colors.black : colors.white)
                    : colors.textPrimary;
              } else {
                bg = noSessionCell;
                textColor = colors.textSecondary;
              }

              final selected = _selectedDay != null &&
                  _selectedDay!.year == date.year &&
                  _selectedDay!.month == date.month &&
                  _selectedDay!.day == date.day;

              return GestureDetector(
                onTap: trained ? () => _onDayTap(date) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10.r),
                    border: selected
                        ? Border.all(color: colors.accent, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 12.h),
          // Legend
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                Text(
                  l10n.heatmapLess,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                for (final swatch in [
                  noSessionCell,
                  colors.accent.withValues(alpha: 0.35),
                  colors.accent.withValues(alpha: 0.7),
                  colors.accent,
                ])
                  Padding(
                    padding: EdgeInsets.only(left: 6.w),
                    child: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: swatch,
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                SizedBox(width: 6.w),
                Text(
                  l10n.heatmapMore,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.tapDayToJump,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Stats-forward Session Card
// Collapsed: title + date·muscles, PR badge, mini set-volume bar chart,
// VOLUME / DURATION / trend row.
// Tap to expand: exercise rows (→ exercise detail sheet) + delete/share.
// ═══════════════════════════════════════════════════════════════════

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({
    required this.enriched,
    required this.l10n,
    required this.unit,
    this.isPr = false,
    this.trendPct,
    this.highlighted = false,
  });
  final EnrichedSession enriched;
  final AppLocalizations l10n;
  final WeightUnit unit;
  final bool isPr;
  final double? trendPct;
  final bool highlighted;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _expanded = false;

  Future<void> _confirmDeleteSession(int sessionId) async {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          l10n.deleteWorkout,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.deleteWorkoutConfirm,
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(sessionDaoProvider).deleteSession(sessionId);
    // Refresh every downstream view that derives from session history.
    // Without these the Status card, streak, weekly stats, and home
    // dashboards keep showing the deleted session's contribution.
    ref
      ..invalidate(enrichedAllSessionsProvider)
      ..invalidate(enrichedRecentSessionsProvider)
      ..invalidate(recentSessionsProvider)
      ..invalidate(weeklyStatsProvider)
      ..invalidate(lifetimeStatsProvider)
      ..invalidate(activityStatsProvider)
      ..invalidate(streakProvider)
      ..invalidate(muscleRecoveryProvider)
      ..invalidate(recordsProvider)
      ..invalidate(consecutiveRestDaysProvider);
  }

  /// Completed working-set volumes across the session, in set order —
  /// one bar each in the mini chart.
  List<double> _setVolumes() {
    final vols = <double>[];
    for (final ex in widget.enriched.exercises) {
      for (final set in ex.setDetails) {
        if (set.isWarmup || set.weight == null || set.reps == null) continue;
        final v = set.weight! * set.reps!;
        if (v > 0) vols.add(v);
      }
    }
    return vols;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    final s = widget.enriched.session;

    final dateStr = DateFormat.MMMEd(locale).format(s.startedAt);
    final muscles = widget.enriched.targetedMuscleGroups.take(3).join(' · ');
    final subtitle = muscles.isEmpty ? dateStr : '$dateStr · $muscles';
    final volumeStr =
        formatWeight(s.totalVolume, widget.unit, decimals: 0, withUnit: true);
    final durationStr = _formatDuration(s.durationSeconds ?? 0);
    final onAccent = isDark ? colors.black : colors.white;

    final setVolumes = _setVolumes();
    var maxSetVolume = 0.0;
    for (final v in setVolumes) {
      if (v > maxSetVolume) maxSetVolume = v;
    }
    final restingBar = isDark ? colors.separator : colors.panelBackground;

    final trendPct = widget.trendPct;
    final trendUp = (trendPct ?? 0) >= 0;
    final trendColor = trendUp ? colors.trendPositive : colors.trendNegative;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: widget.highlighted
              ? Border.all(color: colors.accent, width: 2)
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + subtitle + PR badge ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.enriched.workoutName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isPr)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius:
                            BorderRadius.circular(AppRadius.button.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events,
                              color: onAccent, size: 11.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'PR',
                            style: TextStyle(
                              color: onAccent,
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ── Mini set-volume bar chart ──
              if (setVolumes.isNotEmpty) ...[
                SizedBox(height: 16.h),
                SizedBox(
                  height: 44.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final v in setVolumes)
                        Expanded(
                          child: Container(
                            height: 44.h *
                                (maxSetVolume > 0
                                        ? (v / maxSetVolume).clamp(0.12, 1.0)
                                        : 0.12)
                                    ,
                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                            decoration: BoxDecoration(
                              color: v >= maxSetVolume
                                  ? colors.accent
                                  : restingBar,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // ── Stat row: volume · duration · trend ──
              SizedBox(height: 14.h),
              Row(
                children: [
                  _StatBlock(
                    label: widget.l10n.volume.toUpperCase(),
                    value: volumeStr,
                    colors: colors,
                  ),
                  SizedBox(width: 24.w),
                  _StatBlock(
                    label: widget.l10n.duration.toUpperCase(),
                    value: durationStr,
                    colors: colors,
                  ),
                  SizedBox(width: 24.w),
                  if (trendPct != null)
                    Row(
                      children: [
                        Text(
                          '${trendUp ? '+' : ''}${trendPct.round()}%',
                          style: TextStyle(
                            color: trendColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          trendUp
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: trendColor,
                          size: 15.sp,
                        ),
                      ],
                    ),
                ],
              ),

              // ── Expanded: exercise rows + delete/share ──
              if (_expanded) ...[
                SizedBox(height: 16.h),
                ...widget.enriched.exercises.map((ex) {
                  final timeStr = ex.startedAt != null
                      ? DateFormat.jm(locale)
                          .format(ex.startedAt!)
                          .toLowerCase()
                      : AppLocalizations.of(context).setsCount(ex.sets);

                  return GestureDetector(
                    onTap: () => showExerciseDetailSheet(
                      context,
                      exercise: ex,
                      session: widget.enriched.session,
                    ),
                    // Opaque so the empty space between text and arrow is
                    // tappable too (deferToChild only hits painted children).
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          // 58x58 rounded rect thumbnail (radius 12)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.exerciseThumb.r,
                            ),
                            child: ex.gifUrl != null
                                ? CachedNetworkImage(
                                    cacheManager: ExerciseGifCache.instance,
                                    imageUrl: ex.gifUrl!,
                                    width: 58.w,
                                    height: 58.h,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      width: 58.w,
                                      height: 58.h,
                                      color: colors.separator,
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const _ExercisePlaceholder(),
                                  )
                                : const _ExercisePlaceholder(),
                          ),
                          SizedBox(width: 12.w),
                          // Name + time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Arrow right
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: colors.textPrimary,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Footer: delete + share
                Row(
                  children: [
                    const Spacer(),
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      onTap: () => _confirmDeleteSession(
                        widget.enriched.session.localId,
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20.sp),
                    ),
                    SizedBox(width: 8.w),
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      onTap: () => context.push(
                        AppRoutes.shareCard,
                        extra: ShareCardData.fromEnrichedSession(
                          widget.enriched,
                          hasPr: widget.isPr,
                        ),
                      ),
                      child: Icon(Icons.ios_share_rounded,
                          color: colors.textPrimary, size: 20.sp),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.colors,
  });
  final String label;
  final String value;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ExercisePlaceholder extends StatelessWidget {
  const _ExercisePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 58.w,
      height: 58.h,
      decoration: BoxDecoration(
        color: colors.separator,
        borderRadius: BorderRadius.circular(AppRadius.exerciseThumb.r),
      ),
      child: Icon(
        Icons.fitness_center_rounded,
        color: colors.textSecondary,
        size: 24.sp,
      ),
    );
  }
}
