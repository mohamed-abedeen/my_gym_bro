import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import 'exercise_detail_sheet.dart';
import 'workout_providers.dart';

/// Show the Log bottom sheet — matches Figma Past Sessions design.
void showLogBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LogSheet(),
  );
}


class _LogSheet extends ConsumerWidget {
  const _LogSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final enriched = ref.watch(enrichedAllSessionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
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
            SizedBox(height: 12.h),

            // ── Header: X  ...  search + check ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.contentPaddingH.w,
              ),
              child: Row(
                children: [
                  // Close button (glass circle)
                  LiquidGlassButton(
                    width: 48.w,
                    height: 48.h,
                    opacity: 0.15,
                    radius: 24.r,
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded,
                        color: colors.textPrimary, size: 22.sp),
                  ),
                  const Spacer(),
                  // Search (glass circle)
                  LiquidGlassButton(
                    width: 48.w,
                    height: 48.h,
                    opacity: 0.15,
                    radius: 24.r,
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
            SizedBox(height: 16.h),

            // "Last Week" title — 24px bold per Figma
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (AppSizes.contentPaddingH + 4).w,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.lastWeek,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // ── Session cards list ──
            Expanded(
              child: enriched.when(
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noRecordsYet,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.contentPaddingH.w,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (_, i) => _SessionCard(
                          enriched: list[i],
                          l10n: l10n,
                          initiallyExpanded: i == 0,
                        ),
                      ),
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2,
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Expandable Session Card — Figma spec:
// bg #29292B, radius 25, collapsed height 77
// Expanded: 58x58 exercise thumbnails (radius 12), exercise time,
// footer with Total Volume + Total Time, share button
// ═══════════════════════════════════════════════════════════════════

class _SessionCard extends StatefulWidget {
  final EnrichedSession enriched;
  final AppLocalizations l10n;
  final bool initiallyExpanded;

  const _SessionCard({
    required this.enriched,
    required this.l10n,
    this.initiallyExpanded = false,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = widget.enriched.session;
    final dayAbbr = DateFormat.E().format(s.startedAt).substring(0, 3);
    final dateStr = DateFormat('d / M / yyyy').format(s.startedAt);
    final title = '$dayAbbr, ${widget.enriched.workoutName}';
    final durationMin = (s.durationSeconds ?? 0) ~/ 60;
    final volume = s.totalVolume?.toInt() ?? 0;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(25.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row — always visible ──
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 16.w, 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chevron
                  SizedBox(
                    width: 44.w,
                    height: 44.h,
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colors.textPrimary,
                      size: 28.sp,
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded content ──
            if (_expanded) ...[
              // Exercise rows
              ...widget.enriched.exercises.map((ex) {
                final timeStr = ex.startedAt != null
                    ? DateFormat('h:mma')
                        .format(ex.startedAt!)
                        .toLowerCase()
                    : '${ex.sets} sets';

                return GestureDetector(
                  onTap: () => showExerciseDetailSheet(
                    context,
                    exercise: ex,
                    session: widget.enriched.session,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 16.w, 12.h),
                    child: Row(
                      children: [
                        // 58x58 rounded rect thumbnail (radius 12)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.exerciseThumb.r,
                          ),
                          child: ex.gifUrl != null
                              ? CachedNetworkImage(
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
                                  color: colors.textPrimary,
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

              SizedBox(height: 8.h),

              // Footer: Total Volume + Total Time + share
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 16.w, 16.h),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.l10n.totalVolume} ${volume}lbs',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${widget.l10n.totalTime} ${durationMin}m',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Share icon — 48x48 per Figma
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      child: Icon(Icons.ios_share_rounded,
                          color: colors.textPrimary, size: 20.sp),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
