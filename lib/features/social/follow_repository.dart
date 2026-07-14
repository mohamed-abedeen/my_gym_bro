import 'package:my_gym_bro/core/database/app_database.dart' show Follows;
import 'package:my_gym_bro/core/database/daos/follow_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Coordinates the local [Follows] cache with Supabase for the social graph.
///
/// Writes are **offline-first**: follow/unfollow update the local cache and
/// enqueue a sync op; they never block on the network. Reads of other users'
/// public profiles and the mutual-follow check go to Supabase when online.
class FollowRepository {
  FollowRepository(this._dao, this._sync, this._supabase);

  final FollowDao _dao;
  final SyncService _sync;
  final SupabaseClient? _supabase;

  static const _uuid = Uuid();

  /// The signed-in user's id, or null when signed-out / Supabase-less.
  String? get currentUserId => _supabase?.auth.currentUser?.id;

  /// Live stream of ids the current user follows (from the local cache).
  Stream<List<String>> watchFollowingIds() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);
    return _dao.watchFollowingIds(uid);
  }

  /// Whether the current user follows [followeeId] (local, offline-safe).
  Future<bool> isFollowing(String followeeId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    return _dao.isFollowing(uid, followeeId);
  }

  /// Follow [followeeId]: optimistic local write + queued sync insert.
  ///
  /// The follow row's Supabase `id` is generated here (a UUID) and stored
  /// locally as `remoteId`, so a later unfollow can target that exact row.
  Future<void> follow(String followeeId) async {
    final uid = currentUserId;
    if (uid == null || uid == followeeId) return;
    if (await _dao.isFollowing(uid, followeeId)) return;

    final remoteId = _uuid.v4();
    await _dao.upsertFollow(
      followerId: uid,
      followeeId: followeeId,
      remoteId: remoteId,
    );
    await _sync.enqueue(
      table: 'follows',
      rowId: 0, // follows carries its id in the payload; rowId is unused
      operation: 'insert',
      payload: {
        'id': remoteId,
        'follower_id': uid,
        'followee_id': followeeId,
      },
    );
  }

  /// Unfollow [followeeId]: optimistic local delete + queued sync delete.
  Future<void> unfollow(String followeeId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final row = await _dao.find(uid, followeeId);
    await _dao.deleteFollow(uid, followeeId);

    final remoteId = row?.remoteId;
    if (remoteId != null) {
      await _sync.enqueue(
        table: 'follows',
        rowId: row!.localId,
        operation: 'delete',
        // remote_id in the payload lets sync_service target the row directly.
        payload: {'remote_id': remoteId},
      );
    }
  }

  /// Fetch a user's public profile (safe fields + counts) from Supabase.
  /// Returns null offline or when the user has no profile.
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

  /// The current user's relationship to [userId]: self / none / following /
  /// friends. "friends" requires a mutual follow, so it checks the server for
  /// the reverse edge (falls back to non-mutual when offline).
  Future<Relationship> relationshipTo(String userId) async {
    final uid = currentUserId;
    if (uid == null) return Relationship.none;
    if (uid == userId) return Relationship.self;

    final iFollow = await isFollowing(userId);
    if (!iFollow) return Relationship.none;

    final sb = _supabase;
    if (sb == null) return Relationship.following; // can't confirm mutual offline
    final back = await sb
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('followee_id', uid)
        .maybeSingle();
    return back != null ? Relationship.friends : Relationship.following;
  }

  /// Refresh the local follow cache from the server. Call on app start / when
  /// opening the profile so offline reads stay accurate across devices.
  Future<void> refreshFollowingFromServer() async {
    final uid = currentUserId;
    final sb = _supabase;
    if (uid == null || sb == null) return;
    final rows = await sb
        .from('follows')
        .select('id, followee_id')
        .eq('follower_id', uid);
    final map = <String, String>{
      for (final r in rows as List)
        (r as Map<String, dynamic>)['followee_id'] as String:
            r['id'] as String,
    };
    await _dao.replaceFollowing(uid, map);
  }
}
