import 'dart:async';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
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

/// Where the catalogue sync remembers how far it got, so the next app launch
/// resumes instead of re-walking pages it already cached.
abstract class CatalogueSyncCheckpoint {
  /// The saved resume point, or null when there is none.
  Future<({String cursor, int cachedCount})?> read();

  /// Save [cursor] (the `after` value for the next page) together with how
  /// many catalogue rows were cached when it was saved.
  Future<void> write(String cursor, int cachedCount);

  /// Forget the resume point (the walk reached the last page).
  Future<void> clear();
}

/// [CatalogueSyncCheckpoint] in the platform key store.
///
/// The iOS Keychain outlives a reinstall while the database does not, so the
/// saved row count is checked against the database before the cursor is
/// trusted: a fresh database holds fewer rows and the walk restarts from
/// page 1.
class SecureStorageCatalogueCheckpoint implements CatalogueSyncCheckpoint {
  const SecureStorageCatalogueCheckpoint();

  static const _key = 'exercise_catalogue_sync_checkpoint';

  @override
  Future<({String cursor, int cachedCount})?> read() async {
    try {
      final raw = await SecureStorage().read(_key);
      if (raw == null) return null;
      final sep = raw.indexOf('|');
      if (sep <= 0) return null;
      final count = int.tryParse(raw.substring(0, sep));
      final cursor = raw.substring(sep + 1);
      if (count == null || cursor.isEmpty) return null;
      return (cursor: cursor, cachedCount: count);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String cursor, int cachedCount) async {
    try {
      await SecureStorage().write(_key, '$cachedCount|$cursor');
    } on Object {
      // Best effort: without it the next launch re-walks from page 1.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await SecureStorage().delete(_key);
    } on Object {
      // Best effort.
    }
  }
}

/// Coordinates the ExerciseDB OSS API with the local Drift cache.
///
/// Strategy: the catalogue is small (~1,500 rows) and static, so instead of
/// proxying every browse/search to the network, the repository **syncs the
/// catalogue into Drift** (cursor-paged, 25 rows a request) and serves every
/// read from the local DB. The app is fully offline after one complete sync.
///
///   • **warmUp** walks the whole catalogue in the background. The API 429s
///     after about a dozen quick requests, so on a 429 it waits (the server's
///     `Retry-After`, else an increasing backoff) and carries on instead of
///     giving up. Progress is checkpointed after every page
///     ([CatalogueSyncCheckpoint]), so a killed app resumes where it stopped
///     on the next launch. Before this, the cursor lived only in memory:
///     every launch restarted at page 1, hit the same 429 around page 12,
///     and the catalogue never got past ~300 rows.
///   • **browse** syncs at least `offset + limit` rows, then reads a page
///     from the DB (ordered by name).
///   • **search** is local and immediate. It never waits on the network (it
///     used to block until the whole catalogue had synced); callers re-run
///     it when [whenSynced] completes to pick up rows that arrived since.
///   • **getById / ensureCached** are local-first with a network backfill for
///     unknown ids (scheduled/logged exercises).
class ExerciseRepository {
  ExerciseRepository(
    this._api,
    this._dao, {
    CatalogueSyncCheckpoint checkpoint =
        const SecureStorageCatalogueCheckpoint(),
    Duration rateLimitBackoff = const Duration(seconds: 20),
    Duration pageDelay = const Duration(milliseconds: 400),
  })  : _checkpoint = checkpoint,
        _rateLimitBackoff = rateLimitBackoff,
        _pageDelay = pageDelay;

  final ExerciseApiService _api;
  final ExerciseDao _dao;
  final CatalogueSyncCheckpoint _checkpoint;

  // ── catalogue sync state (per app session) ───────────────────────────
  bool _syncDone = false;
  String? _nextCursor;
  bool _syncStarted = false;
  int? _serverTotal;
  Future<void>? _pageInFlight;
  Future<void>? _warmUpInFlight;
  final Completer<void> _synced = Completer<void>();

  /// The error that stopped the most recent sync attempt; cleared by the
  /// next page that succeeds. Non-null means reads are degraded to whatever
  /// is cached (offline / rate-limited).
  ExerciseApiException? _lastError;

  /// Gap between page fetches while syncing.
  final Duration _pageDelay;

  /// First wait after a 429 when the server sends no `Retry-After`; doubles
  /// on each consecutive 429 up to [_maxRateLimitBackoff].
  final Duration _rateLimitBackoff;
  static const Duration _maxRateLimitBackoff = Duration(minutes: 2);

  /// Consecutive 429s the background walk sits out before stopping for this
  /// launch (the checkpoint resumes it next time).
  static const int _maxRateLimitWaits = 12;

  /// The API needs no key — network features are always possible.
  bool get isOnlineCapable => true;

  /// Completes once the whole catalogue is in the local DB this session.
  Future<void> get whenSynced => _synced.future;

  /// Background full-catalogue sync — call once at startup. Rides out rate
  /// limiting; stops when offline. Concurrent calls share one walk. Once the
  /// catalogue is complete, a later launch confirms it with one request.
  Future<void> warmUp() {
    final running = _warmUpInFlight;
    if (running != null) return running;
    final run = _runWarmUp().whenComplete(() => _warmUpInFlight = null);
    _warmUpInFlight = run;
    return run;
  }

  Future<void> _runWarmUp() async {
    var backoff = _rateLimitBackoff;
    for (var waits = 0;; waits++) {
      if (await _syncUpTo(1 << 30)) return;
      final error = _lastError;
      // Offline or a server error: stop. The next launch (or a browse)
      // resumes from the checkpoint.
      if (error == null || !error.rateLimited) return;
      if (waits >= _maxRateLimitWaits) return;
      await Future<void>.delayed(error.retryAfter ?? backoff);
      final doubled = backoff * 2;
      backoff =
          doubled > _maxRateLimitBackoff ? _maxRateLimitBackoff : doubled;
    }
  }

  /// Browse the catalogue, paginated. Served straight from the local DB when
  /// it already holds the requested page (rows are static, so cached pages
  /// are never stale); only a cold cache waits on the sync.
  Future<ExercisePage> browse({int offset = 0, int limit = 50}) async {
    var fresh = _syncDone || await _dao.countCatalogue() >= offset + limit;
    if (!fresh) fresh = await _syncUpTo(offset + limit);
    final rows = await _dao.getPaged(limit: limit, offset: offset);
    final total = await _dao.count();
    return ExercisePage(total: total, items: rows, fromCache: !fresh);
  }

  /// Search by name against the local catalogue. Never waits on the network:
  /// while the background sync is still running the results cover what has
  /// arrived so far — re-run on [whenSynced] for the complete set.
  /// [ExercisePage.fromCache] is true only when the sync is stuck (offline /
  /// rate-limited), not merely still running. Unpaginated.
  Future<ExercisePage> searchByName(String query) async {
    final q = query.trim();
    if (q.isEmpty) return browse();
    if (!_syncDone) unawaited(warmUp());
    final rows = await _dao.searchByName(q);
    return ExercisePage(
      total: rows.length,
      items: rows,
      fromCache: !_syncDone && _lastError != null,
    );
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

  /// Pulls catalogue pages (resuming from the cursor) until the local
  /// catalogue holds at least [target] rows, the server is exhausted, or the
  /// API errors (offline / rate limit). Returns true when the local data
  /// satisfies [target] — false means "serving a possibly-stale cache".
  ///
  /// Concurrent callers interleave fairly: page fetches are serialized (a
  /// shared cursor walked by two loops would double-fetch pages and 429),
  /// but each caller re-checks its own [target] between pages — so a browse
  /// needing 50 rows returns after a couple of pages even while [warmUp] is
  /// still walking the whole catalogue.
  Future<bool> _syncUpTo(int target) async {
    try {
      while (true) {
        if (_syncDone) return true;
        final count = await _dao.countCatalogue();
        if (_serverTotal != null && count >= _serverTotal!) {
          await _markDone();
          return true;
        }
        if (_syncStarted && _nextCursor == null) {
          // Walked every page this session.
          await _markDone();
          return true;
        }
        if (_serverTotal != null && count >= target) return true;
        await _syncNextPage();
      }
    } on ExerciseApiException catch (e) {
      _lastError = e;
      return false; // degrade to cache; a later call resumes from the cursor
    }
  }

  Future<void> _markDone() async {
    if (_syncDone) return;
    _syncDone = true;
    _lastError = null;
    await _checkpoint.clear();
    if (!_synced.isCompleted) _synced.complete();
  }

  /// Fetch-and-cache exactly one catalogue page. Serialized: if another
  /// caller's fetch is in flight, wait for it instead of starting a second
  /// one, then let the caller re-check its target.
  Future<void> _syncNextPage() async {
    final inFlight = _pageInFlight;
    if (inFlight != null) return inFlight;
    final run = _fetchOnePage();
    _pageInFlight = run;
    try {
      await run;
    } finally {
      _pageInFlight = null;
    }
  }

  Future<void> _fetchOnePage() async {
    var after = _nextCursor;
    if (_syncStarted) {
      await Future<void>.delayed(_pageDelay);
    } else {
      // First page this launch: resume from the saved checkpoint when the
      // DB still holds the rows it vouches for (a reinstall wipes the DB
      // but not the iOS Keychain).
      final saved = await _checkpoint.read();
      if (saved != null &&
          await _dao.countCatalogue() >= saved.cachedCount) {
        after = saved.cursor;
      }
    }
    final page = await _api.browsePage(after: after);
    _syncStarted = true;
    _lastError = null;
    _serverTotal = page.total;
    _nextCursor = page.nextCursor;
    if (page.items.isNotEmpty) {
      await _dao.cacheAll(page.items.map((e) => e.toCompanion()).toList());
    }
    final next = page.nextCursor;
    if (next == null) {
      // Last page: the walk is over. Done-ness itself is decided by the
      // caller's loop (row count vs server total).
      await _checkpoint.clear();
    } else {
      await _checkpoint.write(next, await _dao.countCatalogue());
    }
  }
}
