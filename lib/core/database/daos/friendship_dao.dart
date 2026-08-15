import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'friendship_dao.g.dart';

/// Data access for the local [Friendships] cache — every friendship edge the
/// current user is a side of (requests in and out, accepted bros, blocked
/// pairs). This is the offline source of truth for relationship state.
@DriftAccessor(tables: [Friendships])
class FriendshipDao extends DatabaseAccessor<AppDatabase>
    with _$FriendshipDaoMixin {
  FriendshipDao(super.db);

  /// Live stream of every non-deleted edge involving [userId].
  Stream<List<Friendship>> watchInvolving(String userId) {
    final q = select(friendships)
      ..where((t) =>
          (t.requesterId.equals(userId) | t.addresseeId.equals(userId)) &
          t.deletedAt.isNull());
    return q.watch();
  }

  /// The edge between [userId] and [otherId], in either direction, if any.
  Future<Friendship?> findPair(String userId, String otherId) {
    return (select(friendships)
          ..where((t) =>
              ((t.requesterId.equals(userId) & t.addresseeId.equals(otherId)) |
                  (t.requesterId.equals(otherId) &
                      t.addresseeId.equals(userId))) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Insert (or revive) an edge. Returns the row's local id.
  Future<int> upsertEdge({
    required String requesterId,
    required String addresseeId,
    required String remoteId,
    String status = 'pending',
    String? blockedBy,
  }) {
    return into(friendships).insertOnConflictUpdate(
      FriendshipsCompanion(
        requesterId: Value(requesterId),
        addresseeId: Value(addresseeId),
        remoteId: Value(remoteId),
        status: Value(status),
        blockedBy: Value(blockedBy),
        syncStatus: const Value('pending'),
        deletedAt: const Value(null),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update an edge's status in place (accept / block).
  Future<void> updateStatus(
    int localId, {
    required String status,
    String? blockedBy,
    DateTime? respondedAt,
  }) {
    return (update(friendships)..where((t) => t.localId.equals(localId))).write(
      FriendshipsCompanion(
        status: Value(status),
        blockedBy: Value(blockedBy),
        respondedAt: Value(respondedAt),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard-delete an edge locally. The remote delete is queued separately and
  /// carries the remote id in its payload, so it doesn't need this row — and
  /// a hard delete frees the unique (requester, addressee) key immediately,
  /// which is what lets a pair re-request after a decline or unfriend.
  Future<int> deleteEdge(int localId) {
    return (delete(friendships)..where((t) => t.localId.equals(localId))).go();
  }

  /// Replace the local graph for [userId] from a server snapshot. Rows still
  /// waiting to push (syncStatus 'pending') are kept and win over the
  /// snapshot — the outbox pushes them and the next refresh reconciles.
  Future<void> replaceFromServer(
    String userId,
    List<FriendshipsCompanion> serverRows,
  ) async {
    await transaction(() async {
      await (delete(friendships)
            ..where((t) =>
                (t.requesterId.equals(userId) | t.addresseeId.equals(userId)) &
                t.syncStatus.equals('synced')))
          .go();
      for (final row in serverRows) {
        await into(friendships).insert(row, mode: InsertMode.insertOrIgnore);
      }
    });
  }
}
