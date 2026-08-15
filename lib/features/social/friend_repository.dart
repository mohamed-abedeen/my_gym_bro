import 'package:drift/drift.dart' show Value;

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/friendship_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Outcome of sending a friend request.
enum SendRequestResult {
  /// Written locally and queued for sync.
  sent,

  /// The other side had already sent one — we accepted it instead.
  accepted,

  /// An edge already exists: already bros, already pending, or a blocked
  /// pair. Deliberately indistinguishable to the caller (PRD §5.6 —
  /// blocking is discreet).
  unavailable,

  /// Not signed in.
  notSignedIn,
}

/// Outcome of claiming a @username.
enum ClaimUsernameResult { claimed, taken, invalid, offline }

/// Outcome of an exact-match @username lookup.
sealed class UsernameLookupResult {
  const UsernameLookupResult();
}

class UsernameFound extends UsernameLookupResult {
  const UsernameFound(this.profile);
  final PublicProfile profile;
}

class UsernameNotFound extends UsernameLookupResult {
  const UsernameNotFound();
}

class UsernameLookupOffline extends UsernameLookupResult {
  const UsernameLookupOffline();
}

/// Coordinates the local [Friendships] cache with Supabase for the friends
/// graph (Bros Phase B — PRD §5.6, 04-BACKEND.md §5).
///
/// Graph writes are **offline-first**: request / accept / block / remove
/// update the local cache and enqueue a sync op; they never block on the
/// network. The two deliberate exceptions are the @username claim and lookup —
/// a handle is a global uniqueness contract, so claiming one is online-only
/// (like signing in), and lookups read the live server.
class FriendRepository {
  FriendRepository({
    required FriendshipDao friendshipDao,
    required UserProfileDao userProfileDao,
    required SyncService syncService,
    required SupabaseClient? supabase,
  })  : _dao = friendshipDao,
        _profiles = userProfileDao,
        _sync = syncService,
        _supabase = supabase;

  final FriendshipDao _dao;
  final UserProfileDao _profiles;
  final SyncService _sync;
  final SupabaseClient? _supabase;

  static const _uuid = Uuid();

  /// Lowercase a-z, digits, underscore; 3–20 chars (PRD §5.6). Must match the
  /// `user_profiles_username_format` CHECK in migration 012.
  static final usernameRx = RegExp(r'^[a-z0-9_]{3,20}$');

  /// The signed-in user's id, or null when signed-out / Supabase-less.
  String? get currentUserId => _supabase?.auth.currentUser?.id;

  /// Live stream of every friendship edge involving the current user.
  Stream<List<Friendship>> watchEdges() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);
    return _dao.watchInvolving(uid);
  }

  /// Send a friend request: optimistic local write + queued sync insert.
  ///
  /// The row's Supabase `id` is generated here (a UUID) and stored locally as
  /// `remoteId`, so later accept/delete ops can target that exact row. If the
  /// target already sent *us* a pending request, this accepts it instead.
  Future<SendRequestResult> sendRequest(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return SendRequestResult.notSignedIn;
    if (uid == targetUserId) return SendRequestResult.unavailable;

    final existing = await _dao.findPair(uid, targetUserId);
    if (existing != null) {
      if (existing.status == 'pending' && existing.addresseeId == uid) {
        await accept(existing);
        return SendRequestResult.accepted;
      }
      return SendRequestResult.unavailable;
    }

    final remoteId = _uuid.v4();
    await _dao.upsertEdge(
      requesterId: uid,
      addresseeId: targetUserId,
      remoteId: remoteId,
    );
    await _sync.enqueue(
      table: 'friendships',
      rowId: 0, // friendships carries its id in the payload; rowId is unused
      operation: 'insert',
      payload: {
        'id': remoteId,
        'requester_id': uid,
        'addressee_id': targetUserId,
        'status': 'pending',
      },
    );
    return SendRequestResult.sent;
  }

  /// Accept an incoming pending request (addressee only — mirrors RLS).
  Future<void> accept(Friendship edge) async {
    final uid = currentUserId;
    if (uid == null || edge.addresseeId != uid || edge.status != 'pending') {
      return;
    }
    final now = DateTime.now();
    await _dao.updateStatus(edge.localId, status: 'accepted', respondedAt: now);
    final remoteId = edge.remoteId;
    if (remoteId == null) return;
    await _sync.enqueue(
      table: 'friendships',
      rowId: edge.localId,
      operation: 'update',
      payload: {
        'remote_id': remoteId,
        'status': 'accepted',
        'responded_at': now.toUtc().toIso8601String(),
      },
    );
  }

  /// Remove an edge: decline or cancel a request, unfriend, or (blocker only)
  /// unblock. Local hard delete + queued remote delete — the pair may
  /// re-request afterwards. A blocked edge is only removable by its blocker
  /// (mirrors RLS; anything else would be block evasion).
  Future<void> removeEdge(Friendship edge) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (edge.status == 'blocked' && edge.blockedBy != uid) return;

    await _dao.deleteEdge(edge.localId);
    final remoteId = edge.remoteId;
    if (remoteId != null) {
      await _sync.enqueue(
        table: 'friendships',
        rowId: edge.localId,
        operation: 'delete',
        // remote_id in the payload lets sync_service target the row directly.
        payload: {'remote_id': remoteId},
      );
    }
  }

  /// Block [targetUserId] (store safety requirement). Converts any existing
  /// edge to 'blocked', or creates a pre-emptive blocked edge when the pair
  /// has none (blocking a stranger from their profile). Hides both directions.
  Future<void> block(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUserId) return;

    final existing = await _dao.findPair(uid, targetUserId);
    if (existing != null) {
      if (existing.status == 'blocked') return; // either side already blocked
      await _dao.updateStatus(
        existing.localId,
        status: 'blocked',
        blockedBy: uid,
        respondedAt: existing.respondedAt,
      );
      final remoteId = existing.remoteId;
      if (remoteId == null) return;
      await _sync.enqueue(
        table: 'friendships',
        rowId: existing.localId,
        operation: 'update',
        payload: {
          'remote_id': remoteId,
          'status': 'blocked',
          'blocked_by': uid,
        },
      );
      return;
    }

    final remoteId = _uuid.v4();
    await _dao.upsertEdge(
      requesterId: uid,
      addresseeId: targetUserId,
      remoteId: remoteId,
      status: 'blocked',
      blockedBy: uid,
    );
    await _sync.enqueue(
      table: 'friendships',
      rowId: 0,
      operation: 'insert',
      payload: {
        'id': remoteId,
        'requester_id': uid,
        'addressee_id': targetUserId,
        'status': 'blocked',
        'blocked_by': uid,
      },
    );
  }

  /// File an abuse report (store safety requirement). Insert-only server
  /// table with no local cache — the report rides the outbox and is reviewed
  /// manually (04-BACKEND.md §5).
  Future<void> report({
    required String reportedUserId,
    required String reason,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid == reportedUserId) return;
    final clean = InputSanitiser.sanitise(reason);
    if (clean.isEmpty) return;
    await _sync.enqueue(
      table: 'user_reports',
      rowId: 0,
      operation: 'insert',
      payload: {
        'id': _uuid.v4(),
        'reporter_id': uid,
        'reported_id': reportedUserId,
        'reason': clean,
      },
    );
  }

  /// The current user's relationship to [userId] — derived purely from the
  /// local cache, so it's instant and offline-safe.
  Future<Relationship> relationshipTo(String userId) async {
    final uid = currentUserId;
    if (uid == null) return Relationship.none;
    if (uid == userId) return Relationship.self;
    return relationshipFromRow(await _dao.findPair(uid, userId), uid);
  }

  /// Fetch a user's public profile (safe fields + friend count) from
  /// Supabase. Returns null offline or when the user has no profile.
  Future<PublicProfile?> fetchPublicProfile(String userId) async {
    final sb = _supabase;
    if (sb == null) return null;
    final row = await sb
        .from('public_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return PublicProfile.fromMap(row);
  }

  /// Exact-match lookup of a claimed @username (the only search there is —
  /// no name search, PRD §5.6). Accepts a leading '@' and any casing.
  Future<UsernameLookupResult> lookupByUsername(String raw) async {
    final username = _normalise(raw);
    if (!usernameRx.hasMatch(username)) return const UsernameNotFound();
    final sb = _supabase;
    if (sb == null) return const UsernameLookupOffline();
    try {
      final row = await sb
          .from('public_profiles')
          .select()
          .eq('username', username)
          .maybeSingle();
      if (row == null) return const UsernameNotFound();
      return UsernameFound(PublicProfile.fromMap(row));
    } on Exception {
      return const UsernameLookupOffline();
    }
  }

  /// Claim [raw] as the current user's @username. Online-only by design: the
  /// unique index on `user_profiles.username` is the arbiter, and a queued
  /// offline claim could silently lose the race hours later. On success the
  /// local profile row is updated too.
  Future<ClaimUsernameResult> claimUsername(String raw) async {
    final username = _normalise(raw);
    if (!usernameRx.hasMatch(username)) return ClaimUsernameResult.invalid;

    final sb = _supabase;
    final profile = await _profiles.getFirst();
    final remoteId = profile?.remoteId;
    if (sb == null || currentUserId == null || remoteId == null) {
      return ClaimUsernameResult.offline;
    }
    try {
      await sb
          .from('user_profiles')
          .update({'username': username}).eq('id', remoteId);
    } on PostgrestException catch (e) {
      if (e.code == '23505') return ClaimUsernameResult.taken; // unique index
      if (e.code == '23514') return ClaimUsernameResult.invalid; // format CHECK
      return ClaimUsernameResult.offline;
    } on Exception {
      return ClaimUsernameResult.offline;
    }
    await _profiles.updateUsername(profile!.localId, username);
    return ClaimUsernameResult.claimed;
  }

  /// Push anything queued, then replace the local graph from the server.
  /// No-op offline — the local cache stays authoritative.
  Future<void> refreshFromServer() async {
    final uid = currentUserId;
    final sb = _supabase;
    if (uid == null || sb == null) return;
    // Drain the outbox first so a queued accept/remove isn't resurrected by
    // the snapshot we're about to pull.
    await _sync.syncAll();
    try {
      final rows = await sb
          .from('friendships')
          .select()
          .or('requester_id.eq.$uid,addressee_id.eq.$uid');
      await _dao.replaceFromServer(uid, [
        for (final r in rows as List)
          _companionFromRemote(r as Map<String, dynamic>),
      ]);
    } on Exception {
      // Offline / transient — keep the cache as-is.
    }
  }

  String _normalise(String raw) =>
      raw.trim().toLowerCase().replaceFirst(RegExp('^@'), '');

  FriendshipsCompanion _companionFromRemote(Map<String, dynamic> r) {
    return FriendshipsCompanion.insert(
      requesterId: r['requester_id'] as String,
      addresseeId: r['addressee_id'] as String,
      remoteId: Value(r['id'] as String),
      status: Value(r['status'] as String),
      blockedBy: Value(r['blocked_by'] as String?),
      respondedAt: Value(_parseTimestamp(r['responded_at'])),
      createdAt: Value(_parseTimestamp(r['created_at'])),
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value('synced'),
    );
  }

  DateTime? _parseTimestamp(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();
}
