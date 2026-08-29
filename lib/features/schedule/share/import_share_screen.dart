import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/deep_link_service.dart';
import 'package:my_gym_bro/features/schedule/premade_programs_screen.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_codec.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_importer.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_service.dart';
import 'package:my_gym_bro/features/schedule/split_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Deep-link/paste-code target for a shared routine: fetches the share by
/// code, previews it STRAIGHT FROM THE PAYLOAD (names travel in the payload,
/// so the preview never needs the local catalogue), and imports it as
/// ordinary local schedule rows.
///
/// Reachable while paywall-locked (importing is free — the router exempts
/// `/s/`); the gate re-applies as soon as the user navigates on.
class ImportShareScreen extends ConsumerStatefulWidget {
  const ImportShareScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<ImportShareScreen> createState() => _ImportShareScreenState();
}

class _ImportShareScreenState extends ConsumerState<ImportShareScreen> {
  ShareFetchResult? _result; // null while fetching
  Schedule? _activeSchedule; // append target for day shares
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _result = null);
    final result =
        await ref.read(routineShareServiceProvider).fetchShare(widget.code);
    final active = await ref.read(scheduleDaoProvider).getActive();
    if (!mounted) return;
    setState(() {
      _result = result;
      _activeSchedule = active;
    });
  }

  Future<void> _import({required bool appendToActive}) async {
    final fetched = _result;
    if (_importing || fetched is! ShareFetched) return;
    setState(() => _importing = true);
    final l10n = AppLocalizations.of(context);
    try {
      final importer = ref.read(routineShareImporterProvider);
      final active = _activeSchedule;
      final scheduleId = appendToActive && active != null
          ? await importer.appendDayToSchedule(fetched.payload, active.localId)
          : await importer.importAsNewSchedule(fetched.payload);
      unawaited(
        ref.read(routineShareServiceProvider).markImported(widget.code),
      );
      selectInstalledSchedule(ref, scheduleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importShareImported)));
      context.go(AppRoutes.home);
    } on Object {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importShareFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.contentPaddingH.w,
                8.h,
                AppSizes.contentPaddingH.w,
                0,
              ),
              child: Row(
                children: [
                  SplitHeaderButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.home),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    l10n.importShareTitle,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(child: _body(l10n, colors)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, AppColorsTheme colors) {
    return switch (_result) {
      null => _message(
          colors,
          l10n.importShareLoading,
          spinner: true,
        ),
      ShareFetched(:final payload) => _preview(l10n, colors, payload),
      ShareNotFound() => _message(colors, l10n.importShareNotFound),
      ShareFetchSignedOut() => _message(
          colors,
          l10n.importShareSignIn,
          actionLabel: l10n.importShareSignInAction,
          onAction: () {
            // Stash the code so the import replays once sign-in lands.
            DeepLinkService.stashCode(widget.code);
            context.go(AppRoutes.signIn);
          },
        ),
      ShareFetchUnavailable() => _message(
          colors,
          l10n.importShareOffline,
          actionLabel: l10n.shareRoutineRetry,
          onAction: _fetch,
        ),
      ShareVersionUnsupported() =>
        _message(colors, l10n.importShareUnsupported),
      ShareFetchFailed() => _message(
          colors,
          l10n.importShareFailed,
          actionLabel: l10n.shareRoutineRetry,
          onAction: _fetch,
        ),
    };
  }

  Widget _message(
    AppColorsTheme colors,
    String text, {
    bool spinner = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              SizedBox(
                width: 28.w,
                height: 28.w,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colors.accent,
                ),
              )
            else
              Icon(
                Icons.cloud_off_rounded,
                size: 32.sp,
                color: colors.textSecondary,
              ),
            SizedBox(height: 12.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 16.h),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.todayPillText,
                  padding:
                      EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _preview(
    AppLocalizations l10n,
    AppColorsTheme colors,
    RoutineSharePayload payload,
  ) {
    final isDay = payload.kind == RoutineShareKind.day;
    final canAppend = isDay && _activeSchedule != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      isDay
                          ? l10n.importShareKindDay
                          : l10n.importShareKindProgram,
                      style: TextStyle(
                        color: colors.todayPillText,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '${l10n.premadeDaysCount(payload.days.length)} · '
                      '${l10n.premadeExercisesCount(payload.exerciseCount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSizes.contentPaddingH.w,
              0,
              AppSizes.contentPaddingH.w,
              16.h,
            ),
            itemCount: payload.days.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, i) =>
                _dayCard(l10n, colors, i, payload.days[i]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.contentPaddingH.w,
            8.h,
            AppSizes.contentPaddingH.w,
            12.h,
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.todayPillText,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed:
                      _importing ? null : () => _import(appendToActive: false),
                  child: _importing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.todayPillText,
                          ),
                        )
                      : Text(
                          l10n.importShareAddProgram,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (canAppend) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(
                        color: colors.textSecondary.withValues(alpha: .4),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed:
                        _importing ? null : () => _import(appendToActive: true),
                    child: Text(
                      l10n.importShareAppendToActive,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayCard(
    AppLocalizations l10n,
    AppColorsTheme colors,
    int index,
    SharedDay day,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.label.isEmpty ? l10n.dayNumber(index + 1) : day.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (day.isRest)
                Text(
                  l10n.importShareRestDay,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (!day.isRest) ...[
            SizedBox(height: 8.h),
            for (final exercise in day.exercises)
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${exercise.sets} × ${exercise.reps}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
