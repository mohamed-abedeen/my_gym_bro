import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'dm_dao.g.dart';

/// Data access object for the local DM message cache.
@DriftAccessor(tables: [DmMessages])
class DmDao extends DatabaseAccessor<AppDatabase> with _$DmDaoMixin {
  DmDao(super.db);

  /// Stream all messages for a conversation, ordered oldest-first.
  Stream<List<DmMessage>> watchMessages(String conversationId) =>
      (select(dmMessages)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Upsert a message (insert or replace on primary key conflict).
  Future<void> upsertMessage(DmMessagesCompanion companion) =>
      into(dmMessages).insertOnConflictUpdate(companion);

  /// Mark a previously-optimistic message as confirmed by Supabase.
  Future<void> markSent(String id) =>
      (update(dmMessages)..where((t) => t.id.equals(id))).write(
        const DmMessagesCompanion(isOptimistic: Value(false)),
      );

  /// Delete a single message by ID (used to replace optimistic rows).
  Future<void> deleteMessage(String id) =>
      (delete(dmMessages)..where((t) => t.id.equals(id))).go();

  /// Delete all cached messages for a conversation (e.g., on sign-out).
  Future<void> clearConversation(String conversationId) =>
      (delete(dmMessages)
            ..where((t) => t.conversationId.equals(conversationId)))
          .go();

  /// Delete all cached DM messages (full wipe on sign-out).
  Future<void> clearAll() => delete(dmMessages).go();
}
