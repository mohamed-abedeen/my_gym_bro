import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';

/// Leaderboard + Challenges screen.
///
/// Implements the three Figma frames "iPhone 16 & 17 Pro Max - 57 / 101 / 102":
///  • Leaderboard tab — Current League card, scope (Rivals/Global/Friends),
///    and a server-ranked list with tier colours (weekly board via the
///    `leaderboard_*` RPCs; offline/empty states handled).
///  • Challenges tab — vertically stacked challenge cards with hero photo,
///    progress bar, rank, and an "End in Nd" badge (mock until the
///    challenges backend ships).
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

enum _Tab { leaderboard, challenges }

class _Row {
  const _Row({
    required this.rank,
    required this.name,
    required this.volume,
    required this.tier,
    this.avatarUrl,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final int volume;
  final _Tier tier;
  final String? avatarUrl;
  final bool isMe;
}

enum _Tier { elite, master, standing, movingUp, workHarder }

/// Tier from a row's rank within the visible board: podium ranks get the
/// medal tiers, the upper half is "moving up", the rest "work harder".
_Tier _tierForRank(int rank, int total) {
  if (rank == 1) return _Tier.elite;
  if (rank == 2) return _Tier.master;
  if (rank == 3) return _Tier.standing;
  if (total > 0 && rank <= (total / 2).ceil()) return _Tier.movingUp;
  return _Tier.workHarder;
}

class _Challenge {
  const _Challenge({
    required this.title,
    required this.percent,
    required this.rank,
    required this.daysLeft,
  });

  final String title;
  final int percent;
  final int rank;
  final int daysLeft;
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  _Tab _tab = _Tab.leaderboard;
  LeaderboardScope _scope = LeaderboardScope.rivals;

  static const _challenges = <_Challenge>[
    _Challenge(title: '1000 push up', percent: 30, rank: 20, daysLeft: 25),
    _Challenge(title: '1000 push up', percent: 30, rank: 20, daysLeft: 25),
    _Challenge(title: '1000 push up', percent: 30, rank: 20, daysLeft: 25),
  ];

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Top gradient header strip (Figma Rectangle 23: 440x599)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 599.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.cardElevated.withValues(alpha: 0.4),
                      colors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 8.h),
                _TopBar(
                  tab: _tab,
                  onChange: (t) => setState(() => _tab = t),
                  onBack: () => Navigator.of(context).pop(),
                  l10n: l10n,
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: _tab == _Tab.leaderboard
                      ? _LeaderboardTab(
                          scope: _scope,
                          onScope: (s) => setState(() => _scope = s),
                          l10n: l10n,
                        )
                      : _ChallengesTab(
                          challenges: _challenges,
                          l10n: l10n,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// T O P   B A R
// Back chip + Leaderboard pill + Challenges pill
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.tab,
    required this.onChange,
    required this.onBack,
    required this.l10n,
  });

  final _Tab tab;
  final ValueChanged<_Tab> onChange;
  final VoidCallback onBack;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        children: [
          // Back chip — 34x34 rounded
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34.w,
              height: 34.h,
              decoration: BoxDecoration(
                color: colors.panelBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: colors.textPrimary,
                size: 22.sp,
              ),
            ),
          ),
          const Spacer(),
          // Leaderboard pill
          _TopPill(
            label: l10n.leaderboardTab,
            active: tab == _Tab.leaderboard,
            onTap: () => onChange(_Tab.leaderboard),
          ),
          SizedBox(width: 4.w),
          // Challenges pill
          _TopPill(
            label: l10n.challengesTab,
            active: tab == _Tab.challenges,
            onTap: () => onChange(_Tab.challenges),
          ),
        ],
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34.h,
        constraints: BoxConstraints(minWidth: 103.w),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: active ? colors.accent : colors.panelBackground,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? colors.todayPillText : colors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// L E A D E R B O A R D   T A B
// ─────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({
    required this.scope,
    required this.onScope,
    required this.l10n,
  });

  final LeaderboardScope scope;
  final ValueChanged<LeaderboardScope> onScope;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final entries = ref.watch(leaderboardProvider(scope));

    return ListView(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 24.h),
      children: [
        _CurrentLeagueCard(
          me: entries.valueOrNull
              ?.where((e) => e.isMe)
              .cast<LeaderboardEntry?>()
              .firstWhere((_) => true, orElse: () => null),
          total: entries.valueOrNull?.length ?? 0,
          l10n: l10n,
        ),
        SizedBox(height: 18.h),
        _ScopeSelector(scope: scope, onChange: onScope, l10n: l10n),
        SizedBox(height: 18.h),
        ...entries.when(
          data: (list) {
            if (list.isEmpty) {
              return [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 40.h,
                  ),
                  child: Text(
                    l10n.leaderboardEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ];
            }
            final rows = [
              for (final e in list)
                _Row(
                  rank: e.rank,
                  name: e.name,
                  volume: e.volume.round(),
                  tier: _tierForRank(e.rank, list.length),
                  avatarUrl: e.avatarUrl,
                  isMe: e.isMe,
                ),
            ];
            return [
              for (var i = 0; i < rows.length; i++) ...[
                _LeaderboardRow(row: rows[i], l10n: l10n),
                if (i < rows.length - 1) SizedBox(height: 10.h),
              ],
            ];
          },
          loading: () => [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 60.h),
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              ),
            ),
          ],
          error: (_, __) => [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 40.h,
              ),
              child: Text(
                l10n.leaderboardEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Current League card — 419x194, radius 36 ──

class _CurrentLeagueCard extends StatelessWidget {
  const _CurrentLeagueCard({
    required this.me,
    required this.total,
    required this.l10n,
  });

  /// The caller's own row on the current board, when loaded and present.
  final LeaderboardEntry? me;
  final int total;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tier = me == null ? null : _tierForRank(me!.rank, total);

    return Container(
      height: 194.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(36.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Right-side trophy emblem (placeholder for the Figma "13 1" image)
          Positioned(
            right: -10.w,
            top: 20.h,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 140.sp,
              color: colors.accent.withValues(alpha: 0.85),
            ),
          ),
          // Left-side text content
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 12.w, 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentLeague,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  tier == null
                      ? l10n.leagueMasterTitle
                      : _LeaderboardRow._tierLabel(tier, l10n),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.yourPlace,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      me == null ? '—' : l10n.placeNumber(me!.rank),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Transform.rotate(
                      angle: AppAngles.quarterTurnCcw,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.trendPositive,
                        size: 18.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scope selector (Rivals / Global / Friends) ──

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.scope,
    required this.onChange,
    required this.l10n,
  });

  final LeaderboardScope scope;
  final ValueChanged<LeaderboardScope> onChange;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labels = <LeaderboardScope, String>{
      LeaderboardScope.rivals: l10n.scopeRivals,
      LeaderboardScope.global: l10n.scopeGlobal,
      LeaderboardScope.friends: l10n.scopeFriends,
    };

    return Container(
      height: 48.h,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(39.5.r),
      ),
      child: Row(
        children: LeaderboardScope.values.map((s) {
          final active = scope == s;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(s),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(21.r),
                ),
                child: Text(
                  labels[s]!,
                  style: TextStyle(
                    color: active ? colors.todayPillText : colors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Leaderboard row — 419x80, radius 36 ──

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.row, required this.l10n});

  final _Row row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = _tierPalette(row.tier, colors);
    final isLastFaded = row.tier == _Tier.workHarder && !row.isMe;
    final bgColor = row.isMe ? colors.accent : colors.panelBackground;
    final onBg = row.isMe ? colors.todayPillText : colors.textPrimary;

    return Opacity(
      opacity: isLastFaded ? 0.5 : 1,
      child: Container(
        height: 80.h,
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(36.r),
        ),
        child: Row(
          children: [
            // Rank number — coloured by tier (or black when row is highlighted)
            SizedBox(
              width: 22.w,
              child: Text(
                '${row.rank}',
                style: TextStyle(
                  color: row.isMe ? onBg : palette.rankText,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 6.w),
            // Avatar with optional tier ring (for top 3)
            _AvatarMedal(
              tier: row.tier,
              isMe: row.isMe,
              avatarUrl: row.avatarUrl,
            ),
            SizedBox(width: 11.w),
            // Name + tier sublabel
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: TextStyle(
                      color: onBg,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _tierLabel(row.tier, l10n),
                    style: TextStyle(
                      color: row.isMe ? onBg : palette.subLabel,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Volume + value + arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.volumeLabel,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  _formatVolume(row.volume),
                  style: TextStyle(
                    color: onBg,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(width: 8.w),
            Transform.rotate(
              angle: AppAngles.quarterTurnCcw,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: onBg,
                size: 22.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatVolume(int v) {
    if (v >= 1000) {
      final thousands = v ~/ 1000;
      final remainder = v % 1000;
      return remainder == 0 ? '$thousands,000' : '$v';
    }
    return '$v';
  }

  static String _tierLabel(_Tier t, AppLocalizations l10n) => switch (t) {
        _Tier.elite => l10n.leagueElite,
        _Tier.master => l10n.leagueMaster,
        _Tier.standing => l10n.leagueStanding,
        _Tier.movingUp => l10n.leagueMovingUp,
        _Tier.workHarder => l10n.leagueWorkHarder,
      };
}

class _TierPalette {
  const _TierPalette({
    required this.rankText,
    required this.subLabel,
    this.gradient,
    this.medalText,
  });

  final Color rankText;
  final Color subLabel;
  final List<Color>? gradient;
  final Color? medalText;
}

_TierPalette _tierPalette(_Tier t, AppColorsTheme colors) => switch (t) {
      _Tier.elite => const _TierPalette(
          rankText: Color(0xFFCAA14B),
          subLabel: Color(0xFFCAA14B),
          gradient: [Color(0xFFFFD67D), Color(0xFFC68F18), Color(0xFF674907)],
          medalText: Color(0xFF412C00),
        ),
      _Tier.master => const _TierPalette(
          rankText: Color(0xFF9F9F9F),
          subLabel: Color(0xFF9F9F9F),
          gradient: [Color(0xFFE2E2E2), Color(0xFF969696), Color(0xFF303030)],
          medalText: Color(0xFF1F1F1F),
        ),
      _Tier.standing => const _TierPalette(
          rankText: Color(0xFF95685C),
          subLabel: Color(0xFF95685C),
          gradient: [Color(0xFFFFD2AB), Color(0xFF9F6943), Color(0xFF332217)],
          medalText: Color(0xFF2C1911),
        ),
      _Tier.movingUp => _TierPalette(
          rankText: colors.textPrimary,
          subLabel: colors.textPrimary,
        ),
      _Tier.workHarder => _TierPalette(
          rankText: colors.textPrimary,
          subLabel: colors.textPrimary,
        ),
    };

// ── Avatar with medal ring for top 3 ──

class _AvatarMedal extends StatelessWidget {
  const _AvatarMedal({
    required this.tier,
    required this.isMe,
    this.avatarUrl,
  });

  final _Tier tier;
  final bool isMe;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = _tierPalette(tier, colors);
    final hasMedal = palette.gradient != null;
    final ringSize = 52.w;
    final innerSize = 44.w;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasMedal)
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.476, 1],
                  colors: palette.gradient!,
                ),
              ),
            ),
          ClipOval(
            child: SizedBox(
              width: innerSize,
              height: innerSize,
              child: UserAvatar(
                url: avatarUrl,
                size: innerSize,
                iconColor: isMe
                    ? colors.todayPillText
                    : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// C H A L L E N G E S   T A B
// Stack of hero cards with progress + countdown
// ─────────────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({required this.challenges, required this.l10n});

  final List<_Challenge> challenges;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) {
      final colors = AppColors.of(context);
      return Center(
        child: Text(
          l10n.noChallengesYet,
          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(9.w, 0, 9.w, 24.h),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, i) =>
          _ChallengeCard(challenge: challenges[i], l10n: l10n),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.l10n});

  final _Challenge challenge;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: 281.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(25.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Hero image (push-up photo placeholder — falls back to a gradient).
          Positioned.fill(
            child: _ChallengeHero(colors: colors),
          ),
          // Gradient overlay for text legibility
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
          // "End in 25d" pill (top-right)
          Positioned(
            top: 12.h,
            right: 14.w,
            child: Container(
              height: 28.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(20.5.r),
              ),
              child: Text(
                l10n.endInDays(challenge.daysLeft),
                style: TextStyle(
                  color: colors.todayPillText,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Title + progress + rank + bar (bottom)
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 18.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  challenge.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.percentDone(challenge.percent),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      l10n.rankNumber(challenge.rank),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                _ProgressBar(percent: challenge.percent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({required this.colors});

  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    // Placeholder visual until asset is added — a dark fitness-themed gradient
    // with a barbell silhouette icon. Once a hero image asset is available,
    // swap this for Image.asset('assets/images/challenge_pushup.png', fit: BoxFit.cover).
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.cardElevated,
            colors.panelBackground,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center_rounded,
          color: colors.textPrimary.withValues(alpha: 0.18),
          size: 110.sp,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pct = (percent.clamp(0, 100)) / 100;

    return LayoutBuilder(
      builder: (context, c) {
        final fullWidth = c.maxWidth;
        return Stack(
          children: [
            Container(
              height: 7.h,
              decoration: BoxDecoration(
                color: const Color(0xFF363A0D),
                borderRadius: BorderRadius.circular(7.5.r),
              ),
            ),
            Container(
              width: fullWidth * pct,
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
