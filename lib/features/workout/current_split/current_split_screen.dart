import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/schedule_builder_screen.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_models.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_providers.dart';
import 'package:my_gym_bro/features/workout/reports_screen.dart';
import 'package:my_gym_bro/features/workout/status_bottom_sheet.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

class CurrentSplitScreen extends ConsumerWidget {
  const CurrentSplitScreen({
    required this.scheduleId,
    required this.onBack,
    super.key,
  });

  final int scheduleId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(currentSplitOverviewProvider(scheduleId));
    final resolvedScheduleId = overview.valueOrNull?.schedule.localId;

    return ColoredBox(
      color: AppColors.of(context).background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.contentPaddingH,
            8,
            AppSizes.contentPaddingH,
            112,
          ),
          child: CustomScrollView(
            key: const Key('current_split_screen'),
            slivers: [
              SliverToBoxAdapter(
                child: _TopControls(
                  onBack: onBack,
                  scheduleId: resolvedScheduleId,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ...overview.when(
                loading: () => const <Widget>[
                  SliverToBoxAdapter(child: _LoadingState()),
                ],
                error: (_, _) => <Widget>[
                  SliverToBoxAdapter(
                    child: _MessageState(
                      key: const Key('current_split_error'),
                      icon: Icons.cloud_off_rounded,
                      message: AppLocalizations.of(
                        context,
                      ).currentSplitLoadError,
                      actionLabel: AppLocalizations.of(context).retry,
                      actionKey: const Key('current_split_retry'),
                      onAction: () => ref.invalidate(
                        currentSplitOverviewProvider(scheduleId),
                      ),
                    ),
                  ),
                ],
                data: (data) => data == null
                    ? <Widget>[
                        SliverToBoxAdapter(
                          child: _MessageState(
                            key: const Key('current_split_no_plan'),
                            icon: Icons.calendar_month_rounded,
                            message: AppLocalizations.of(
                              context,
                            ).currentSplitNoPlanMessage,
                            actionLabel: AppLocalizations.of(
                              context,
                            ).currentSplitCreatePlan,
                            actionKey: const Key('current_split_create_plan'),
                            onAction: () => context.push(
                              AppRoutes.scheduleBuilder,
                              extra: const ScheduleBuilderArgs(),
                            ),
                          ),
                        ),
                      ]
                    : _overviewSlivers(context, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _overviewSlivers(
    BuildContext context,
    CurrentSplitOverviewData data,
  ) {
    final resolvedScheduleId = data.schedule.localId;
    return [
      SliverToBoxAdapter(child: _Hero(data: data)),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverToBoxAdapter(child: _Metrics(data: data)),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      const SliverToBoxAdapter(child: _QuickActions()),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      SliverToBoxAdapter(child: _PlanHeading()),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (data.days.isEmpty)
        SliverToBoxAdapter(
          child: _MessageState(
            key: const Key('current_split_empty_plan'),
            icon: Icons.event_note_rounded,
            message: AppLocalizations.of(context).currentSplitEmptyPlanMessage,
            actionLabel: AppLocalizations.of(context).currentSplitBuildPlan,
            actionKey: const Key('current_split_create_plan'),
            onAction: () => context.push(
              AppRoutes.scheduleBuilder,
              extra: ScheduleBuilderArgs(scheduleId: resolvedScheduleId),
            ),
          ),
        )
      else ...[
        SliverList.builder(
          itemCount: data.days.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == data.days.length - 1 ? 20 : 10,
            ),
            child: _DayRow(
              scheduleId: resolvedScheduleId,
              summary: data.days[index],
              fallbackDayNumber: index + 1,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _DiscoverPlansButton()),
      ],
    ];
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const Key('current_split_loading'),
      liveRegion: true,
      label: l10n.currentSplitLoading,
      excludeSemantics: true,
      child: GlassSurface(
        tint: colors.panelBackground,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: colors.accent,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.currentSplitLoading,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassSurface(
      tint: colors.panelBackground,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ExcludeSemantics(child: Icon(icon, color: colors.accent, size: 32)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: actionLabel,
              onTap: onAction,
              excludeSemantics: true,
              child: SizedBox(
                key: actionKey,
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(actionLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({required this.onBack, required this.scheduleId});

  final VoidCallback onBack;
  final int? scheduleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final canEdit = scheduleId != null;
    final editLabel = canEdit
        ? l10n.currentSplitEditPlan
        : '${l10n.currentSplitEditPlan}, ${l10n.currentSplitUnavailable}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          key: const Key('current_split_back_button'),
          button: true,
          label: l10n.back,
          onTap: onBack,
          excludeSemantics: true,
          child: IconButton(
            onPressed: onBack,
            tooltip: l10n.back,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          ),
        ),
        Semantics(
          key: const Key('current_split_edit_button'),
          button: true,
          enabled: canEdit,
          label: editLabel,
          onTap: canEdit
              ? () => context.push(
                  AppRoutes.scheduleBuilder,
                  extra: ScheduleBuilderArgs(scheduleId: scheduleId),
                )
              : null,
          excludeSemantics: true,
          child: IconButton(
            onPressed: canEdit
                ? () => context.push(
                    AppRoutes.scheduleBuilder,
                    extra: ScheduleBuilderArgs(scheduleId: scheduleId),
                  )
                : null,
            tooltip: editLabel,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.more_horiz_rounded, color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.data});

  final CurrentSplitOverviewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final details = _HeroDetails(data: data);
    final anatomy = Semantics(
      excludeSemantics: true,
      child: AnatomyBody(
        height: largeText ? 180 : 220,
        gender: ref.watch(anatomyGenderProvider),
        basePngPath: ref.watch(activeSkinPathProvider),
        muscleStates: data.anatomyMuscles,
        highlightColor: colors.accent,
      ),
    );
    return GlassSurface(
      key: const Key('current_split_hero'),
      tint: colors.panelBackground,
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 14),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: anatomy),
              ],
            )
          : SizedBox(
              height: 236,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 11, child: details),
                  Expanded(
                    flex: 8,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: anatomy,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeroDetails extends StatelessWidget {
  const _HeroDetails({required this.data});

  final CurrentSplitOverviewData data;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.currentPlanEyebrow,
            style: TextStyle(
              color: colors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.schedule.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                l10n.trainingDaysCount(data.trainingDayCount),
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.currentSplitDescription,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data});

  final CurrentSplitOverviewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassSurface(
      key: const Key('current_split_metrics'),
      tint: AppColors.of(context).panelBackground,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          _Metric(
            value: data.trainingDayCount,
            label: l10n.currentSplitTrainingDays,
          ),
          _Metric(value: data.totalExerciseCount, label: l10n.exercisesLabel),
          _Metric(
            value: data.totalPlannedSets,
            label: l10n.currentSplitPlannedSets,
          ),
          _Metric(value: data.restDayCount, label: l10n.currentSplitRestDays),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('current_split_quick_actions'),
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                key: const Key('current_split_action_progress'),
                icon: Icons.insights_rounded,
                label: l10n.currentSplitProgress,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReportsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                key: const Key('current_split_action_nutrition'),
                icon: Icons.restaurant_rounded,
                label: l10n.currentSplitNutrition,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                key: const Key('current_split_action_statistics'),
                icon: Icons.query_stats_rounded,
                label: l10n.currentSplitStatistics,
                onTap: () => showStatusBottomSheet(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                key: const Key('current_split_action_settings'),
                icon: Icons.settings_rounded,
                label: l10n.settings,
                onTap: () => context.push(AppRoutes.settings),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    super.key,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? label
          : '$label, ${AppLocalizations.of(context).currentSplitUnavailable}',
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Ink(
              decoration: BoxDecoration(
                color: colors.panelBackground,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: enabled
                      ? colors.accent.withValues(alpha: 0.16)
                      : colors.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      icon,
                      color: enabled ? colors.accent : colors.textSecondary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.of(context).currentSplitWeeklyPlan,
    key: const Key('current_split_plan_heading'),
    style: TextStyle(
      color: AppColors.of(context).textPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.scheduleId,
    required this.summary,
    required this.fallbackDayNumber,
  });

  final int scheduleId;
  final CurrentSplitDaySummary summary;
  final int fallbackDayNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final day = summary.day;
    final dayLabel = (day.label?.trim().isNotEmpty ?? false)
        ? day.label!
        : l10n.dayNumber(fallbackDayNumber);
    final detail = summary.isRestDay
        ? l10n.restDay
        : '${l10n.currentSplitExercisesCount(summary.exerciseCount)} · ${l10n.setsCount(summary.plannedSetCount)}';
    final muscleGroups = summary.muscleGroups.take(3).join(', ');
    final semanticsLabel = [
      dayLabel,
      if (summary.isRestDay) l10n.restDay,
      if (!summary.isRestDay && muscleGroups.isNotEmpty) muscleGroups,
      if (!summary.isRestDay)
        l10n.currentSplitExercisesCount(summary.exerciseCount),
      if (!summary.isRestDay) l10n.setsCount(summary.plannedSetCount),
    ].join(', ');
    void openDay() {
      context.push(
        AppRoutes.scheduleBuilder,
        extra: ScheduleBuilderArgs(
          scheduleId: scheduleId,
          initialDayLocalId: day.localId,
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: l10n.currentSplitOpenPlanDay,
      onTap: openDay,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('current_split_day_${day.localId}'),
          onTap: openDay,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Ink(
              decoration: BoxDecoration(
                color: colors.panelBackground,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          (summary.isRestDay
                                  ? colors.textSecondary
                                  : colors.accent)
                              .withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      summary.isRestDay
                          ? Icons.hotel_rounded
                          : Icons.fitness_center_rounded,
                      color: summary.isRestDay
                          ? colors.textSecondary
                          : colors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          summary.isRestDay || muscleGroups.isEmpty
                              ? detail
                              : '$muscleGroups · $detail',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverPlansButton extends StatelessWidget {
  const _DiscoverPlansButton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      key: const Key('current_split_discover_disabled'),
      button: true,
      enabled: false,
      label:
          '${AppLocalizations.of(context).currentSplitDiscoverPlans}, ${AppLocalizations.of(context).currentSplitUnavailable}',
      excludeSemantics: true,
      child: IgnorePointer(
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Text(
            AppLocalizations.of(context).currentSplitDiscoverPlans,
            style: TextStyle(
              color: colors.accent.withValues(alpha: 0.58),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
