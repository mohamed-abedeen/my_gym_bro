import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'progress_report_dao.g.dart';

/// Data access for the periodic-reports offline mirror. Pure read-through
/// cache of the server's `progress_reports` (migration 017): no sync queue;
/// a successful refresh replaces the whole set.
@DriftAccessor(tables: [ProgressReports])
class ProgressReportDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressReportDaoMixin {
  ProgressReportDao(super.db);

  /// Cached reports, newest period first.
  Future<List<ProgressReport>> getAll() {
    return (select(progressReports)
          ..orderBy([(t) => OrderingTerm.desc(t.periodStart)]))
        .get();
  }

  /// Replace the whole mirror with a fresh server snapshot.
  Future<void> replaceAll(List<ProgressReportsCompanion> rows) async {
    await transaction(() async {
      await delete(progressReports).go();
      for (final row in rows) {
        await into(progressReports).insert(row);
      }
    });
  }

  /// Wipe the mirror (account deletion).
  Future<int> clearAll() => delete(progressReports).go();
}
