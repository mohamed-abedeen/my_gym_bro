import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';
import 'package:my_gym_bro/core/services/workoutx_exercise.dart';

/// A page of exercises for the browser, plus whether it was served from the
/// local cache (offline / plan-gated / rate-limited) rather than the network.
class ExercisePage {
  const ExercisePage({
    required this.total,
    required this.items,
    required this.fromCache,
  });
  final int total;
  final List<Exercise> items;
  final bool fromCache;
}

/// Coordinates the WorkoutX API with the local Drift cache.
///
/// Strategy:
///   • **browse / search** hit the network first, then cache every row so the
///     app keeps working offline afterwards. On any [WorkoutXException]
///     (offline, rate-limited, or free-plan search gating) they degrade to the
///     local cache instead of surfacing an error.
///   • **getById** is local-first: it returns the cached row immediately and
///     only calls the network when the id is unknown locally.
///   • **ensureCached** backfills missing rows for ids that the app already
///     references (scheduled/logged exercises) so history enrichment and
///     muscle-recovery lookups always resolve.
class ExerciseRepository {
  ExerciseRepository(this._api, this._dao);

  final ExerciseApiService _api;
  final ExerciseDao _dao;

  /// Set once the API reports that search requires a higher plan, so we stop
  /// spending quota on calls that will always 402 in this session.
  bool _searchPlanGated = false;

  /// True when an API key is configured (network features are possible).
  bool get isOnlineCapable => _api.hasKey;

  /// Key used to make cached WorkoutX `gifUrl`s self-authenticating.
  String get mediaApiKey => _api.apiKey;

  /// True when server-side search is known to be plan-gated (free tier).
  bool get isSearchPlanGated => _searchPlanGated;

  /// Browse the catalogue, paginated. Caches results; falls back to cache.
  Future<ExercisePage> browse({int offset = 0, int limit = 50}) async {
    try {
      final page = await _api.browse(offset: offset, limit: limit);
      final rows = await _cacheAndRead(page.items);
      return ExercisePage(total: page.total, items: rows, fromCache: false);
    } on WorkoutXException {
      final rows = await _dao.getPaged(limit: limit, offset: offset);
      final total = await _dao.count();
      return ExercisePage(total: total, items: rows, fromCache: true);
    }
  }

  /// Search by name. Uses the (paid) search endpoint and degrades to a local
  /// `LIKE` search over the cache when it is gated/offline/rate-limited.
  Future<ExercisePage> searchByName(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return browse(limit: limit);

    // Skip the network entirely once we know search is plan-gated.
    if (_searchPlanGated || !_api.hasKey) {
      return _cacheSearch(q);
    }

    try {
      final page = await _api.searchByName(q, limit: limit);
      final rows = await _cacheAndRead(page.items);
      return ExercisePage(total: page.total, items: rows, fromCache: false);
    } on WorkoutXPlanException {
      _searchPlanGated = true;
      return _cacheSearch(q);
    } on WorkoutXException {
      return _cacheSearch(q);
    }
  }

  Future<ExercisePage> _cacheSearch(String query) async {
    final rows = await _dao.searchByName(query);
    return ExercisePage(total: rows.length, items: rows, fromCache: true);
  }

  /// Local-first lookup by WorkoutX id. Caches a network result before
  /// returning. Returns null if unknown and unreachable.
  Future<Exercise?> getById(String id) async {
    final local = await _dao.findByExerciseId(id);
    if (local != null) return local;
    try {
      final dto = await _api.getById(id);
      if (dto == null) return null;
      await _dao.cacheOne(dto.toCompanion(apiKey: _api.apiKey));
      return _dao.findByExerciseId(id);
    } on WorkoutXException {
      return null;
    }
  }

  /// Best-effort backfill: fetch and cache any [ids] not already cached.
  /// Silently skips ids that can't be fetched (offline / plan / 404), so the
  /// caller's flow is never blocked.
  Future<void> ensureCached(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return;
    final existing = await _dao.findByExerciseIds(unique);
    final have = existing.map((e) => e.exerciseId).toSet();
    final missing = unique.where((id) => !have.contains(id)).toList();
    for (final id in missing) {
      try {
        final dto = await _api.getById(id);
        if (dto != null) await _dao.cacheOne(dto.toCompanion(apiKey: _api.apiKey));
      } on WorkoutXException {
        // best effort — leave uncached
      }
    }
  }

  Future<List<Exercise>> _cacheAndRead(List<WorkoutXExercise> items) async {
    if (items.isEmpty) return const [];
    await _dao
        .cacheAll(items.map((e) => e.toCompanion(apiKey: _api.apiKey)).toList());
    final ids = items.map((e) => e.id).toList();
    final rows = await _dao.findByExerciseIds(ids);
    final byId = {for (final r in rows) r.exerciseId: r};
    // Preserve the order the API returned.
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }
}
