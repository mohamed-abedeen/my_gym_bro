import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/friendship_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/social/friend_repository.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';

/// Local friendship-cache DAO.
final friendshipDaoProvider = Provider<FriendshipDao>((ref) {
  return FriendshipDao(ref.watch(databaseProvider));
});

/// Friends-graph repository (friendships + public profiles + @username).
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(
    friendshipDao: ref.watch(friendshipDaoProvider),
    userProfileDao: UserProfileDao(ref.watch(databaseProvider)),
    syncService: ref.watch(syncServiceProvider),
    supabase: ref.watch(supabaseProvider),
  );
});

/// The signed-in user's auth id, or null when signed-out / Supabase-less.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseProvider)?.auth.currentUser?.id;
});

/// Every live friendship edge involving the current user (local cache).
final friendshipEdgesProvider = StreamProvider<List<Friendship>>((ref) {
  return ref.watch(friendRepositoryProvider).watchEdges();
});

/// Auth ids of accepted bros.
final friendIdsProvider = Provider<List<String>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final edges = ref.watch(friendshipEdgesProvider).valueOrNull ?? const [];
  return [
    for (final e in edges)
      if (e.status == 'accepted')
        e.requesterId == uid ? e.addresseeId : e.requesterId,
  ];
});

/// Incoming pending requests — the inbox.
final incomingRequestsProvider = Provider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final edges = ref.watch(friendshipEdgesProvider).valueOrNull ?? const [];
  return [
    for (final e in edges)
      if (e.status == 'pending' && e.addresseeId == uid) e,
  ];
});

/// Outgoing pending requests (shown as "pending" chips).
final outgoingRequestsProvider = Provider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final edges = ref.watch(friendshipEdgesProvider).valueOrNull ?? const [];
  return [
    for (final e in edges)
      if (e.status == 'pending' && e.requesterId == uid) e,
  ];
});

/// Badge count for the add-bros header button.
final pendingRequestCountProvider = Provider<int>((ref) {
  return ref.watch(incomingRequestsProvider).length;
});

/// One-shot push of queued graph ops + pull of the server snapshot. Surfaces
/// that show the graph (Bros tab, profile) watch this on mount; pull-to-
/// refresh re-runs it via `ref.refresh`. No-op offline.
final friendGraphRefreshProvider = FutureProvider<void>((ref) {
  return ref.watch(friendRepositoryProvider).refreshFromServer();
});

/// The current user's own public profile (authoritative friend count from the
/// server). Null offline / signed-out — callers fall back to the local graph.
final myPublicProfileProvider = FutureProvider<PublicProfile?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Future<PublicProfile?>.value();
  ref.watch(friendshipEdgesProvider); // re-fetch when the graph changes
  return ref.watch(friendRepositoryProvider).fetchPublicProfile(uid);
});

/// A user's public profile (safe fields + friend count) from Supabase.
final publicProfileProvider =
    FutureProvider.family<PublicProfile?, String>((ref, userId) {
  ref.watch(friendshipEdgesProvider); // counts may shift with the graph
  return ref.watch(friendRepositoryProvider).fetchPublicProfile(userId);
});

/// The current user's relationship to a given user — derived synchronously
/// from the local cache, so it's instant and offline-safe.
final relationshipProvider = Provider.family<Relationship, String>(
  (ref, userId) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return Relationship.none;
    if (uid == userId) return Relationship.self;
    final edges = ref.watch(friendshipEdgesProvider).valueOrNull ?? const [];
    Friendship? pair;
    for (final e in edges) {
      if (e.requesterId == userId || e.addresseeId == userId) {
        pair = e;
        break;
      }
    }
    return relationshipFromRow(pair, uid);
  },
);
