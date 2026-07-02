import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/providers/providers.dart';

/// The three leaderboard scopes the screen offers. Values map 1:1 onto the
/// Supabase RPCs from `008_leaderboard.sql`.
enum LeaderboardScope { rivals, global, friends }

/// One ranked row as returned by the leaderboard RPCs.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.volume,
    required this.composite,
    this.avatarUrl,
    this.isMe = false,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) {
    return LeaderboardEntry(
      rank: (row['rank'] as num?)?.toInt() ?? 0,
      name: (row['display_name'] as String?)?.trim().isNotEmpty ?? false
          ? (row['display_name'] as String).trim()
          : 'Anonymous',
      volume: (row['volume_raw'] as num?)?.toDouble() ?? 0,
      composite: (row['composite'] as num?)?.toDouble() ?? 0,
      avatarUrl: row['avatar_url'] as String?,
      isMe: row['is_me'] as bool? ?? false,
    );
  }

  final int rank;
  final String name;
  final double volume;
  final double composite;
  final String? avatarUrl;
  final bool isMe;
}

/// Server-ranked leaderboard rows for a scope (weekly board).
///
/// Offline-first: with no Supabase client, no signed-in user, or a network
/// failure this resolves to an empty list — the screen renders its empty
/// state instead of an error, and the tab stays usable offline.
final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, LeaderboardScope>((ref, scope) async {
  final sb = ref.watch(supabaseProvider);
  if (sb == null || sb.auth.currentUser == null) return const [];

  final fn = switch (scope) {
    LeaderboardScope.rivals => 'leaderboard_rivals',
    LeaderboardScope.global => 'leaderboard_global',
    LeaderboardScope.friends => 'leaderboard_friends',
  };

  try {
    final rows = await sb.rpc<List<dynamic>>(
      fn,
      params: {'p_board': 'weekly'},
    );
    return [
      for (final row in rows)
        LeaderboardEntry.fromRow((row as Map).cast<String, dynamic>()),
    ];
  } on Exception {
    return const [];
  }
});
