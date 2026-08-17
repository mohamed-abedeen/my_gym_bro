import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final icon = switch (challenge.goalType) {
      'volume' => Icons.fitness_center_rounded,
      'sessions' => Icons.event_available_rounded,
      'sets' => Icons.format_list_numbered_rounded,
      'streak' => Icons.local_fire_department_rounded,
      _ => Icons.flag_rounded,
    };
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
  final _targetController = TextEditingController();
  String _goalType = 'volume';
  int _days = 7;
  int _points = 25;

  static const _dayOptions = [7, 14, 31];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final target = double.tryParse(_targetController.text) ?? 0;
    final result = await ref.read(challengeRepositoryProvider).create(
          title: _titleController.text,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text,
          goalType: _goalType,
          goalValue: target,
          points: _points,
          startsAt: now,
          endsAt: now.add(Duration(days: _days)),
        );
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final goalTypes = <(String, String)>[
      ('volume', l10n.goalTypeVolume),
      ('sessions', l10n.goalTypeSessions),
      ('sets', l10n.goalTypeSets),
      ('streak', l10n.goalTypeStreak),
      ('custom', l10n.goalTypeCustom),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
        top: 16.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createChallenge,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _titleController,
              maxLength: 80,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: l10n.challengeTitleLabel,
                counterText: '',
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _descriptionController,
              maxLength: 200,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: l10n.challengeDescriptionLabel,
                counterText: '',
              ),
            ),
            SizedBox(height: 16.h),
            _SectionLabel(text: l10n.challengeGoalLabel),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final (key, label) in goalTypes)
                  ChoiceChip(
                    label: Text(label),
                    selected: _goalType == key,
                    onSelected: (_) => setState(() => _goalType = key),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: l10n.challengeTargetLabel,
              ),
            ),
            SizedBox(height: 16.h),
            _SectionLabel(text: l10n.challengeDurationLabel),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              children: [
                for (final d in _dayOptions)
                  ChoiceChip(
                    label: Text(l10n.durationDaysOption('$d')),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            _SectionLabel(
              text: l10n.challengePointsLabel(
                '$kCommunityChallengeMaxPoints',
              ),
            ),
            Slider(
              value: _points.toDouble(),
              max: kCommunityChallengeMaxPoints.toDouble(),
              divisions: 10,
              activeColor: colors.accent,
              label: '$_points',
              onChanged: (v) => setState(() => _points = v.round()),
            ),
            SizedBox(height: 8.h),
            _AccentPill(label: l10n.createChallenge, onTap: _submit),
          ],
        ),
      ),
    );
  }
}
