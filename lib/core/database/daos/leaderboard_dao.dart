import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'leaderboard_dao.g.dart';

/// Data access for the leaderboard offline caches — ranked rows per
/// (scope, board) and the last season winner. Pure read-through cache: no
/// sync queue involvement; a successful fetch replaces its slice wholesale.
@DriftAccessor(tables: [LeaderboardCache, SeasonWinnerCache])
class LeaderboardDao extends DatabaseAccessor<AppDatabase>
    with _$LeaderboardDaoMixin {
  LeaderboardDao(super.db);

  /// Cached rows for a (scope, board), in rank order.
  Future<List<LeaderboardCacheData>> rowsFor(String scope, String board) {
    return (select(leaderboardCache)
          ..where((t) => t.scope.equals(scope) & t.board.equals(board))
          ..orderBy([(t) => OrderingTerm(expression: t.rank)]))
        .get();
  }

  /// Replace the cached slice for a (scope, board) with a fresh snapshot.
  Future<void> replaceRows(
    String scope,
    String board,
    List<LeaderboardCacheCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(leaderboardCache)
            ..where((t) => t.scope.equals(scope) & t.board.equals(board)))
          .go();
      for (final row in rows) {
        await into(leaderboardCache).insert(row);
      }
    });
  }

  /// Cached last-season winner for a (scope, board), if any.
  Future<SeasonWinnerCacheData?> winnerFor(String scope, String board) {
    return (select(seasonWinnerCache)
          ..where((t) => t.scope.equals(scope) & t.board.equals(board)))
        .getSingleOrNull();
  }

  /// Upsert the last-season winner for a (scope, board).
  Future<void> saveWinner(SeasonWinnerCacheCompanion row) {
    return into(seasonWinnerCache).insert(
      row,
      onConflict: DoUpdate(
        (_) => row,
        target: [seasonWinnerCache.scope, seasonWinnerCache.board],
      ),
    );
  }
}
