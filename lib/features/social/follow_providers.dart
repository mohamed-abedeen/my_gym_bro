import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/daos/follow_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/social/follow_repository.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';

/// Local follow-cache DAO.
final followDaoProvider = Provider<FollowDao>((ref) {
  return FollowDao(ref.watch(databaseProvider));
});

/// Social graph repository (follows + friends + public profiles).
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(
    ref.watch(followDaoProvider),
    ref.watch(syncServiceProvider),
    ref.watch(supabaseProvider),
  );
});

/// The signed-in user's auth id, or null when signed-out / Supabase-less.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseProvider)?.auth.currentUser?.id;
});

/// Ids the current user follows (live, from the local cache).
final followingIdsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(followRepositoryProvider).watchFollowingIds();
});

/// The current user's own public profile (authoritative social counts from the
/// server). Null offline / signed-out — callers fall back to the local follow
/// count for "following".
final myPublicProfileProvider = FutureProvider<PublicProfile?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Future<PublicProfile?>.value(null);
  ref.watch(followingIdsProvider); // refresh counts when the follow set changes
  return ref.watch(followRepositoryProvider).fetchPublicProfile(uid);
});

/// A user's public profile (safe fields + social counts) from Supabase.
final publicProfileProvider =
    FutureProvider.family<PublicProfile?, String>((ref, userId) {
  // Re-fetch when the local follow set changes (counts may shift).
  ref.watch(followingIdsProvider);
  return ref.watch(followRepositoryProvider).fetchPublicProfile(userId);
});

/// The current user's relationship to a given profile.
final relationshipProvider =
    FutureProvider.family<Relationship, String>((ref, userId) {
  ref.watch(followingIdsProvider);
  return ref.watch(followRepositoryProvider).relationshipTo(userId);
});
