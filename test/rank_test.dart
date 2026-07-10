import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';

void main() {
  test('composite percentile maps onto 15 tier/level bands', () {
    // Bottom of the board → entry bronze.
    expect(Rank.fromComposite(0).tier, RankTier.bronze);
    expect(Rank.fromComposite(0).level, 3);
    // Top of a tier before the next one starts.
    expect(Rank.fromComposite(19.9).tier, RankTier.bronze);
    expect(Rank.fromComposite(19.9).level, 1);
    expect(Rank.fromComposite(20).tier, RankTier.silver);
    expect(Rank.fromComposite(20).level, 3);
    // Mid-board.
    expect(Rank.fromComposite(50).tier, RankTier.gold);
    // Top of the board → Elite I, and 100 doesn't overflow the band table.
    expect(Rank.fromComposite(99).tier, RankTier.elite);
    expect(Rank.fromComposite(100).tier, RankTier.elite);
    expect(Rank.fromComposite(100).level, 1);
    expect(Rank.fromComposite(100).numeral, 'I');
  });

  test('band round-trips through fromBand and orders the ladder', () {
    for (var b = 0; b < 15; b++) {
      expect(Rank.fromBand(b).band, b);
    }
    // Higher band == higher rank — the comparison rank-up detection uses.
    expect(
      Rank.fromBand(4).band, // Warrior II
      greaterThan(const Rank(RankTier.bronze, 1).band), // Grinder I
    );
    // Out-of-range persisted values clamp instead of throwing.
    expect(Rank.fromBand(-1).band, 0);
    expect(Rank.fromBand(99).band, 14);
  });

  test('progressToNext measures position within the current band', () {
    expect(Rank.progressToNext(0), 0);
    // Composite 10 = 1.5 bands in → halfway through the second band.
    expect(Rank.progressToNext(10), closeTo(0.5, 1e-9));
    // Top of the ladder pegs full instead of wrapping to 0.
    expect(Rank.progressToNext(100), 1);
  });

  test('next walks up the ladder and stops at the top', () {
    expect(const Rank(RankTier.bronze, 3).next!.band, 1);
    expect(const Rank(RankTier.elite, 1).next, isNull);
  });

  group('resolveRank (demotion shield)', () {
    final now = DateTime(2026, 7, 8);

    test('first placement persists without celebrating', () {
      final r = resolveRank(null, 42, now);
      expect(r.state, const RankState(42));
      expect(r.rankedUp, false);
    });

    test('promotion applies immediately and celebrates', () {
      final r = resolveRank(const RankState(10), 25, now);
      expect(r.state, const RankState(25));
      expect(r.rankedUp, true);
    });

    test('same-band refresh moves the composite silently', () {
      final r = resolveRank(const RankState(21), 24, now);
      expect(r.state, const RankState(24));
      expect(r.rankedUp, false);
    });

    test('a drop arms a shield that holds the stored rank', () {
      final r = resolveRank(const RankState(50), 10, now);
      expect(r.state.composite, 50);
      expect(r.state.shieldUntil, now.add(rankShieldGrace));
      expect(r.rankedUp, false);
    });

    test('an armed shield keeps holding until the grace ends', () {
      final shielded =
          RankState(50, shieldUntil: now.add(const Duration(days: 2)));
      final r = resolveRank(shielded, 10, now);
      expect(r.state, shielded);
      expect(r.rankedUp, false);
    });

    test('still below when the shield expires → demotion lands', () {
      final shielded =
          RankState(50, shieldUntil: now.subtract(const Duration(minutes: 1)));
      final r = resolveRank(shielded, 10, now);
      expect(r.state, const RankState(10));
    });

    test('climbing back to the held band clears the shield', () {
      final shielded =
          RankState(50, shieldUntil: now.add(const Duration(days: 2)));
      final r = resolveRank(shielded, 48, now); // both band 7
      expect(r.state, const RankState(48));
      expect(r.rankedUp, false);
    });

    test('overshooting the held band celebrates and clears the shield', () {
      final shielded =
          RankState(50, shieldUntil: now.add(const Duration(days: 2)));
      final r = resolveRank(shielded, 70, now);
      expect(r.state, const RankState(70));
      expect(r.rankedUp, true);
    });
  });
}
