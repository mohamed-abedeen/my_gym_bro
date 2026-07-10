import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';

/// A page of exercises for the browser, plus whether it was served from the
/// local cache (offline / rate-limited) rather than fresh-enough data.
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

/// Coordinates the ExerciseDB OSS API with the local Drift cache.
///
/// Strategy — the catalogue is small (~1,500 rows) and static, so instead of
/// proxying every browse/search to the network, the repository **syncs the
/// catalogue into Drift once** (cursor-paged, incrementally, as far as each
/// call needs) and serves every read from the local DB. This keeps the app
/// fully offline after one complete sync and sidesteps the API's aggressive
/// rate limiting: a 429/offline error just pauses the sync, reads degrade to
/// whatever is cached, and the next call resumes from the saved cursor.
///
///   • **browse** syncs at least `offset + limit` rows, then reads a page
///     from the DB (ordered by name).
///   • **search** tries to finish the sync, then does a local `LIKE` search.
///   • **getById / ensureCached** are local-first with a network backfill for
///     unknown ids (scheduled/logged exercises).
class ExerciseRepository {
  ExerciseRepository(this._api, this._dao);

  final ExerciseApiService _api;
  final ExerciseDao _dao;

  // ── catalogue sync state (per app session) ───────────────────────────
  bool _syncDone = false;
  String? _nextCursor;
  bool _syncStarted = false;
  int? _serverTotal;

  /// Gap between page fetches while syncing. The API 429s after ~a dozen
  /// rapid requests; per-call bursts are small (a few pages), so this only
  /// matters for the full sync a search triggers.
  // ponytail: fixed 400ms pacing — a long first-search sync can still 429
  // midway and serve partial results until later calls resume it. Bump the
  // delay (or prefetch the catalogue at startup) if that bites in testing.
  static const Duration _pageDelay = Duration(milliseconds: 400);

  /// The API needs no key — network features are always possible.
  bool get isOnlineCapable => true;

  /// Browse the catalogue, paginated, served from the local DB after an
  /// incremental sync.
  Future<ExercisePage> browse({int offset = 0, int limit = 50}) async {
    final fresh = await _syncUpTo(offset + limit);
    final rows = await _dao.getPaged(limit: limit, offset: offset);
    final total = await _dao.count();
    return ExercisePage(total: total, items: rows, fromCache: !fresh);
  }

  /// Search by name against the local catalogue (syncing it first when
  /// possible, so results are complete once the sync has finished).
  Future<ExercisePage> searchByName(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return browse(limit: limit);
    await _syncUpTo(1 << 30);
    final rows = await _dao.searchByName(q);
    return ExercisePage(
        total: rows.length, items: rows, fromCache: !_syncDone);
  }

  /// Local-first lookup by exercise id. Caches a network result before
  /// returning. Returns null if unknown and unreachable.
  Future<Exercise?> getById(String id) async {
    final local = await _dao.findByExerciseId(id);
    if (local != null) return local;
    try {
      final dto = await _api.getById(id);
      if (dto == null) return null;
      await _dao.cacheOne(dto.toCompanion());
      return _dao.findByExerciseId(id);
    } on ExerciseApiException {
      return null;
    }
  }

  /// Best-effort backfill: fetch and cache any [ids] not already cached.
  /// Silently skips ids that can't be fetched (offline / 404), so the
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
        if (dto != null) await _dao.cacheOne(dto.toCompanion());
      } on ExerciseApiException {
        // best effort — leave uncached
      }
    }
  }

  /// Pulls catalogue pages (resuming from the session cursor) until the
  /// local catalogue holds at least [target] rows, the server is exhausted,
  /// or the API errors (offline / rate limit). Returns true when the local
  /// data satisfies [target] — false means "serving a possibly-stale cache".
  Future<bool> _syncUpTo(int target) async {
    if (_syncDone) return true;
    try {
      var count = await _dao.countCatalogue();
      while (true) {
        if (_serverTotal != null && count >= _serverTotal!) {
          _syncDone = true;
          return true;
        }
        if (_syncStarted && _nextCursor == null) {
          // Walked every page this session.
          _syncDone = true;
          return true;
        }
        if (_serverTotal != null && count >= target) return true;
        if (_syncStarted) await Future<void>.delayed(_pageDelay);
        final page = await _api.browsePage(after: _nextCursor);
        _syncStarted = true;
        _serverTotal = page.total;
        _nextCursor = page.nextCursor;
        if (page.items.isEmpty && !page.hasNextPage) {
          _syncDone = true;
          return true;
        }
        await _dao.cacheAll(page.items.map((e) => e.toCompanion()).toList());
        count = await _dao.countCatalogue();
      }
    } on ExerciseApiException {
      return false; // degrade to cache; a later call resumes from _nextCursor
    }
  }
}
