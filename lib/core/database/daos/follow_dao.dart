import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'follow_dao.g.dart';

/// Data access for the local [Follows] cache — the current user's outgoing
/// follow edges. This is the offline source of truth for "am I following X?".
@DriftAccessor(tables: [Follows])
class FollowDao extends DatabaseAccessor<AppDatabase> with _$FollowDaoMixin {
  FollowDao(super.db);

  /// Stream of followee ids the current [followerId] follows (not soft-deleted).
  Stream<List<String>> watchFollowingIds(String followerId) {
    final q = select(follows)
      ..where((t) => t.followerId.equals(followerId) & t.deletedAt.isNull());
    return q.watch().map((rows) => rows.map((r) => r.followeeId).toList());
  }

  /// Whether [followerId] currently follows [followeeId].
  Future<bool> isFollowing(String followerId, String followeeId) async {
    final row = await (select(follows)
          ..where((t) =>
              t.followerId.equals(followerId) &
              t.followeeId.equals(followeeId) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
    return row != null;
  }

  /// Look up a single follow edge (including soft-deleted), if present.
  Future<Follow?> find(String followerId, String followeeId) {
    return (select(follows)
          ..where((t) =>
              t.followerId.equals(followerId) &
              t.followeeId.equals(followeeId)))
        .getSingleOrNull();
  }

  /// Insert (or revive) a follow edge. Returns the row's local id.
  Future<int> upsertFollow({
    required String followerId,
    required String followeeId,
    required String remoteId,
  }) {
    return into(follows).insertOnConflictUpdate(
      FollowsCompanion(
        followerId: Value(followerId),
        followeeId: Value(followeeId),
        remoteId: Value(remoteId),
        syncStatus: const Value('pending'),
        deletedAt: const Value(null),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard-delete the local follow edge (the unfollow is queued separately).
  Future<int> deleteFollow(String followerId, String followeeId) {
    return (delete(follows)
          ..where((t) =>
              t.followerId.equals(followerId) &
              t.followeeId.equals(followeeId)))
        .go();
  }

  /// Replace the whole local follow cache for [followerId] from a server
  /// snapshot of `{followeeId: remoteId}`. Keeps offline reads fresh.
  Future<void> replaceFollowing(
    String followerId,
    Map<String, String> followeeToRemoteId,
  ) async {
    await transaction(() async {
      await (delete(follows)..where((t) => t.followerId.equals(followerId)))
          .go();
      for (final entry in followeeToRemoteId.entries) {
        await into(follows).insert(
          FollowsCompanion(
            followerId: Value(followerId),
            followeeId: Value(entry.key),
            remoteId: Value(entry.value),
            syncStatus: const Value('synced'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
