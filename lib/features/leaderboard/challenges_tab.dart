import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/leaderboard/challenge_providers.dart';
import 'package:my_gym_bro/features/leaderboard/challenge_repository.dart';
import 'package:my_gym_bro/features/social/friend_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/inline_editable_field.dart';

/// Challenges tab of the Bros screen (Phase 4 — PRD §5.9).
///
/// Restores the Figma hero-card design (git history, purged pre-launch as
/// mock data) on top of real offline-first data: curated daily + community
/// list, join, progress, create, report. Everything renders from the local
/// cache; [challengeRefreshProvider] pushes the outbox and pulls a snapshot
/// on open and on pull-to-refresh.
class ChallengesTab extends ConsumerStatefulWidget {
  const ChallengesTab({super.key});

  @override
  ConsumerState<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends ConsumerState<ChallengesTab> {
  @override
  void initState() {
    super.initState();
    // Re-run recompute + snapshot on every tab open (same pattern as the
    // leaderboard tab). Post-frame: ref can't touch providers in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(challengeRefreshProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final challenges = ref.watch(challengesProvider);
    ref.watch(challengeRefreshProvider);

    return challenges.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: colors.accent,
          strokeWidth: 2.w,
        ),
      ),
      error: (_, __) => _EmptyState(l10n: l10n),
      data: (_) {
        final daily = ref.watch(dailyChallengeProvider);
        final community = ref.watch(communityChallengesProvider);
        final points = ref.watch(myChallengePointsProvider);

        return RefreshIndicator(
          color: colors.accent,
          onRefresh: () => ref.refresh(challengeRefreshProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(9.w, 0, 9.w, 24.h),
            children: [
              _HeaderRow(points: points, l10n: l10n),
              SizedBox(height: 12.h),
              if (daily != null) ...[
                _SectionLabel(text: l10n.dailyChallenge),
                SizedBox(height: 8.h),
                _ChallengeCard(challenge: daily, l10n: l10n),
                SizedBox(height: 16.h),
              ],
              if (community.isNotEmpty) ...[
                _SectionLabel(text: l10n.communityChallenges),
                SizedBox(height: 8.h),
                for (final c in community) ...[
                  _ChallengeCard(challenge: c, l10n: l10n),
                  SizedBox(height: 12.h),
                ],
              ],
              if (daily == null && community.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 60.h),
                  child: _EmptyState(l10n: l10n),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Text(
        l10n.noChallengesYet,
        style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
      ),
    );
  }
}

// ── header: my points chip + create button ───────────────────────────────────

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({required this.points, required this.l10n});

  final int points;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final nf = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );

    return Row(
      children: [
        if (points > 0)
          Container(
            height: 28.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(20.5.r),
            ),
            child: Text(
              l10n.challengePointsChip(nf.format(points)),
              style: TextStyle(
                color: colors.todayPillText,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const Spacer(),
        // Frosted per the glass rules (general surface button; small chip →
        // AppGlass.blurButton).
        GlassSurface(
          height: 32.h,
          radius: 16.r,
          opacity: 0.15,
          blurSigma: AppGlass.blurButton,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          onTap: () => _showCreateChallengeSheet(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: colors.textPrimary, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                l10n.createChallenge,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Icon for a challenge goal type — shared by the card hero and the create
/// sheet's goal picker.
IconData _goalIcon(String goalType) => switch (goalType) {
      'volume' => Icons.fitness_center_rounded,
      'sessions' => Icons.event_available_rounded,
      'sets' => Icons.format_list_numbered_rounded,
      'streak' => Icons.local_fire_department_rounded,
      _ => Icons.flag_rounded,
    };

// ── the hero card (Figma "iPhone … - 101/102", restored from history) ────────

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge, required this.l10n});

  final Challenge challenge;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final uid = ref.watch(currentUserIdProvider);
    final participation =
        ref.watch(participationForProvider(challenge.remoteId ?? ''));
    final nf = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );

    final now = DateTime.now();
    final ended = challenge.status == 'ended' || now.isAfter(challenge.endsAt);
    final joined = participation != null;
    final completed = participation?.completedAt != null;
    final mine = uid != null && challenge.creatorId == uid;
    final hasMenu = joined || mine || challenge.source == 'community';

    return Container(
      height: AppSizes.challengeCardH.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(25.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: _ChallengeHero(challenge: challenge)),
          // Gradient overlay for text legibility (Figma stops).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.21, 0.73],
                  colors: [
                    colors.panelBackground.withValues(alpha: 0),
                    colors.panelBackground.withValues(alpha: 0),
                    colors.panelBackground,
                  ],
                ),
              ),
            ),
          ),
          // Points chip (top-left).
          if (challenge.points > 0)
            Positioned(
              top: 12.h,
              left: 14.w,
              child: _Chip(
                text: l10n.plusPoints('${challenge.points}'),
                background: colors.panelBackground.withValues(alpha: 0.7),
                foreground: colors.textPrimary,
              ),
            ),
          // Countdown pill + card menu (top-right).
          Positioned(
            top: 12.h,
            right: 14.w,
            child: Row(
              children: [
                _Chip(
                  text: ended
                      ? l10n.endedLabel
                      : l10n.endsInShort(_remainingLabel(l10n, challenge)),
                  background: colors.accent,
                  foreground: colors.todayPillText,
                ),
                if (hasMenu) ...[
                  SizedBox(width: 4.w),
                  InkWell(
                    borderRadius: BorderRadius.circular(14.r),
                    onTap: () => _showCardMenu(
                      context,
                      ref,
                      challenge: challenge,
                      participation: participation,
                      mine: mine,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: colors.textPrimary,
                        size: 18.sp,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Title + state row (bottom).
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 16.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title(l10n, challenge),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_description(l10n, challenge) case final desc?) ...[
                  SizedBox(height: 2.h),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                if (completed)
                  _CompletedRow(
                    l10n: l10n,
                    pointsAwarded: participation!.pointsAwarded,
                  )
                else if (joined)
                  _ProgressSection(
                    challenge: challenge,
                    participation: participation,
                    l10n: l10n,
                    nf: nf,
                  )
                else if (!ended && challenge.status == 'active')
                  _JoinButton(challenge: challenge, l10n: l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "3d" / "17h" style remaining time for the countdown pill.
String _remainingLabel(AppLocalizations l10n, Challenge c) {
  final remaining = c.endsAt.difference(DateTime.now());
  if (remaining.inHours >= 48) {
    return l10n.durationShortDays('${remaining.inDays}');
  }
  final hours = (remaining.inMinutes / 60).ceil().clamp(1, 48);
  return l10n.durationShortHours('$hours');
}

/// Curated challenges localize via their template id; community challenges
/// (and unknown future templates) fall back to the server-stored text.
String _title(AppLocalizations l10n, Challenge c) => switch (c.templateId) {
      'tpl_daily_one_session' => l10n.tplDailyOneSessionTitle,
      'tpl_daily_volume_5k' => l10n.tplDailyVolume5kTitle,
      'tpl_daily_volume_10k' => l10n.tplDailyVolume10kTitle,
      'tpl_daily_sets_12' => l10n.tplDailySets12Title,
      'tpl_daily_sets_20' => l10n.tplDailySets20Title,
      _ => c.title,
    };

String? _description(AppLocalizations l10n, Challenge c) =>
    switch (c.templateId) {
      'tpl_daily_one_session' => l10n.tplDailyOneSessionDesc,
      'tpl_daily_volume_5k' => l10n.tplDailyVolume5kDesc,
      'tpl_daily_volume_10k' => l10n.tplDailyVolume10kDesc,
      'tpl_daily_sets_12' => l10n.tplDailySets12Desc,
      'tpl_daily_sets_20' => l10n.tplDailySets20Desc,
      _ => c.description,
    };

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20.5.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final icon = _goalIcon(challenge.goalType);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.cardElevated, colors.panelBackground],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: colors.textPrimary.withValues(alpha: 0.18),
          size: 80.sp,
        ),
      ),
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.l10n, required this.pointsAwarded});

  final AppLocalizations l10n;
  final int pointsAwarded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: colors.accent, size: 16.sp),
        SizedBox(width: 6.w),
        Text(
          l10n.challengeCompleted,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (pointsAwarded > 0) ...[
          SizedBox(width: 8.w),
          Text(
            l10n.plusPoints('$pointsAwarded'),
            style: TextStyle(
              color: colors.accent,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({
    required this.challenge,
    required this.participation,
    required this.l10n,
    required this.nf,
  });

  final Challenge challenge;
  final ChallengeParticipant participation;
  final AppLocalizations l10n;
  final NumberFormat nf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final goal = challenge.goalValue;
    final progress = participation.progress.clamp(0, goal);
    final pct = goal > 0 ? (progress / goal * 100).round() : 0;

    if (challenge.goalType == 'custom') {
      // The device can't measure a custom goal — honor-system button.
      return _AccentPill(
        label: l10n.markComplete,
        onTap: () => ref
            .read(challengeRepositoryProvider)
            .markCustomComplete(challenge, participation),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.percentDone('$pct'),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              l10n.progressOfGoal(
                nf.format(progress.round()),
                nf.format(goal.round()),
              ),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        _ProgressBar(fraction: goal > 0 ? progress / goal : 0),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pct = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            Container(
              height: 7.h,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(7.5.r),
              ),
            ),
            Container(
              width: c.maxWidth * pct,
              height: 7.h,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(7.5.r),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _JoinButton extends ConsumerWidget {
  const _JoinButton({required this.challenge, required this.l10n});

  final Challenge challenge;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AccentPill(
      label: l10n.joinChallenge,
      onTap: () async {
        final result =
            await ref.read(challengeRepositoryProvider).join(challenge);
        if (!context.mounted) return;
        if (result == JoinChallengeResult.notSignedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.signInToJoinChallenges)),
          );
        }
      },
    );
  }
}

class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20.5.r),
      onTap: onTap,
      child: Container(
        height: 34.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(20.5.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.todayPillText,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── card menu: leave / report / delete ───────────────────────────────────────

Future<void> _showCardMenu(
  BuildContext context,
  WidgetRef ref, {
  required Challenge challenge,
  required ChallengeParticipant? participation,
  required bool mine,
}) async {
  final colors = AppColors.of(context);
  final l10n = AppLocalizations.of(context);
  final repo = ref.read(challengeRepositoryProvider);

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          if (participation != null)
            ListTile(
              title: Text(
                l10n.leaveChallenge,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
              ),
              onTap: () => Navigator.of(ctx).pop('leave'),
            ),
          if (challenge.source == 'community' && !mine)
            ListTile(
              title: Text(
                l10n.reportChallenge,
                style: TextStyle(color: colors.danger, fontSize: 14.sp),
              ),
              onTap: () => Navigator.of(ctx).pop('report'),
            ),
          if (mine)
            ListTile(
              title: Text(
                l10n.deleteChallenge,
                style: TextStyle(color: colors.danger, fontSize: 14.sp),
              ),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'leave':
      if (participation != null) await repo.leave(participation);
    case 'delete':
      await repo.deleteOwn(challenge);
    case 'report':
      await _showChallengeReportSheet(context, ref, challenge: challenge);
  }
}

/// Report a community challenge (store safety requirement). Same canned
/// reasons + stable English wire values as the user report sheet.
Future<void> _showChallengeReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required Challenge challenge,
}) async {
  final colors = AppColors.of(context);
  final l10n = AppLocalizations.of(context);
  final reasons = <(String, String)>[
    ('spam', l10n.reportReasonSpam),
    ('harassment', l10n.reportReasonHarassment),
    ('impersonation', l10n.reportReasonImpersonation),
    ('other', l10n.reportReasonOther),
  ];

  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
            child: Text(
              l10n.reportSheetTitle,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final (key, label) in reasons)
            ListTile(
              title: Text(
                label,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
              ),
              onTap: () => Navigator.of(ctx).pop(key),
            ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );
  if (reason == null) return;

  await ref.read(challengeRepositoryProvider).report(challenge, reason);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.challengeReportedToast)),
    );
  }
}

// ── create sheet ─────────────────────────────────────────────────────────────

Future<void> _showCreateChallengeSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final colors = AppColors.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (ctx) => const _CreateChallengeSheet(),
  );
}

class _CreateChallengeSheet extends ConsumerStatefulWidget {
  const _CreateChallengeSheet();

  @override
  ConsumerState<_CreateChallengeSheet> createState() =>
      _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends ConsumerState<_CreateChallengeSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _goalType = 'volume';
  int _target = 0;
  int _days = 7;
  int _points = 25;
  bool _submitting = false;

  static const _dayOptions = [7, 14, 31];

  /// Mirrors the repository's validation (non-empty title, goal ≥ 1) so the
  /// CTA only lights up for a challenge that will actually be accepted.
  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty && _target >= 1 && !_submitting;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    setState(() => _submitting = true);
    final result = await ref.read(challengeRepositoryProvider).create(
          title: _titleController.text,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text,
          goalType: _goalType,
          goalValue: _target.toDouble(),
          points: _points,
          startsAt: now,
          endsAt: now.add(Duration(days: _days)),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case CreateChallengeResult.created:
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.challengeCreatedToast)),
        );
      case CreateChallengeResult.invalid:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.challengeInvalidToast)),
        );
      case CreateChallengeResult.notSignedIn:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signInToJoinChallenges)),
        );
    }
  }

  /// Unit shown next to the target: kg for volume (the goal is stored in
  /// kg, see `goalTypeVolume`), the goal's own name for counted goals, none
  /// for custom.
  String? _targetUnit(AppLocalizations l10n) => switch (_goalType) {
        'volume' => 'kg',
        'sessions' => l10n.goalTypeSessions,
        'sets' => l10n.goalTypeSets,
        'streak' => l10n.goalTypeStreak,
        _ => null,
      };

  Future<void> _editTarget(AppLocalizations l10n) async {
    // The shared calculator-style numpad sheet (same entry surface as the
    // workout set fields) instead of the OS keyboard.
    final raw = await showNumpadSheet(
      context,
      title: l10n.challengeTargetLabel,
      initial: '$_target',
      allowDecimal: false,
      suffix: _goalType == 'volume' ? 'kg' : null,
    );
    if (raw == null || !mounted) return;
    setState(() => _target = int.tryParse(raw) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final goalTypes = <(String, String)>[
      ('volume', l10n.goalTypeVolume),
      ('sessions', l10n.goalTypeSessions),
      ('sets', l10n.goalTypeSets),
      ('streak', l10n.goalTypeStreak),
      ('custom', l10n.goalTypeCustom),
    ];

    Widget goalTile((String, String) goal) => _ChoiceTile(
          icon: _goalIcon(goal.$1),
          label: goal.$2,
          selected: _goalType == goal.$1,
          onTap: () => setState(() => _goalType = goal.$1),
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.w,
          10.h,
          20.w,
          MediaQuery.paddingOf(context).bottom + 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              l10n.createChallenge,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 20.h),
            _SectionLabel(text: l10n.challengeTitleLabel),
            SizedBox(height: 8.h),
            _SheetTextField(
              controller: _titleController,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16.h),
            _SectionLabel(text: l10n.challengeDescriptionLabel),
            SizedBox(height: 8.h),
            _SheetTextField(
              controller: _descriptionController,
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
            ),
            SizedBox(height: 22.h),
            _SectionLabel(text: l10n.challengeGoalLabel),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(child: goalTile(goalTypes[0])),
                SizedBox(width: 8.w),
                Expanded(child: goalTile(goalTypes[1])),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(child: goalTile(goalTypes[2])),
                SizedBox(width: 8.w),
                Expanded(child: goalTile(goalTypes[3])),
              ],
            ),
            SizedBox(height: 8.h),
            goalTile(goalTypes[4]),
            SizedBox(height: 22.h),
            _SectionLabel(text: l10n.challengeTargetLabel),
            SizedBox(height: 8.h),
            _TargetField(
              value: _target > 0 ? nf.format(_target) : null,
              unit: _targetUnit(l10n),
              onTap: () => _editTarget(l10n),
            ),
            SizedBox(height: 22.h),
            _SectionLabel(text: l10n.challengeDurationLabel),
            SizedBox(height: 8.h),
            _SegmentedPicker(
              labels: [
                for (final d in _dayOptions) l10n.durationDaysOption('$d'),
              ],
              selectedIndex: _dayOptions.indexOf(_days),
              onSelected: (i) => setState(() => _days = _dayOptions[i]),
            ),
            SizedBox(height: 22.h),
            Row(
              children: [
                Expanded(
                  child: _SectionLabel(
                    text: l10n.challengePointsLabel(
                      '$kCommunityChallengeMaxPoints',
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    l10n.plusPoints(nf.format(_points)),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.h,
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.textPrimary.withValues(alpha: 0.12),
                thumbColor: colors.accent,
                overlayColor: colors.accent.withValues(alpha: 0.14),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: _points.toDouble(),
                max: kCommunityChallengeMaxPoints.toDouble(),
                divisions: 10,
                onChanged: (v) => setState(() => _points = v.round()),
              ),
            ),
            SizedBox(height: 12.h),
            _SubmitButton(
              label: l10n.createChallenge,
              enabled: _canSubmit,
              busy: _submitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Filled, borderless text field for the create sheet — lime outline on
/// focus, no Material underline.
class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.onChanged,
  });

  final TextEditingController controller;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(14.r);
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
      cursorColor: colors.accent,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15.sp,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: colors.cardElevated,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
    );
  }
}

/// Selectable icon + label tile (goal picker). Selected: lime outline and a
/// faint lime wash, keeping the sheet's accent instead of the default
/// Material chip colours.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(14.r);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: BoxConstraints(minHeight: 48.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.14)
                  : colors.cardElevated,
              borderRadius: radius,
              border: Border.all(
                color: selected ? colors.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18.sp,
                  color: selected ? colors.accent : colors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.sp,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large read-only target value; tapping opens the numpad sheet.
class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.value,
    required this.unit,
    required this.onTap,
  });

  /// Formatted target, or null while unset (shows a muted 0).
  final String? value;
  final String? unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(14.r);
    return Material(
      color: colors.cardElevated,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value ?? '0',
                style: TextStyle(
                  color: value == null
                      ? colors.textSecondary.withValues(alpha: 0.6)
                      : colors.textPrimary,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit != null) ...[
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                Icons.dialpad_rounded,
                size: 18.sp,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width segmented control — the selected segment is a lime pill.
class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 38.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? colors.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: i == selectedIndex
                            ? colors.todayPillText
                            : colors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-width lime CTA; dimmed and inert until the form is valid.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(26.r);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled || busy ? 1 : 0.4,
      child: Material(
        color: colors.accent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 52.h,
            width: double.infinity,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.todayPillText,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: colors.todayPillText,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
