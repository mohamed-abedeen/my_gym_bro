import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';

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

/// The signed-in user's live composite on the weekly global board. `null`
/// while loading, offline, signed out, or not yet on the board. Feeds the
/// scaffold's rank-resolution listener; screens display [myRankProvider].
final myLiveCompositeProvider = Provider.autoDispose<double?>((ref) {
  final entries =
      ref.watch(leaderboardProvider(LeaderboardScope.global)).valueOrNull;
  for (final e in entries ?? const <LeaderboardEntry>[]) {
    if (e.isMe) return e.composite;
  }
  return null;
});

/// The rank badge to display: derived from the persisted, shield-resolved
/// [rankStateProvider] (kept fresh by the scaffold listener, available
/// offline), falling back to the live board before the first save lands.
/// `null` only when the user has never been ranked.
final myRankProvider = Provider.autoDispose<Rank?>((ref) {
  final composite = ref.watch(myCompositeProvider);
  return composite == null ? null : Rank.fromComposite(composite);
});

/// Composite behind the displayed badge — also drives the progress bar.
final myCompositeProvider = Provider.autoDispose<double?>((ref) {
  final stored = ref.watch(rankStateProvider);
  return stored?.composite ?? ref.watch(myLiveCompositeProvider);
});

/// Persisted [RankState] (composite + demotion-shield deadline), written by
/// the scaffold's rank-resolution listener via [resolveRank] and stored as
/// JSON so the badge survives restarts and offline sessions.
class RankStateNotifier extends StateNotifier<RankState?> {
  RankStateNotifier() : super(null) {
    _load();
  }

  static const _key = 'rank_state';

  /// True once the stored value has been read — rank resolution waits on
  /// this so a slow read isn't mistaken for "never ranked before".
  bool loaded = false;

  Future<void> _load() async {
    final raw = await SecureStorage().read(_key);
    if (!mounted) return;
    if (raw != null && raw.isNotEmpty && state == null) {
      try {
        final map = json.decode(raw);
        // Type-checked field reads so a corrupt store can never throw.
        if (map is Map) {
          final c = map['c'];
          final su = map['su'];
          if (c is num) {
            state = RankState(
              c.toDouble(),
              shieldUntil: su is int
                  ? DateTime.fromMillisecondsSinceEpoch(su)
                  : null,
            );
          }
        }
      } on FormatException {
        // Corrupt store — start fresh.
      }
    }
    loaded = true;
  }

  Future<void> save(RankState s) async {
    state = s;
    await SecureStorage().write(
      _key,
      json.encode({
        'c': s.composite,
        'su': s.shieldUntil?.millisecondsSinceEpoch,
      }),
    );
  }
}

final rankStateProvider = StateNotifierProvider<RankStateNotifier, RankState?>(
  (ref) => RankStateNotifier(),
);
