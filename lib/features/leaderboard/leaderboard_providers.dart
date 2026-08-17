import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/leaderboard_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';

/// The three leaderboard scopes the screen offers. Values map 1:1 onto the
/// Supabase RPCs from `008_leaderboard.sql`.
enum LeaderboardScope { rivals, global, friends }

/// The three boards within each scope (PRD §5.11). Weekly/monthly are UTC
/// seasons that reset at boundaries; all-time never resets.
enum LeaderboardBoard {
  weekly('weekly'),
  monthly('monthly'),
  allTime('all_time');

  const LeaderboardBoard(this.wire);

  /// Wire value understood by the `leaderboard_*` RPCs.
  final String wire;
}

/// Family key: one board of one scope.
typedef LeaderboardKey = ({LeaderboardScope scope, LeaderboardBoard board});

/// The board currently selected in the Bros tab UI. The rank badge and Home
/// preview deliberately do NOT follow this — they stay pinned to the weekly
/// global board so the badge doesn't jump when browsing.
final leaderboardBoardProvider =
    StateProvider<LeaderboardBoard>((_) => LeaderboardBoard.weekly);

/// UTC instant of the next reset for a board, or null for all-time.
/// Boundaries mirror compute_leaderboard_scores: weekly = Monday 00:00 UTC,
/// monthly = 1st 00:00 UTC.
DateTime? nextResetUtc(LeaderboardBoard board, {DateTime? nowUtc}) {
  final now = nowUtc ?? DateTime.now().toUtc();
  switch (board) {
    case LeaderboardBoard.weekly:
      final today = DateTime.utc(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: now.weekday - 1));
      return monday.add(const Duration(days: 7));
    case LeaderboardBoard.monthly:
      return now.month == 12
          ? DateTime.utc(now.year + 1)
          : DateTime.utc(now.year, now.month + 1);
    case LeaderboardBoard.allTime:
      return null;
  }
}

/// One ranked row as returned by the leaderboard RPCs.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.volume,
    required this.composite,
    this.userId,
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
      userId: row['user_id'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isMe: row['is_me'] as bool? ?? false,
    );
  }

  final int rank;
  final String name;
  final double volume;
  final double composite;
  final String? userId;
  final String? avatarUrl;
  final bool isMe;
}

/// Leaderboard cache DAO (Drift v19).
final leaderboardDaoProvider = Provider<LeaderboardDao>((ref) {
  return LeaderboardDao(ref.watch(databaseProvider));
});

/// Server-ranked leaderboard rows for a (scope, board).
///
/// Offline-first with a read-through cache: a successful fetch replaces the
/// (scope, board) slice in `LeaderboardCache`; without Supabase, sign-in, or
/// network the cached slice renders instead of an empty board.
final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, LeaderboardKey>((ref, key) async {
  final dao = ref.watch(leaderboardDaoProvider);
  final sb = ref.watch(supabaseProvider);

  Future<List<LeaderboardEntry>> fromCache() async => [
        for (final r in await dao.rowsFor(key.scope.name, key.board.wire))
          LeaderboardEntry(
            rank: r.rank,
            name: r.name,
            volume: r.volume,
            composite: r.composite,
            userId: r.userId,
            avatarUrl: r.avatarUrl,
            isMe: r.isMe,
          ),
      ];

  if (sb == null || sb.auth.currentUser == null) return fromCache();

  final fn = switch (key.scope) {
    LeaderboardScope.rivals => 'leaderboard_rivals',
    LeaderboardScope.global => 'leaderboard_global',
    LeaderboardScope.friends => 'leaderboard_friends',
  };

  try {
    final rows = await sb.rpc<List<dynamic>>(
      fn,
      params: {'p_board': key.board.wire},
    );
    final entries = [
      for (final row in rows)
        LeaderboardEntry.fromRow((row as Map).cast<String, dynamic>()),
    ];
    final now = DateTime.now();
    await dao.replaceRows(key.scope.name, key.board.wire, [
      for (final e in entries)
        LeaderboardCacheCompanion.insert(
          scope: key.scope.name,
          board: key.board.wire,
          rank: e.rank,
          name: e.name,
          userId: Value(e.userId),
          avatarUrl: Value(e.avatarUrl),
          volume: Value(e.volume),
          composite: Value(e.composite),
          isMe: Value(e.isMe),
          fetchedAt: now,
        ),
    ]);
    return entries;
  } on Exception {
    return fromCache();
  }
});

/// Last season's winner for the banner.
class SeasonWinner {
  const SeasonWinner({required this.name, this.avatarUrl, this.seasonStart});

  final String name;
  final String? avatarUrl;
  final DateTime? seasonStart;
}

/// Last closed season's winner for a (scope, board); null for all-time (it
/// never resets) or before the first season has finalized. Same read-through
/// cache pattern as [leaderboardProvider].
final lastWinnerProvider = FutureProvider.autoDispose
    .family<SeasonWinner?, LeaderboardKey>((ref, key) async {
  if (key.board == LeaderboardBoard.allTime) return null;
  final dao = ref.watch(leaderboardDaoProvider);
  final sb = ref.watch(supabaseProvider);

  Future<SeasonWinner?> fromCache() async {
    final r = await dao.winnerFor(key.scope.name, key.board.wire);
    return r == null
        ? null
        : SeasonWinner(
            name: r.name,
            avatarUrl: r.avatarUrl,
            seasonStart: r.seasonStart,
          );
  }

  if (sb == null || sb.auth.currentUser == null) return fromCache();
  try {
    final rows = await sb.rpc<List<dynamic>>(
      'leaderboard_last_winner',
      params: {'p_board': key.board.wire, 'p_scope': key.scope.name},
    );
    if (rows.isEmpty) return fromCache();
    final row = (rows.first as Map).cast<String, dynamic>();
    final name = (row['display_name'] as String?)?.trim();
    final winner = SeasonWinner(
      name: name == null || name.isEmpty ? 'Anonymous' : name,
      avatarUrl: row['avatar_url'] as String?,
      seasonStart: DateTime.tryParse(row['season_start'] as String? ?? ''),
    );
    await dao.saveWinner(
      SeasonWinnerCacheCompanion.insert(
        scope: key.scope.name,
        board: key.board.wire,
        name: winner.name,
        userId: Value(row['user_id'] as String?),
        avatarUrl: Value(winner.avatarUrl),
        seasonStart: Value(winner.seasonStart),
        fetchedAt: DateTime.now(),
      ),
    );
    return winner;
  } on Exception {
    return fromCache();
  }
});

/// The signed-in user's live composite on the weekly global board. `null`
/// while loading, offline, signed out, or not yet on the board. Feeds the
/// scaffold's rank-resolution listener; screens display [myRankProvider].
/// Pinned to weekly/global regardless of the board the UI is browsing, so
/// the persisted rank badge stays stable.
final myLiveCompositeProvider = Provider.autoDispose<double?>((ref) {
  final entries = ref
      .watch(leaderboardProvider((
        scope: LeaderboardScope.global,
        board: LeaderboardBoard.weekly,
      )))
      .valueOrNull;
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
