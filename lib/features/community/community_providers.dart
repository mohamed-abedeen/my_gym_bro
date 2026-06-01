import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/community/community_models.dart';
import 'package:my_gym_bro/features/community/community_repository.dart';

/// Community repository — Supabase-backed when available, mock otherwise so the
/// feed still renders offline / when the backend isn't configured.
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final sb = ref.watch(supabaseProvider);
  if (sb == null) return const MockCommunityRepository();
  return SupabaseCommunityRepository(sb);
});

/// The community feed. Refetch by invalidating this provider (e.g. after
/// posting or liking).
final communityFeedProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) {
  return ref.watch(communityRepositoryProvider).fetchFeed();
});
