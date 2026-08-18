import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';

/// Gating-logic scenarios run against a fixture catalog so they keep testing
/// [computeUnlockedSkinIds] while the LIVE catalog is temporarily all-free
/// for the 2026-08 art review (see the TODO on `availableSkins`).
const _fixture = <Skin>[
  Skin(id: 'default', name: 'Default', malePath: 'm'),
  Skin(id: 'basic', name: 'Basic', malePath: 'm'),
  Skin(
    id: 'bronze',
    name: 'Bronze',
    malePath: 'm',
    unlock: SkinUnlock.progress,
    requiredSessions: 10,
  ),
  Skin(
    id: 'silver',
    name: 'Silver',
    malePath: 'm',
    unlock: SkinUnlock.progress,
    requiredSessions: 25,
  ),
  Skin(
    id: 'earned',
    name: 'Earned',
    malePath: 'm',
    unlock: SkinUnlock.progress,
    requiredSessions: 200,
  ),
  Skin(
    id: 'gold',
    name: 'Gold',
    malePath: 'm',
    unlock: SkinUnlock.paid,
    productId: 'mgb_skin_gold',
  ),
  Skin(
    id: 'galaxy',
    name: 'Galaxy',
    malePath: 'm',
    unlock: SkinUnlock.paid,
    productId: 'mgb_skin_galaxy',
  ),
];

Set<String> unlocked({int sessions = 0, Set<String> owned = const {}}) =>
    computeUnlockedSkinIds(sessions: sessions, owned: owned, skins: _fixture);

void main() {
  group('computeUnlockedSkinIds', () {
    const freeIds = {'default', 'basic'};

    test('sessions=0, nothing owned → exactly the free skins', () {
      expect(unlocked(), freeIds);
    });

    test('free skins are always present regardless of sessions/ownership', () {
      expect(
        unlocked(sessions: 999, owned: const {'gold'}),
        containsAll(freeIds),
      );
    });

    test('a progress skin flips on at its session threshold', () {
      expect(unlocked(sessions: 9), isNot(contains('bronze')));
      expect(unlocked(sessions: 10), contains('bronze'));
    });

    test('higher-threshold progress skins stay locked below their bar', () {
      final ids = unlocked(sessions: 10);
      expect(ids, isNot(contains('silver')));
      expect(ids, isNot(contains('earned')));
    });

    test('a paid skin appears only when its id is owned', () {
      expect(unlocked(sessions: 999), isNot(contains('gold')));
      expect(unlocked(owned: const {'gold'}), contains('gold'));
    });

    test('owning an unrelated paid id does not unlock a different paid skin',
        () {
      final ids = unlocked(owned: const {'gold'});
      expect(ids, contains('gold'));
      expect(ids, isNot(contains('galaxy')));
    });

    test('a server grant unlocks a progress skin below its session bar', () {
      // Migration 016 seeds OR-alternative earn rules (e.g. 200 sessions OR
      // a weekly season win) — the grant arrives as ownership.
      final ids = unlocked(owned: const {'earned'});
      expect(ids, contains('earned'));
      // The grant is per-skin: other progress skins stay session-gated.
      expect(ids, isNot(contains('bronze')));
    });
  });

  group('live catalog (2026-08 art review)', () {
    // TEMPORARY state pin: every shipped skin is SkinUnlock.free so the whole
    // new-art set is browsable in-app. Replace this test with real tier
    // expectations when gating is restored (TODO on `availableSkins`).
    test('every catalog skin is currently unlocked at zero sessions', () {
      expect(
        computeUnlockedSkinIds(sessions: 0, owned: const {}),
        {for (final s in availableSkins) s.id},
      );
    });
  });
}
