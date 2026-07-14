import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/community/community_models.dart';
import 'package:my_gym_bro/features/community/community_repository.dart';

/// Community repository — Supabase-backed, or `null` when Supabase isn't
/// available (offline at startup / not configured). Never serves mock data.
final communityRepositoryProvider = Provider<CommunityRepository?>((ref) {
  final sb = ref.watch(supabaseProvider);
  if (sb == null) return null;
  return SupabaseCommunityRepository(sb);
});

/// The community feed. Refetch by invalidating this provider (e.g. after
/// posting or liking). Errors (backend unavailable / network failure) surface
/// as the screen's offline state with pull-to-refresh retry.
final communityFeedProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  if (repo == null) {
    throw StateError('Community backend unavailable');
  }
  return repo.fetchFeed();
});
