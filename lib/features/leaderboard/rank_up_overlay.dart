import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Full-screen rank-up celebration: dark barrier, badge popping in with an
/// elastic scale + tier-colored glow, the new rank name, and a dismiss CTA.
Future<void> showRankUp(BuildContext context, Rank rank) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'rank up',
    barrierColor: Colors.black.withValues(alpha: 0.82),
    transitionDuration: const Duration(milliseconds: 700),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: child,
      ),
    ),
    pageBuilder: (context, _, __) => _RankUpPage(rank: rank),
  );
}

class _RankUpPage extends StatelessWidget {
  const _RankUpPage({required this.rank});

  final Rank rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final glow = rankColors(rank.tier).gradient[1];

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.55),
                    blurRadius: 90,
                    spreadRadius: 24,
                  ),
                ],
              ),
              child: RankBadge(rank, size: 224.w),
            ),
            SizedBox(height: 28.h),
            Text(
              l10n.rankUpTitle,
              style: TextStyle(
                color: colors.accent,
                fontSize: 30.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              rank.label(l10n),
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 32.h),
            LiquidGlassButton(
              width: 180.w,
              height: 52.h,
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                l10n.rankUpCta,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
