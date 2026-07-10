import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

// ── Default base PNGs (already in assets/anatomy/) ──
const _defaultMale = 'assets/anatomy/male_black.png';
const _defaultFemale = 'assets/anatomy/Female Black.png';

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
  });

  final String id;

  /// Display name shown under the skin card (without gender prefix).
  final String name;

  final String? malePath;
  final String? femalePath;

  final SkinUnlock unlock;

  /// Finished workouts needed to earn a [SkinUnlock.progress] skin.
  final int? requiredSessions;

  /// Returns the asset path for the given gender, or `null` if unavailable.
  String? pathForGender({required bool isFemale}) =>
      isFemale ? femalePath : malePath;

  bool availableForGender({required bool isFemale}) =>
      pathForGender(isFemale: isFemale) != null;
}

/// All available skins.
///
/// Asset file names must match exactly what is in `assets/skins/`.
/// Add a new [Skin] here whenever a new image pair is dropped in.
const availableSkins = <Skin>[
  Skin(
    id: 'default',
    name: 'Default',
    malePath: _defaultMale,
    femalePath: _defaultFemale,
  ),
  Skin(
    id: 'carbone',
    name: 'Carbone',
    malePath: 'assets/skins/male carbone.png',
    femalePath: 'assets/skins/Female carbone.png',
  ),
  Skin(
    id: 'smoke',
    name: 'Smoke',
    malePath: 'assets/skins/male smoke.png',
    femalePath: 'assets/skins/Female smoke.png',
  ),
  Skin(
    id: 'white',
    name: 'White',
    malePath: 'assets/skins/male white.png',
    // no female white skin — femalePath intentionally omitted
  ),
  Skin(
    id: 'light',
    name: 'Light',
    // no male light skin — malePath intentionally omitted
    femalePath: 'assets/skins/Female Light.png',
  ),
  Skin(
    id: 'carbon',
    name: 'Carbon',
    malePath: 'assets/skins/male carbon.png',
    femalePath: 'assets/skins/Female carbon.png',
    unlock: SkinUnlock.progress,
    requiredSessions: 10,
  ),
  Skin(
    id: 'gold',
    name: 'Gold',
    malePath: 'assets/skins/male gold.png',
    femalePath: 'assets/skins/Female gold.png',
    unlock: SkinUnlock.paid,
  ),
  Skin(
    id: 'metal',
    name: 'Metal',
    malePath: 'assets/skins/male metal.png',
    femalePath: 'assets/skins/Female metal.png',
    unlock: SkinUnlock.progress,
    requiredSessions: 25,
  ),
  Skin(
    id: 'liquid',
    name: 'Liquid',
    malePath: 'assets/skins/male liquid.png',
    femalePath: 'assets/skins/Female liquid.png',
    unlock: SkinUnlock.progress,
    requiredSessions: 50,
  ),
  Skin(
    id: 'atack',
    name: 'Attack',
    malePath: 'assets/skins/male atack.png',
    femalePath: 'assets/skins/Female atack.png',
    unlock: SkinUnlock.progress,
    requiredSessions: 75,
  ),
  Skin(
    id: 'galaxy',
    name: 'Galaxy',
    // no male galaxy skin — malePath intentionally omitted
    femalePath: 'assets/skins/Female galaxy.png',
    unlock: SkinUnlock.paid,
  ),
  Skin(
    id: 'teddy_bear',
    name: 'Teddy Bear',
    // no male teddy bear skin — malePath intentionally omitted
    femalePath: 'assets/skins/Female Teddy Bear.png',
    unlock: SkinUnlock.paid,
  ),
  Skin(
    id: 'gren_guy',
    name: 'Green Guy',
    malePath: 'assets/skins/male gren guy.png',
    // no female green guy skin — femalePath intentionally omitted
    unlock: SkinUnlock.progress,
    requiredSessions: 120,
  ),
  Skin(
    id: 'volkano',
    name: 'Volcano',
    malePath: 'assets/skins/male volkano.png',
    // no female volcano skin — femalePath intentionally omitted
    unlock: SkinUnlock.progress,
    requiredSessions: 200,
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
/// finished-[sessions] count and the set of [owned] paid skin ids. Free skins
/// are always in; progress skins unlock once the session threshold is met;
/// paid skins only when owned. Extracted so it can be unit-tested without the
/// SecureStorage-backed [ownedSkinsProvider].
Set<String> computeUnlockedSkinIds({
  required int sessions,
  required Set<String> owned,
}) {
  return {
    for (final s in availableSkins)
      if (switch (s.unlock) {
        SkinUnlock.free => true,
        SkinUnlock.progress => sessions >= (s.requiredSessions ?? 0),
        SkinUnlock.paid => owned.contains(s.id),
      })
        s.id,
  };
}

/// Ids of every skin the user can select right now: free skins, progress
/// skins whose workout requirement is met (from local session history, so
/// it works offline), and purchased paid skins.
final unlockedSkinIdsProvider = Provider<Set<String>>((ref) {
  final sessions =
      ref.watch(lifetimeStatsProvider).valueOrNull?.sessionCount ?? 0;
  final owned = ref.watch(ownedSkinsProvider);
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
