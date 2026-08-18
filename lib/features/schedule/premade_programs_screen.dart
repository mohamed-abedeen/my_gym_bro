import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/features/schedule/premade_program_card.dart';
import 'package:my_gym_bro/features/schedule/premade_programs.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Browsable library of curated pre-made programs (5-minute sessions, home
/// workouts, calisthenics, core plans). Installing one creates a normal
/// schedule via [ProgramSeeder.buildSchedule] and selects it on the
/// Workout tab.
class PremadeProgramsScreen extends ConsumerStatefulWidget {
  const PremadeProgramsScreen({super.key});

  @override
  ConsumerState<PremadeProgramsScreen> createState() =>
      _PremadeProgramsScreenState();
}

class _PremadeProgramsScreenState extends ConsumerState<PremadeProgramsScreen> {
  /// null → all categories.
  PremadeCategory? _category;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    final programs = _category == null
        ? premadePrograms
        : premadePrograms.where((p) => p.category == _category).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.premadeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: AppSizes.headerActionBtn.w,
                      height: AppSizes.headerActionBtn.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.card,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: AppSizes.headerActionIcon.sp,
                        color: colors.subtitleText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
              child: Text(
                l10n.premadeSubtitle,
                style: TextStyle(fontSize: 13.sp, color: colors.subtitleText),
              ),
            ),
            SizedBox(
              height: 34.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  _CategoryChip(
                    label: l10n.premadeCategoryAll,
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in PremadeCategory.values)
                    _CategoryChip(
                      label: premadeCategoryLabel(l10n, c),
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 48.h),
                itemCount: programs.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, i) => PremadeProgramCard(
                  program: programs[i],
                  l10n: l10n,
                  onTap: () => _showProgramDetail(context, programs[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProgramDetail(BuildContext context, PremadeProgram program) {
    showPremadeProgramSheet(context, program: program, onInstalled: _onInstalled);
  }

  /// Selects the freshly installed schedule on the Workout tab (same as the
  /// program picker) and confirms with a snackbar on this screen.
  void _onInstalled(int scheduleId) {
    selectInstalledSchedule(ref, scheduleId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.premadeAdded)));
  }
}

/// Opens the program detail/install sheet for [program]. Shared by this
/// library screen and the Discover screen.
void showPremadeProgramSheet(
  BuildContext context, {
  required PremadeProgram program,
  required ValueChanged<int> onInstalled,
}) {
  final colors = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.cardElevated,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) => _ProgramDetailSheet(
        program: program,
        scrollController: scrollController,
        onInstalled: onInstalled,
      ),
    ),
  );
}

/// Selects a freshly installed schedule on the Workout tab, mirroring the
/// program picker (state + persisted last-selected id).
void selectInstalledSchedule(WidgetRef ref, int scheduleId) {
  ref.read(workoutCardStateProvider.notifier).state = WorkoutCardState(
    selectedScheduleId: scheduleId,
  );
  SecureStorage().write('last_selected_schedule_id', scheduleId.toString());
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(17.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.todayPillText : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProgramDetailSheet extends ConsumerStatefulWidget {
  const _ProgramDetailSheet({
    required this.program,
    required this.scrollController,
    required this.onInstalled,
  });

  final PremadeProgram program;
  final ScrollController scrollController;
  final ValueChanged<int> onInstalled;

  @override
  ConsumerState<_ProgramDetailSheet> createState() =>
      _ProgramDetailSheetState();
}

class _ProgramDetailSheetState extends ConsumerState<_ProgramDetailSheet> {
  bool _installing = false;

  Future<void> _install() async {
    if (_installing) return;
    setState(() => _installing = true);
    final l10n = AppLocalizations.of(context);
    final program = widget.program;
    try {
      final seeder = ProgramSeeder(
        ref.read(databaseProvider),
        ref.read(exerciseRepositoryProvider),
      );
      final scheduleId = await seeder.buildSchedule(
        name: program.name(l10n),
        isActive: false,
        days: [
          for (final day in program.days)
            ProgramDay(day.label(l10n), day.exercises),
        ],
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onInstalled(scheduleId);
    } on Object {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final program = widget.program;

    return Column(
      children: [
        SizedBox(height: 10.h),
        Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: colors.textSecondary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: program.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: Icon(
                      program.icon,
                      color: program.color,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 13.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.name(l10n),
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${premadeLevelLabel(l10n, program.level)} · '
                          '${l10n.premadeMinutes(program.minutes)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.subtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                program.tagline(l10n),
                style: TextStyle(fontSize: 13.sp, color: colors.subtitleText),
              ),
              for (final day in program.days) ...[
                SizedBox(height: 18.h),
                Text(
                  day.label(l10n).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: colors.subtitleText,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 6.h,
                  ),
                  child: Column(
                    children: [
                      for (final ex in day.exercises)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 7.h),
                          child: Row(
                            children: [
                              Text(
                                '${ex.sets} × ${ex.reps}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  ex.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
          child: GestureDetector(
            onTap: _install,
            child: Container(
              width: double.infinity,
              height: 52.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: _installing
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.todayPillText,
                      ),
                    )
                  : Text(
                      l10n.premadeAdd,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.todayPillText,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
