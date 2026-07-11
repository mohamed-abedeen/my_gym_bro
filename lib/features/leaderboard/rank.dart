import 'package:flutter/material.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Rank tiers, lowest → highest. Derived purely from the server-computed
/// leaderboard `composite` (a 0–100 percentile), so no backend change is
/// needed and offline users simply have no rank yet.
enum RankTier { bronze, silver, gold, platinum, elite }

/// A user's rank: tier + level within the tier (III = entry, I = top),
/// matching the badge artwork convention (e.g. the bronze "III" emblem).
class Rank {
  const Rank(this.tier, this.level);

  /// Maps the 0–100 composite percentile onto 15 bands
  /// (5 tiers × 3 levels; each tier spans 20 points).
  factory Rank.fromComposite(double composite) =>
      Rank.fromBand((composite / 100 * 15).floor());

  /// Band 0 (entry tier, III) … 14 (top tier, I); input is clamped.
  factory Rank.fromBand(int band) {
    final b = band.clamp(0, 14);
    return Rank(RankTier.values[b ~/ 3], 3 - (b % 3));
  }

  final RankTier tier;

  /// 3, 2 or 1 — shown as III / II / I.
  final int level;

  /// Position on the 15-band ladder (0 = entry, 14 = top). Used to compare
  /// ranks for rank-up detection and to persist the last-seen rank.
  int get band => tier.index * 3 + (3 - level);

  /// The next rank up the ladder, or null at the top.
  Rank? get next => band >= 14 ? null : Rank.fromBand(band + 1);

  /// 0–1 progress through the current band toward the next one.
  static double progressToNext(double composite) {
    final t = (composite / 100 * 15).clamp(0.0, 15.0);
    final band = t.floor().clamp(0, 14);
    return (t - band).clamp(0.0, 1.0);
  }

  /// Badge artwork convention: drop PNGs into `assets/badges/` named
  /// `<tier>_<level>.png` (bronze_3.png … elite_1.png, 15 total) and
  /// [RankBadge] picks them up automatically; until then it renders a
  /// styled fallback medal.
  String get assetPath => 'assets/badges/${tier.name}_$level.png';

  String get numeral => switch (level) { 1 => 'I', 2 => 'II', _ => 'III' };

  String tierLabel(AppLocalizations l10n) => switch (tier) {
        RankTier.bronze => l10n.rankBronze,
        RankTier.silver => l10n.rankSilver,
        RankTier.gold => l10n.rankGold,
        RankTier.platinum => l10n.rankPlatinum,
        RankTier.elite => l10n.rankElite,
      };

  /// "Bronze III", "Elite I", …
  String label(AppLocalizations l10n) => '${tierLabel(l10n)} $numeral';
}

/// Persisted rank state: the composite the displayed badge derives from,
/// plus the demotion-shield deadline while one is armed.
@immutable
class RankState {
  const RankState(this.composite, {this.shieldUntil});

  final double composite;

  /// While set, a drop below [composite]'s band is being absorbed — the
  /// displayed rank holds until this deadline passes.
  final DateTime? shieldUntil;

  int get band => Rank.fromComposite(composite).band;

  @override
  bool operator ==(Object other) =>
      other is RankState &&
      other.composite == composite &&
      other.shieldUntil == shieldUntil;

  @override
  int get hashCode => Object.hash(composite, shieldUntil);
}

/// How long a demotion shield holds the displayed rank after a drop.
const rankShieldGrace = Duration(days: 7);

/// Folds a fresh live [composite] into the persisted [stored] state.
///
/// Promotions apply immediately (and report `rankedUp` for the celebration).
/// Same-band updates just refresh the composite so the progress bar moves.
/// Drops arm a shield on first sight: the stored (higher) rank keeps being
/// displayed for [rankShieldGrace]; only if the user is still below it when
/// the shield expires does the demotion land. Climbing back clears the shield.
({RankState state, bool rankedUp}) resolveRank(
  RankState? stored,
  double composite,
  DateTime now,
) {
  final live = RankState(composite);
  if (stored == null) return (state: live, rankedUp: false);
  if (live.band > stored.band) return (state: live, rankedUp: true);
  if (live.band == stored.band) return (state: live, rankedUp: false);
  final until = stored.shieldUntil ?? now.add(rankShieldGrace);
  if (now.isBefore(until)) {
    return (
      state: RankState(stored.composite, shieldUntil: until),
      rankedUp: false,
    );
  }
  return (state: live, rankedUp: false);
}

/// Per-tier medal colours (top→bottom gradient + a readable foreground).
/// Bronze/silver/gold reuse the leaderboard row medal palette.
({List<Color> gradient, Color foreground}) rankColors(RankTier t) =>
    switch (t) {
      RankTier.bronze => (
          gradient: const [
            Color(0xFFFFD2AB),
            Color(0xFF9F6943),
            Color(0xFF332217)
          ],
          foreground: const Color(0xFF2C1911),
        ),
      RankTier.silver => (
          gradient: const [
            Color(0xFFE2E2E2),
            Color(0xFF969696),
            Color(0xFF303030)
          ],
          foreground: const Color(0xFF1F1F1F),
        ),
      RankTier.gold => (
          gradient: const [
            Color(0xFFFFD67D),
            Color(0xFFC68F18),
            Color(0xFF674907)
          ],
          foreground: const Color(0xFF412C00),
        ),
      RankTier.platinum => (
          gradient: const [
            Color(0xFFE8F6FF),
            Color(0xFF8FB7CE),
            Color(0xFF2B4A5A)
          ],
          foreground: const Color(0xFF16303D),
        ),
      RankTier.elite => (
          gradient: const [
            Color(0xFFF6FFB4),
            Color(0xFFB9D500),
            Color(0xFF3A4500)
          ],
          foreground: const Color(0xFF2A3200),
        ),
    };

/// The rank badge. Renders the tier artwork from `assets/badges/` when the
/// PNG exists; otherwise a gradient fallback medal with the tier numeral,
/// so screens can ship before the final art is dropped in.
class RankBadge extends StatelessWidget {
  const RankBadge(this.rank, {super.key, this.size = 96});

  final Rank rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      rank.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackBadge(rank: rank, size: size),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.rank, required this.size});

  final Rank rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = rankColors(rank.tier);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.476, 1],
          colors: c.gradient,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: size * 0.02,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: size * 0.28,
            color: c.foreground,
          ),
          SizedBox(height: size * 0.02),
          Text(
            rank.numeral,
            style: TextStyle(
              color: c.foreground,
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
