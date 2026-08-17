import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/leaderboard/challenges_tab.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/social/bros_sheet.dart';
import 'package:my_gym_bro/features/social/friend_providers.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';

/// Leaderboard + Challenges screen.
///
/// Implements the three Figma frames "iPhone 16 & 17 Pro Max - 57 / 101 / 102":
///  • Leaderboard tab — Current League card, scope (Rivals/Global/Friends),
///    and a server-ranked list with tier colours (weekly board via the
///    `leaderboard_*` RPCs; offline/empty states handled).
///  • Challenges tab — curated daily + community challenges from the local
///    cache (Phase 4), hero-card UI restored from history in
///    `challenges_tab.dart`.
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

/// Tier from a row's 1-based *position within the visible list*: the podium
/// gets the medal tiers, the upper half is "moving up", the rest "work
/// harder". Position (not the row's rank number) matters because Rivals
/// rows carry global ranks (e.g. 132–142) while the list is an ~11-row
/// window — tiering by rank would mark the whole pod "work harder".
_Tier _tierForPosition(int position, int total) {
  if (position == 1) return _Tier.elite;
  if (position == 2) return _Tier.master;
  if (position == 3) return _Tier.standing;
  if (total > 0 && position <= (total / 2).ceil()) return _Tier.movingUp;
  return _Tier.workHarder;
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  _Tab _tab = _Tab.leaderboard;
  LeaderboardScope _scope = LeaderboardScope.rivals;

  @override
  void initState() {
    super.initState();
    // The scaffold's rank listener keeps the global board provider alive for
    // the whole session, so refetch on every screen open to stay fresh.
    // Post-frame: ref can't touch the provider scope during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(leaderboardProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // Bros tab (2026-08-15): rendered as the third tab inside
    // MyGymBroScaffold — no own Scaffold, no back button, and the content
    // ends clear of the bottom nav.
    return Stack(
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
          bottom: false,
          child: Column(
            children: [
              SizedBox(height: 8.h),
              _TopBar(
                tab: _tab,
                onChange: (t) => setState(() => _tab = t),
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
                    : const ChallengesTab(),
              ),
              // Keeps lists/cards clear of the bottom nav.
              SizedBox(height: AppSizes.navClearanceOf(context)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// T O P   B A R
// Leaderboard pill + Challenges pill (no back —
// this is a root tab, not a pushed screen)
// ─────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.tab,
    required this.onChange,
    required this.l10n,
  });

  final _Tab tab;
  final ValueChanged<_Tab> onChange;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final pendingCount = ref.watch(pendingRequestCountProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

          // Add-bros entry (Phase B) — 48pt header spec, frosted per the
          // glass rules; the badge is the incoming-requests inbox count.
          Positioned(
            right: 2.w,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LiquidGlassButton(
                  width: AppSizes.headerActionBtn.w,
                  height: AppSizes.headerActionBtn.w,
                  opacity: 0.15,
                  radius: (AppSizes.headerActionBtn / 2).r,
                  onTap: () => showBrosSheet(context),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: colors.textPrimary,
                    size: AppSizes.headerActionIcon.sp,
                  ),
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: -2.w,
                    top: -2.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 5.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      constraints: BoxConstraints(minWidth: 16.w),
                      child: Text(
                        '$pendingCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.todayPillText,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
    final board = ref.watch(leaderboardBoardProvider);
    final entries = ref.watch(leaderboardProvider((scope: scope, board: board)));

    LeaderboardEntry? me;
    for (final e in entries.valueOrNull ?? const <LeaderboardEntry>[]) {
      if (e.isMe) {
        me = e;
        break;
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 24.h),
      children: [
        _CurrentLeagueCard(me: me, l10n: l10n),
        SizedBox(height: 18.h),
        _ScopeSelector(scope: scope, onChange: onScope, l10n: l10n),
        SizedBox(height: 10.h),
        _BoardSelector(board: board, l10n: l10n),
        _SeasonMetaRow(scope: scope, board: board, l10n: l10n),
        SizedBox(height: 12.h),
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
              for (var i = 0; i < list.length; i++)
                _Row(
                  rank: list[i].rank,
                  name: list[i].name,
                  volume: list[i].volume.round(),
                  tier: _tierForPosition(i + 1, list.length),
                  avatarUrl: list[i].avatarUrl,
                  isMe: list[i].isMe,
                ),
            ];
            return [
              for (var i = 0; i < rows.length; i++) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openProfile(context, ref, list[i]),
                  child: _LeaderboardRow(row: rows[i], l10n: l10n),
                ),
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

class _CurrentLeagueCard extends ConsumerWidget {
  const _CurrentLeagueCard({
    required this.me,
    required this.l10n,
  });

  /// The caller's own row on the current board, when loaded and present.
  final LeaderboardEntry? me;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    // Canonical rank: persisted + shield-resolved from the global board, so
    // the badge matches Home, holds through demotion shields, works offline,
    // and doesn't jump when switching scopes. Entry tier until first ranked.
    final state = ref.watch(rankStateProvider);
    final rank = ref.watch(myRankProvider) ?? const Rank(RankTier.bronze, 3);
    final composite = ref.watch(myCompositeProvider) ?? 0.0;
    final shielded = state?.shieldUntil != null;
    final next = rank.next;

    return Container(
      height: 194.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(36.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Right-side rank badge
          Positioned(
            right: 14.w,
            top: 0,
            bottom: 0,
            child: Center(child: RankBadge(rank, size: 140.w)),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        rank.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (shielded) ...[
                      SizedBox(width: 6.w),
                      Tooltip(
                        message: l10n.rankShieldTooltip,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(
                          Icons.shield_rounded,
                          size: 18.sp,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 10.h),
                // Progress through the current band toward the next rank.
                SizedBox(
                  width: 170.w,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: LinearProgressIndicator(
                      value:
                          next == null ? 1 : Rank.progressToNext(composite),
                      minHeight: 6.h,
                      backgroundColor:
                          colors.textSecondary.withValues(alpha: 0.18),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  next == null ? l10n.rankMax : l10n.rankNext(next.label(l10n)),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.sp,
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
                  NumberFormat.decimalPattern(
                    Localizations.localeOf(context).toString(),
                  ).format(row.volume),
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

// The Challenges tab lives in `challenges_tab.dart` (Phase 4).

// ─────────────────────────────────────────────
// B O A R D S   &   S E A S O N S  (Phase 5)
// ─────────────────────────────────────────────

/// Row tap → public profile. Self goes to the own-profile screen; others
/// resolve their @username (online) and open the existing bro-profile screen,
/// which already carries the add/block/report actions. Offline or
/// username-less rows no-op — never block on the network with a spinner.
Future<void> _openProfile(
  BuildContext context,
  WidgetRef ref,
  LeaderboardEntry entry,
) async {
  if (entry.isMe) {
    unawaited(context.push(AppRoutes.profile));
    return;
  }
  final uid = entry.userId;
  if (uid == null) return;
  final PublicProfile? profile;
  try {
    profile = await ref.read(friendRepositoryProvider).fetchPublicProfile(uid);
  } on Exception {
    return; // offline / transient — tap is a silent no-op
  }
  final username = profile?.username;
  if (username == null || username.isEmpty || !context.mounted) return;
  unawaited(context.push('/bro/$username'));
}

/// All-time / Weekly / Monthly pills — same chrome as the top-bar pills.
class _BoardSelector extends ConsumerWidget {
  const _BoardSelector({required this.board, required this.l10n});

  final LeaderboardBoard board;
  final AppLocalizations l10n;

  String _label(LeaderboardBoard b) => switch (b) {
        LeaderboardBoard.weekly => l10n.boardWeekly,
        LeaderboardBoard.monthly => l10n.boardMonthly,
        LeaderboardBoard.allTime => l10n.boardAllTime,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final b in LeaderboardBoard.values) ...[
          _TopPill(
            label: _label(b),
            active: board == b,
            onTap: () =>
                ref.read(leaderboardBoardProvider.notifier).state = b,
          ),
          if (b != LeaderboardBoard.values.last) SizedBox(width: 4.w),
        ],
      ],
    );
  }
}

/// Reset countdown + last-season winner, under the board pills. All-time has
/// neither (it never resets); the winner line appears once a season has
/// finalized (needs the deployed backend — hidden until data exists).
/// Rebuilds every minute so the countdown stays live across a boundary.
class _SeasonMetaRow extends ConsumerStatefulWidget {
  const _SeasonMetaRow({
    required this.scope,
    required this.board,
    required this.l10n,
  });

  final LeaderboardScope scope;
  final LeaderboardBoard board;
  final AppLocalizations l10n;

  @override
  ConsumerState<_SeasonMetaRow> createState() => _SeasonMetaRowState();
}

class _SeasonMetaRowState extends ConsumerState<_SeasonMetaRow> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final board = widget.board;
    final l10n = widget.l10n;
    final colors = AppColors.of(context);
    final next = nextResetUtc(board);
    if (next == null) return const SizedBox.shrink();

    final remaining = next.difference(DateTime.now().toUtc());
    // Ceil both units: Monday 00:01 reads "7d", not a misleading "6d".
    final time = remaining.inHours >= 48
        ? l10n.durationShortDays('${(remaining.inHours + 23) ~/ 24}')
        : l10n.durationShortHours(
            '${((remaining.inMinutes + 59) ~/ 60).clamp(1, 48)}');
    final winner =
        ref.watch(lastWinnerProvider((scope: scope, board: board))).valueOrNull;

    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined,
              color: colors.textSecondary, size: 13.sp),
          SizedBox(width: 4.w),
          Text(
            l10n.resetsIn(time),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (winner != null) ...[
            SizedBox(width: 12.w),
            Icon(Icons.emoji_events_outlined,
                color: colors.accent, size: 13.sp),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                l10n.lastWinnerLabel(winner.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
