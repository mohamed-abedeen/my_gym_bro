import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';

void main() {
  group('computeUnlockedSkinIds', () {
    // The five day-one free skins (no `unlock:` → SkinUnlock.free).
    const freeIds = {'default', 'carbone', 'smoke', 'white', 'light'};

    test('sessions=0, nothing owned → exactly the free skins', () {
      final ids = computeUnlockedSkinIds(sessions: 0, owned: const {});
      expect(ids, freeIds);
    });

    test('free skins are always present regardless of sessions/ownership', () {
      final ids = computeUnlockedSkinIds(sessions: 999, owned: const {'gold'});
      expect(ids, containsAll(freeIds));
    });

    test('a progress skin flips on at its session threshold', () {
      // 'carbon' requires 10 finished sessions.
      expect(
        computeUnlockedSkinIds(sessions: 9, owned: const {}),
        isNot(contains('carbon')),
      );
      expect(
        computeUnlockedSkinIds(sessions: 10, owned: const {}),
        contains('carbon'),
      );
    });

    test('higher-threshold progress skins stay locked below their bar', () {
      // 'metal' @25, 'liquid' @50 — crossing carbon's 10 must not unlock them.
      final ids = computeUnlockedSkinIds(sessions: 10, owned: const {});
      expect(ids, isNot(contains('metal')));
      expect(ids, isNot(contains('liquid')));
    });

    test('a paid skin appears only when its id is owned', () {
      // 'gold' is paid — never unlocked by progress, only by ownership.
      expect(
        computeUnlockedSkinIds(sessions: 999, owned: const {}),
        isNot(contains('gold')),
      );
      expect(
        computeUnlockedSkinIds(sessions: 0, owned: const {'gold'}),
        contains('gold'),
      );
    });

    test('owning an unrelated paid id does not unlock a different paid skin',
        () {
      // Owns 'gold' but not 'galaxy' → galaxy stays locked.
      final ids = computeUnlockedSkinIds(sessions: 0, owned: const {'gold'});
      expect(ids, contains('gold'));
      expect(ids, isNot(contains('galaxy')));
    });
  });
}
