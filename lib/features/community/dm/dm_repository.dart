import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/dm_dao.dart';
import 'dm_models.dart';

const _uuid = Uuid();

/// Repository for Direct Messages.
/// Wraps Supabase calls and syncs with the local Drift [DmDao] cache.
class DmRepository {
  DmRepository({required this.supabase, required this.dmDao, required this.db});

  final SupabaseClient supabase;
  final DmDao dmDao;
  // Keep AppDatabase reference for schedule saving
  final AppDatabase db;

  String get _myId => supabase.auth.currentUser?.id ?? '';

  // ─── Conversations ───────────────────────────────────────────────────────

  /// Stream conversations for the current user from Supabase.
  Stream<List<DmConversation>> streamConversations() {
    // Supabase Realtime on dm_conversations — re-fetches on each change.
    return supabase
        .from('dm_conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((rows) {
          return rows
              .where((r) =>
                  r['participant_a'] == _myId || r['participant_b'] == _myId)
              .map((r) {
                final otherUserId = r['participant_a'] == _myId
                    ? r['participant_b'] as String
                    : r['participant_a'] as String;
                final lastAt = r['last_message_at'] != null
                    ? DateTime.tryParse(r['last_message_at'] as String)
                    : null;
                return DmConversation(
                  id: r['id'] as String,
                  otherUserId: otherUserId,
                  // No user_profiles table yet — fall back to truncated ID
                  otherUserName: 'User ${otherUserId.substring(0, 6)}',
                  lastMessageText: r['last_message_text'] as String?,
                  lastMessageAt: lastAt,
                );
              })
              .toList();
        });
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  /// Stream messages from the local Drift cache for a conversation.
  Stream<List<DmMessage>> streamLocalMessages(String conversationId) =>
      dmDao.watchMessages(conversationId);

  /// Subscribe to Supabase Realtime for dm_messages and upsert into local cache.
  /// Returns the subscription channel (caller should cancel on dispose).
  RealtimeChannel subscribeMessages(String conversationId) {
    return supabase
        .channel('dm:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            await dmDao.upsertMessage(_supabaseRowToCompanion(row));
          },
        )
        .subscribe();
  }

  /// How many messages to load per page.
  static const _pageSize = 50;

  /// Load existing messages from Supabase into the local cache.
  /// [before] allows pagination — pass the oldest loaded message's timestamp
  /// to fetch the next page of older messages.
  Future<void> fetchMessages(String conversationId, {DateTime? before}) async {
    var query = supabase
        .from('dm_messages')
        .select()
        .eq('conversation_id', conversationId);

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(_pageSize);

    for (final row in rows) {
      await dmDao.upsertMessage(_supabaseRowToCompanion(row));
    }
  }

  // ─── Sending ─────────────────────────────────────────────────────────────

  /// Send a text message.
  Future<void> sendTextMessage(String conversationId, String text) async {
    final tempId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Optimistic insert
    await dmDao.upsertMessage(DmMessagesCompanion(
      id: drift.Value(tempId),
      conversationId: drift.Value(conversationId),
      senderId: drift.Value(_myId),
      type: const drift.Value('text'),
      body: drift.Value(text),
      createdAt: drift.Value(now),
      isMine: const drift.Value(true),
      isOptimistic: const drift.Value(true),
    ));

    try {
      final result = await supabase.from('dm_messages').insert({
        'conversation_id': conversationId,
        'sender_id': _myId,
        'type': 'text',
        'body': text,
      }).select().single();

      // Replace optimistic row with confirmed row
      await dmDao.deleteMessage(tempId);
      await dmDao.upsertMessage(_supabaseRowToCompanion(result));
    } catch (e) {
      await dmDao.deleteMessage(tempId);
      rethrow;
    }
  }

  /// Maximum image file size: 10 MB.
  static const _maxImageBytes = 10 * 1024 * 1024;

  /// Send an image message: upload to Storage, then insert the URL.
  Future<void> sendImageMessage(String conversationId, File imageFile) async {
    final fileSize = await imageFile.length();
    if (fileSize > _maxImageBytes) {
      throw Exception('Image exceeds 10 MB limit.');
    }

    final tempId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Optimistic placeholder without URL
    await dmDao.upsertMessage(DmMessagesCompanion(
      id: drift.Value(tempId),
      conversationId: drift.Value(conversationId),
      senderId: drift.Value(_myId),
      type: const drift.Value('image'),
      createdAt: drift.Value(now),
      isMine: const drift.Value(true),
      isOptimistic: const drift.Value(true),
    ));

    try {
      final ext = imageFile.path.split('.').last;
      final storagePath = 'dm/$conversationId/${_uuid.v4()}.$ext';
      await supabase.storage.from('dm-media').upload(storagePath, imageFile);
      final signedUrl = await supabase.storage
          .from('dm-media')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days

      final result = await supabase.from('dm_messages').insert({
        'conversation_id': conversationId,
        'sender_id': _myId,
        'type': 'image',
        'image_url': signedUrl,
      }).select().single();

      await dmDao.deleteMessage(tempId);
      await dmDao.upsertMessage(_supabaseRowToCompanion(result));
    } catch (e) {
      await dmDao.deleteMessage(tempId);
      rethrow;
    }
  }

  /// Send a schedule card message.
  Future<void> sendScheduleMessage(
    String conversationId,
    String scheduleName,
    List<SharedScheduleDay> days,
  ) async {
    final payload = SharedSchedule(name: scheduleName, days: days);
    final tempId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await dmDao.upsertMessage(DmMessagesCompanion(
      id: drift.Value(tempId),
      conversationId: drift.Value(conversationId),
      senderId: drift.Value(_myId),
      type: const drift.Value('schedule'),
      body: drift.Value(payload.toJsonString()),
      createdAt: drift.Value(now),
      isMine: const drift.Value(true),
      isOptimistic: const drift.Value(true),
    ));

    try {
      final result = await supabase.from('dm_messages').insert({
        'conversation_id': conversationId,
        'sender_id': _myId,
        'type': 'schedule',
        'body': payload.toJsonString(),
      }).select().single();

      await dmDao.deleteMessage(tempId);
      await dmDao.upsertMessage(_supabaseRowToCompanion(result));
    } catch (e) {
      await dmDao.deleteMessage(tempId);
      rethrow;
    }
  }

  /// Save a received shared schedule into the local Drift DB.
  Future<void> saveReceivedSchedule(SharedSchedule schedule) async {
    // Insert schedule row
    final scheduleId = await db.into(db.schedules).insert(
          SchedulesCompanion(
            name: drift.Value(schedule.name),
            isActive: const drift.Value(false),
          ),
        );

    // Insert each day
    for (final day in schedule.days) {
      await db.into(db.scheduleDays).insert(
            ScheduleDaysCompanion(
              scheduleId: drift.Value(scheduleId),
              dayIndex: drift.Value(day.dayIndex),
              label: drift.Value(day.label),
              isRestDay: drift.Value(day.isRestDay),
            ),
          );
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  DmMessagesCompanion _supabaseRowToCompanion(Map<String, dynamic> row) {
    final createdAt = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'] as String)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    return DmMessagesCompanion(
      id: drift.Value(row['id'] as String),
      conversationId: drift.Value(row['conversation_id'] as String),
      senderId: drift.Value(row['sender_id'] as String),
      type: drift.Value(row['type'] as String? ?? 'text'),
      body: drift.Value(row['body'] as String?),
      imageUrl: drift.Value(row['image_url'] as String?),
      createdAt: drift.Value(createdAt),
      isMine: drift.Value(row['sender_id'] == _myId),
      isOptimistic: const drift.Value(false),
    );
  }
}
