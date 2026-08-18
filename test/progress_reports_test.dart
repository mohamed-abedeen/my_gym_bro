import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/progress_report_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/workout/progress_reports_providers.dart';

/// Periodic reports client layer (§6.4a): server-row parsing, the offline
/// mirror, and the cache-first provider's offline path (null Supabase →
/// cache, never a network call).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final remoteRow = <String, dynamic>{
    'period_type': 'weekly',
    'period_start': '2026-08-10',
    'period_end': '2026-08-16',
    'metrics': {
      'volume_kg': 12500.5,
      'sets': 48,
      'sessions': 4,
      'training_days': 4,
      'pr_count': 2,
      'challenge_points': 25,
    },
    'deltas': {
      'volume_kg': 1200.0,
      'sets': -6,
      'sessions': 0,
      'training_days': 0,
      'pr_count': 2,
      'challenge_points': 25,
    },
  };

  group('companionFromRemote / reportFromCacheRow', () {
    test('round-trips a server row through the cache', () async {
      final dao = ProgressReportDao(db);
      final now = DateTime(2026, 8, 18, 9);
      await dao.replaceAll([companionFromRemote(remoteRow, now)!]);

      final report = reportFromCacheRow((await dao.getAll()).single);
      expect(report.periodType, 'weekly');
      expect(report.periodStart, DateTime(2026, 8, 10));
      expect(report.periodEnd, DateTime(2026, 8, 16));
      expect(report.metric('volume_kg'), 12500.5);
      expect(report.metric('sets'), 48);
      expect(report.delta('volume_kg'), 1200.0);
      expect(report.delta('sets'), -6);
      // Unknown keys default to 0 rather than throwing.
      expect(report.metric('nonexistent'), 0);
    });

    test('malformed rows parse to null instead of throwing', () {
      expect(
        companionFromRemote(
          {'period_type': 'weekly', 'period_start': 'garbage'},
          DateTime(2026, 8, 18),
        ),
        isNull,
      );
      expect(
        companionFromRemote(<String, dynamic>{}, DateTime(2026, 8, 18)),
        isNull,
      );
    });
  });

  group('ProgressReportDao', () {
    test('replaceAll swaps wholesale and getAll orders newest first',
        () async {
      final dao = ProgressReportDao(db);
      final now = DateTime(2026, 8, 18);

      ProgressReportsCompanion row(String type, String start, String end) =>
          companionFromRemote({
            'period_type': type,
            'period_start': start,
            'period_end': end,
            'metrics': const {'sessions': 1},
            'deltas': const {'sessions': 0},
          }, now)!;

      await dao.replaceAll([row('weekly', '2026-08-03', '2026-08-09')]);
      await dao.replaceAll([
        row('weekly', '2026-08-03', '2026-08-09'),
        row('weekly', '2026-08-10', '2026-08-16'),
        row('monthly', '2026-07-01', '2026-07-31'),
      ]);

      final all = await dao.getAll();
      expect(all, hasLength(3));
      expect(all.first.periodStart, DateTime(2026, 8, 10));
      expect(all.last.periodStart, DateTime(2026, 7));
    });
  });

  group('periodReportsProvider', () {
    test('null Supabase client serves the cache (offline-first)', () async {
      final dao = ProgressReportDao(db);
      await dao.replaceAll([
        companionFromRemote(remoteRow, DateTime(2026, 8, 18))!,
      ]);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final reports = await container.read(periodReportsProvider.future);
      expect(reports, hasLength(1));
      expect(reports.single.periodType, 'weekly');
      expect(reports.single.metric('volume_kg'), 12500.5);
    });
  });
}
