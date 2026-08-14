import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Ranks template — the session's best-ranked classic lift as a hero badge
/// with its Bronze→Elite standing, plus a compact row per other ranked lift.
/// Only offered when [ShareCardData.liftRanks] is non-empty.
class LiftRankShareCard extends ConsumerWidget {
  const LiftRankShareCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);
    final hero = data.liftRanks.first;
    final heroRank = Rank.fromBand(hero.band);
    final rest = data.liftRanks.skip(1).toList();
    final glow = rankColors(heroRank.tier).gradient[1];

    return ShareCardFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 32, 30, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShareMasthead(data: data, dateFallback: true),
            const Spacer(),
            Text(
              l10n.shareRanksTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: shareMono(11, letterSpacing: 2.5),
            ),
            const SizedBox(height: 22),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.45),
                      blurRadius: 70,
                      spreadRadius: 12,
                    ),
                  ],
                ),
                child: RankBadge(heroRank, size: 150),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hero.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: shareArchivo(
                28,
                weight: 800,
                width: 108,
                letterSpacing: -0.6,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              heroRank.label(l10n).toUpperCase(),
              textAlign: TextAlign.center,
              style: shareMono(12, letterSpacing: 2, color: kShareAccent),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatShareVolume(hero.e1RmKg, unit)} · ${l10n.oneRepMax}'
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: shareMono(10, color: kShareTextTertiary),
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 26),
              const DecoratedBox(
                decoration: BoxDecoration(color: kShareHairline),
                child: SizedBox(height: 1),
              ),
              for (final lift in rest) ...[
                const SizedBox(height: 14),
                _LiftRankRow(lift: lift, unit: unit),
              ],
            ],
            const Spacer(),
            const ShareFooter(),
          ],
        ),
      ),
    );
  }
}

class _LiftRankRow extends StatelessWidget {
  const _LiftRankRow({required this.lift, required this.unit});

  final ShareLiftRank lift;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rank = Rank.fromBand(lift.band);
    return Row(
      children: [
        RankBadge(rank, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            lift.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: shareArchivo(15, weight: 700, letterSpacing: -0.2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          rank.label(l10n).toUpperCase(),
          style: shareMono(9, color: kShareAccent),
        ),
        const SizedBox(width: 10),
        Text(
          formatShareVolume(lift.e1RmKg, unit).toUpperCase(),
          style: shareMono(9, color: kShareTextTertiary),
        ),
      ],
    );
  }
}
