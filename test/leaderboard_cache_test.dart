import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/leaderboard_dao.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';

void main() {
  group('nextResetUtc', () {
    test('weekly: mid-week counts to next Monday 00:00 UTC', () {
      // Thursday 2026-08-13 15:30 UTC → Monday 2026-08-17 00:00 UTC.
      final next = nextResetUtc(
        LeaderboardBoard.weekly,
        nowUtc: DateTime.utc(2026, 8, 13, 15, 30),
      );
      expect(next, DateTime.utc(2026, 8, 17));
    });

    test('weekly: on Monday 00:00 the reset is the FOLLOWING Monday', () {
      final next = nextResetUtc(
        LeaderboardBoard.weekly,
        nowUtc: DateTime.utc(2026, 8, 17),
      );
      expect(next, DateTime.utc(2026, 8, 24));
    });

    test('weekly: Sunday 23:59 is one minute from reset', () {
      final next = nextResetUtc(
        LeaderboardBoard.weekly,
        nowUtc: DateTime.utc(2026, 8, 16, 23, 59),
      )!;
      expect(next, DateTime.utc(2026, 8, 17));
      expect(
        next.difference(DateTime.utc(2026, 8, 16, 23, 59)),
        const Duration(minutes: 1),
      );
    });

    test('monthly: counts to the 1st of next month, incl. December rollover',
        () {
      expect(
        nextResetUtc(
          LeaderboardBoard.monthly,
          nowUtc: DateTime.utc(2026, 8, 17, 12),
        ),
        DateTime.utc(2026, 9),
      );
      expect(
        nextResetUtc(
          LeaderboardBoard.monthly,
          nowUtc: DateTime.utc(2026, 12, 31, 23),
        ),
        DateTime.utc(2027),
      );
    });

    test('all-time never resets', () {
      expect(nextResetUtc(LeaderboardBoard.allTime), isNull);
    });
  });

  group('LeaderboardDao', () {
    late AppDatabase db;
    late LeaderboardDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = LeaderboardDao(db);
    });

    tearDown(() => db.close());

    LeaderboardCacheCompanion row(String scope, String board, int rank) {
      return LeaderboardCacheCompanion.insert(
        scope: scope,
        board: board,
        rank: rank,
        name: 'user$rank',
        fetchedAt: DateTime.now(),
      );
    }

    test('replaceRows replaces only its own (scope, board) slice', () async {
      await dao.replaceRows('global', 'weekly',
          [row('global', 'weekly', 1), row('global', 'weekly', 2)]);
      await dao.replaceRows('global', 'monthly', [row('global', 'monthly', 1)]);

      // A refresh of the weekly slice must not touch monthly.
      await dao.replaceRows('global', 'weekly', [row('global', 'weekly', 1)]);

      expect(await dao.rowsFor('global', 'weekly'), hasLength(1));
      expect(await dao.rowsFor('global', 'monthly'), hasLength(1));
      expect(await dao.rowsFor('friends', 'weekly'), isEmpty);
    });

    test('rowsFor returns rank order', () async {
      await dao.replaceRows('rivals', 'weekly', [
        row('rivals', 'weekly', 3),
        row('rivals', 'weekly', 1),
        row('rivals', 'weekly', 2),
      ]);
      final rows = await dao.rowsFor('rivals', 'weekly');
      expect([for (final r in rows) r.rank], [1, 2, 3]);
    });

    test('saveWinner upserts on (scope, board)', () async {
      await dao.saveWinner(SeasonWinnerCacheCompanion.insert(
        scope: 'global',
        board: 'weekly',
        name: 'first',
        fetchedAt: DateTime.now(),
      ));
      await dao.saveWinner(SeasonWinnerCacheCompanion.insert(
        scope: 'global',
        board: 'weekly',
        name: 'second',
        avatarUrl: const Value('http://x/a.png'),
        fetchedAt: DateTime.now(),
      ));

      final winner = await dao.winnerFor('global', 'weekly');
      expect(winner!.name, 'second');
      expect(await dao.winnerFor('global', 'monthly'), isNull);
    });
  });
}
