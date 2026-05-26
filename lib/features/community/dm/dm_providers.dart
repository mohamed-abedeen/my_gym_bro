import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/dm_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/community/dm/dm_models.dart';
import 'package:my_gym_bro/features/community/dm/dm_repository.dart';

/// Provider for the DmDao.
final dmDaoProvider = Provider<DmDao>((ref) {
  final db = ref.watch(databaseProvider);
  return DmDao(db);
});

/// Provider for the DmRepository.
final dmRepositoryProvider = Provider<DmRepository?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  if (supabase == null) return null;
  final dmDao = ref.watch(dmDaoProvider);
  final db = ref.watch(databaseProvider);
  return DmRepository(supabase: supabase, dmDao: dmDao, db: db);
});

/// Stream of all conversations for the current user.
final dmConversationsProvider = StreamProvider.autoDispose<List<DmConversation>>((ref) {
  final repo = ref.watch(dmRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.streamConversations();
});

/// Stream of messages for a specific conversation.
final dmMessagesProvider = StreamProvider.autoDispose.family<List<DmMessage>, String>((ref, conversationId) {
  final repo = ref.watch(dmRepositoryProvider);
  if (repo == null) return Stream.value([]);
  // Fire-and-forget fetch to ensure local cache is up to date, 
  // though Realtime will also stream new changes.
  repo.fetchMessages(conversationId);
  return repo.streamLocalMessages(conversationId);
});

/// The currently active conversation ID (set when navigating to Chat screen).
final activeDmConversationProvider = StateProvider<String?>((ref) => null);
