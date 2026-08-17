import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/challenge_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/leaderboard/challenge_repository.dart';
import 'package:my_gym_bro/features/social/friend_providers.dart'
    show currentUserIdProvider;

/// Local challenge-cache DAO.
final challengeDaoProvider = Provider<ChallengeDao>((ref) {
  return ChallengeDao(ref.watch(databaseProvider));
});

/// Challenges repository (challenge list + participation + reports).
final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository(
    challengeDao: ref.watch(challengeDaoProvider),
    syncService: ref.watch(syncServiceProvider),
    supabase: ref.watch(supabaseProvider),
  );
});

/// Every visible cached challenge, newest window first (local cache).
final challengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(challengeRepositoryProvider).watchChallenges();
});

/// The current user's participation rows (local cache).
final myParticipationProvider =
    StreamProvider<List<ChallengeParticipant>>((ref) {
  // The repo captures the uid at stream creation — rebuild on auth changes.
  ref.watch(currentUserIdProvider);
  return ref.watch(challengeRepositoryProvider).watchMyParticipation();
});

/// Participation row for a given challenge remote id, if joined.
final participationForProvider =
    Provider.family<ChallengeParticipant?, String>((ref, challengeRemoteId) {
  final rows = ref.watch(myParticipationProvider).valueOrNull ?? const [];
  for (final row in rows) {
    if (row.challengeRemoteId == challengeRemoteId) return row;
  }
  return null;
});

/// Today's curated challenge, if the cache has one whose window contains now.
final dailyChallengeProvider = Provider<Challenge?>((ref) {
  final rows = ref.watch(challengesProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  for (final c in rows) {
    if (c.source == 'curated' &&
        c.status == 'active' &&
        !now.isBefore(c.startsAt) &&
        now.isBefore(c.endsAt)) {
      return c;
    }
  }
  return null;
});

/// Community challenges (live ones first, then recently ended).
final communityChallengesProvider = Provider<List<Challenge>>((ref) {
  final rows = ref.watch(challengesProvider).valueOrNull ?? const [];
  return [
    for (final c in rows)
      if (c.source == 'community') c,
  ];
});

/// Sum of confirmed challenge points (server-awarded, from the cache) — the
/// component that feeds the Phase 5 leaderboard composite, shown as "my
/// points" in the Challenges UI.
final myChallengePointsProvider = Provider<int>((ref) {
  final rows = ref.watch(myParticipationProvider).valueOrNull ?? const [];
  var total = 0;
  for (final row in rows) {
    total += row.pointsAwarded;
  }
  return total;
});

/// One-shot recompute of local progress, push of queued ops, and pull of the
/// server snapshot. The Challenges view watches this on mount; pull-to-refresh
/// re-runs it via `ref.refresh`. No-op offline (recompute still runs — it's
/// local).
final challengeRefreshProvider = FutureProvider<void>((ref) async {
  ref.watch(currentUserIdProvider); // re-run on sign-in/out
  final repo = ref.watch(challengeRepositoryProvider);
  await repo.recomputeProgress();
  await repo.refreshFromServer();
});
