import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/features/settings/skin_repository.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

// ── Default base PNGs (already in assets/anatomy/) ──
const _defaultMale = 'assets/anatomy/male_base.png';
const _defaultFemale = 'assets/anatomy/female_base.png';

/// How a skin is unlocked.
enum SkinUnlock {
  /// Available to everyone from day one.
  free,

  /// Earned by finishing [Skin.requiredSessions] workouts (local, offline).
  progress,

  /// One-time purchase. Ownership lands in [ownedSkinsProvider]; the
  /// RevenueCat `purchase-skin` flow will write into it when skin IAP
  /// products ship (Phase 6/8).
  paid,
}

/// A single skin option with explicit per-gender asset paths.
///
/// A `null` path means the skin doesn't exist for that gender and
/// will be hidden in the picker for that user.
class Skin {
  const Skin({
    required this.id,
    required this.name,
    this.malePath,
    this.femalePath,
    this.unlock = SkinUnlock.free,
    this.requiredSessions,
    this.productId,
  });

  final String id;

  /// Display name shown under the skin card (without gender prefix).
  final String name;

  final String? malePath;
  final String? femalePath;

  final SkinUnlock unlock;

  /// Finished workouts needed to earn a [SkinUnlock.progress] skin.
  final int? requiredSessions;

  /// RevenueCat one-time product id for [SkinUnlock.paid] skins. Must match
  /// the `skins.product_id` seeds in migration 016.
  final String? productId;

  /// Returns the asset path for the given gender, or `null` if unavailable.
  String? pathForGender({required bool isFemale}) =>
      isFemale ? femalePath : malePath;

  bool availableForGender({required bool isFemale}) =>
      pathForGender(isFemale: isFemale) != null;
}

/// All available skins (2026-08 art set — new pose, back-left/front-right).
///
/// Asset file names must match exactly what is in `assets/skins/`.
/// Add a new [Skin] here whenever a new image pair is dropped in.
///
/// TODO(skins): every skin is temporarily [SkinUnlock.free] so the whole set
/// can be reviewed in-app (2026-08-18). Restore the progress/paid tiers
/// (and keep the productIds below in sync with migration 016) before release.
const availableSkins = <Skin>[
  Skin(
    id: 'default',
    name: 'Default',
    malePath: _defaultMale,
    femalePath: _defaultFemale,
  ),
  Skin(
    id: 'carbon',
    name: 'Carbon',
    malePath: 'assets/skins/male_carbon.png',
    femalePath: 'assets/skins/female_carbon.png',
  ),
  Skin(
    id: 'chrome',
    name: 'Chrome',
    malePath: 'assets/skins/male_chrome.png',
    femalePath: 'assets/skins/female_chrome.png',
  ),
  Skin(
    id: 'crystal',
    name: 'Crystal',
    malePath: 'assets/skins/male_crystal.png',
    femalePath: 'assets/skins/female_crystal.png',
  ),
  Skin(
    id: 'galaxy',
    name: 'Galaxy',
    malePath: 'assets/skins/male_galaxy.png',
    femalePath: 'assets/skins/female_galaxy.png',
    productId: 'mgb_skin_galaxy',
  ),
  Skin(
    id: 'gold',
    name: 'Gold',
    malePath: 'assets/skins/male_gold.png',
    femalePath: 'assets/skins/female_gold.png',
    productId: 'mgb_skin_gold',
  ),
  Skin(
    id: 'liquid_metal',
    name: 'Liquid Metal',
    malePath: 'assets/skins/male_liquid_metal.png',
    femalePath: 'assets/skins/female_liquid_metal.png',
  ),
  Skin(
    id: 'oil',
    name: 'Oil',
    malePath: 'assets/skins/male_oil.png',
    femalePath: 'assets/skins/female_oil.png',
  ),
  Skin(
    id: 'rock',
    name: 'Rock',
    malePath: 'assets/skins/male_rock.png',
    // no female rock skin — femalePath intentionally omitted
  ),
  Skin(
    id: 'smoke',
    name: 'Smoke',
    malePath: 'assets/skins/male_smoke.png',
    femalePath: 'assets/skins/female_smoke.png',
  ),
  Skin(
    id: 'teddy_bear',
    name: 'Teddy Bear',
    // no male teddy bear skin — malePath intentionally omitted
    femalePath: 'assets/skins/female_teddy_bear.png',
    productId: 'mgb_skin_teddy_bear',
  ),
  Skin(
    id: 'white_marble',
    name: 'White Marble',
    malePath: 'assets/skins/male_white_marble.png',
    femalePath: 'assets/skins/female_white_marble.png',
  ),
];

/// Paid skin ids the user owns, persisted locally. Empty until the
/// RevenueCat one-time `purchase-skin` flow ships — that flow (and
/// restore purchases) will call [unlock] after a verified purchase.
class OwnedSkinsNotifier extends StateNotifier<Set<String>> {
  OwnedSkinsNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'setting_owned_skins';

  Future<void> _load() async {
    final raw = await SecureStorage().read(_key);
    if (raw != null && raw.isNotEmpty && mounted) {
      // Merge, don't overwrite — an unlock() may have landed while loading.
      state = {...state, ...raw.split(',')};
    }
  }

  Future<void> unlock(String id) async {
    state = {...state, id};
    await SecureStorage().write(_key, state.join(','));
  }
}

final ownedSkinsProvider =
    StateNotifierProvider<OwnedSkinsNotifier, Set<String>>(
  (ref) => OwnedSkinsNotifier(),
);

/// Pure gating logic: which [availableSkins] ids are unlocked given the user's
/// finished-[sessions] count and the set of [owned] skin ids (purchases and
/// server grants). Free skins are always in; progress skins unlock once the
/// session threshold is met — or when a server grant owns them, since
/// migration 016 seeds OR-alternative earn rules (challenges, season
/// placements) for the top tiers; paid skins only when owned. Extracted so it
/// can be unit-tested without the storage-backed providers.
Set<String> computeUnlockedSkinIds({
  required int sessions,
  required Set<String> owned,
  List<Skin> skins = availableSkins,
}) {
  return {
    for (final s in skins)
      if (switch (s.unlock) {
        SkinUnlock.free => true,
        SkinUnlock.progress =>
          sessions >= (s.requiredSessions ?? 0) || owned.contains(s.id),
        SkinUnlock.paid => owned.contains(s.id),
      })
        s.id,
  };
}

/// Ids of every skin the user can select right now: free skins, progress
/// skins whose workout requirement is met (from local session history, so
/// it works offline), and owned skins — the legacy SecureStorage set merged
/// with the server-granted ownership mirror (earned + purchased).
final unlockedSkinIdsProvider = Provider<Set<String>>((ref) {
  final sessions =
      ref.watch(lifetimeStatsProvider).valueOrNull?.sessionCount ?? 0;
  final owned = {
    ...ref.watch(ownedSkinsProvider),
    ...?ref.watch(serverOwnedSkinsProvider).valueOrNull,
  };
  return computeUnlockedSkinIds(sessions: sessions, owned: owned);
});

/// Currently selected skin id. Persisted via SecureStorage so the choice
/// survives app restarts (it used to silently reset to the default skin).
///
/// A previously selected skin that is now lock-gated stays selected
/// (grandfathered) — locks are enforced at selection time in the picker.
class SelectedSkinNotifier extends StateNotifier<String> {
  SelectedSkinNotifier() : super('default') {
    _load();
  }

  static const _key = 'setting_selected_skin';

  Future<void> _load() async {
    final raw = await SecureStorage().read(_key);
    if (raw != null && mounted && availableSkins.any((s) => s.id == raw)) {
      state = raw;
    }
  }

  Future<void> select(String id) async {
    state = id;
    await SecureStorage().write(_key, id);
  }
}

final selectedSkinProvider =
    StateNotifierProvider<SelectedSkinNotifier, String>(
  (ref) => SelectedSkinNotifier(),
);

/// Resolves to the correct base-PNG asset path for the active skin,
/// reacting to both [selectedSkinProvider] and [anatomyGenderProvider].
///
/// This is the single source of truth consumed by every [AnatomyBody].
/// Switching the anatomy-gender toggle instantly updates the body everywhere.
final activeSkinPathProvider = Provider<String>((ref) {
  final selectedId = ref.watch(selectedSkinProvider);
  final isFemale = ref.watch(anatomyGenderProvider) == AnatomyGender.female;

  final skin = availableSkins.firstWhere(
    (s) => s.id == selectedId,
    orElse: () => availableSkins.first,
  );

  // Fall back to the default body if the chosen skin has no asset for this gender.
  return skin.pathForGender(isFemale: isFemale) ??
      (isFemale ? _defaultFemale : _defaultMale);
});

// ── Skins economy (Phase 6.2) ──

final skinRepositoryProvider = Provider<SkinRepository>((ref) {
  return SkinRepository(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
    supabase: ref.watch(supabaseProvider),
  );
});

/// Server-granted skins (earned + purchased) from the offline mirror.
final serverOwnedSkinsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(skinRepositoryProvider).watchOwnedIds(),
);

/// Fire-and-forget ownership refresh — watched by the gallery so opening it
/// pulls fresh grants (new earned skins, purchases from another device).
final skinOwnershipRefreshProvider = FutureProvider.autoDispose<void>(
  (ref) => ref.watch(skinRepositoryProvider).refreshFromServer(),
);

/// Selects a skin everywhere: SecureStorage for the instant local render,
/// plus the synced profile column (cross-device, shows on the public
/// profile). Lock-gating stays at the call site (the gallery).
Future<void> selectSkin(WidgetRef ref, String id) async {
  await ref.read(selectedSkinProvider.notifier).select(id);
  await ref.read(skinRepositoryProvider).persistActiveSkin(id);
}

/// Maps store product ids from a purchase/restore receipt back to skin ids —
/// the instant local unlock when server verification is offline.
Set<String> skinIdsForProducts(Set<String> productIds) => {
      for (final s in availableSkins)
        if (s.productId != null && productIds.contains(s.productId)) s.id,
    };
