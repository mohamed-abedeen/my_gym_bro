import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/exercise_detail_sheet.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Show the Log bottom sheet — matches Figma Past Sessions design.
void showLogBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
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
    final unit = ref.watch(weightUnitProvider);

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
                          unit: unit,
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

class _SessionCard extends ConsumerStatefulWidget {

  const _SessionCard({
    required this.enriched,
    required this.l10n,
    required this.unit,
    this.initiallyExpanded = false,
  });
  final EnrichedSession enriched;
  final AppLocalizations l10n;
  final WeightUnit unit;
  final bool initiallyExpanded;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

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
    ref.invalidate(enrichedAllSessionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = widget.enriched.session;
    final dayAbbr = DateFormat.E().format(s.startedAt).substring(0, 3);
    final dateStr = DateFormat('d / M / yyyy').format(s.startedAt);
    final title = '$dayAbbr, ${widget.enriched.workoutName}';
    final durationMin = (s.durationSeconds ?? 0) ~/ 60;
    final volumeStr = formatWeight(s.totalVolume, widget.unit, decimals: 0, withUnit: true);

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
                          '${widget.l10n.totalVolume} $volumeStr',
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
                    // Delete button
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
