import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/progress_report_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';

/// One server-generated periodic report (PRD §5.17), parsed for the Reports
/// window. Metric keys come from migration 017's `progress_report_metrics`:
/// volume_kg, sets, sessions, training_days, pr_count, challenge_points.
class PeriodReport {
  const PeriodReport({
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.metrics,
    required this.deltas,
  });

  /// 'weekly' | 'monthly'
  final String periodType;
  final DateTime periodStart;

  /// Inclusive last day of the period.
  final DateTime periodEnd;
  final Map<String, double> metrics;

  /// Same keys as [metrics]; value = this period − previous period.
  final Map<String, double> deltas;

  double metric(String key) => metrics[key] ?? 0;
  double delta(String key) => deltas[key] ?? 0;
}

Map<String, double> _numMap(Object? decoded) {
  if (decoded is! Map) return const {};
  return {
    for (final e in decoded.entries)
      if (e.value is num) e.key as String: (e.value as num).toDouble(),
  };
}

PeriodReport reportFromCacheRow(ProgressReport row) => PeriodReport(
      periodType: row.periodType,
      periodStart: row.periodStart,
      periodEnd: row.periodEnd,
      metrics: _numMap(jsonDecode(row.metricsJson)),
      deltas: _numMap(jsonDecode(row.deltasJson)),
    );

/// Parses a server row; null when malformed (skipped, never thrown).
ProgressReportsCompanion? companionFromRemote(
  Map<String, dynamic> row,
  DateTime fetchedAt,
) {
  final periodType = row['period_type'];
  final startRaw = row['period_start'];
  final endRaw = row['period_end'];
  if (periodType is! String || startRaw is! String || endRaw is! String) {
    return null;
  }
  final start = DateTime.tryParse(startRaw);
  final end = DateTime.tryParse(endRaw);
  if (start == null || end == null) return null;
  return ProgressReportsCompanion(
    periodType: Value(periodType),
    periodStart: Value(start),
    periodEnd: Value(end),
    metricsJson: Value(jsonEncode(row['metrics'] ?? const {})),
    deltasJson: Value(jsonEncode(row['deltas'] ?? const {})),
    fetchedAt: Value(fetchedAt),
  );
}

final progressReportDaoProvider = Provider<ProgressReportDao>(
  (ref) => ProgressReportDao(ref.watch(databaseProvider)),
);

/// Cache-first reports list, newest first (weekly + monthly mixed — the
/// window filters by type). Serves the local mirror when offline or signed
/// out; a successful fetch replaces the mirror wholesale
/// (LeaderboardCache doctrine). RLS scopes the select to the caller.
final periodReportsProvider =
    FutureProvider.autoDispose<List<PeriodReport>>((ref) async {
  final dao = ref.watch(progressReportDaoProvider);
  final sb = ref.watch(supabaseProvider);

  Future<List<PeriodReport>> fromCache() async =>
      [for (final r in await dao.getAll()) reportFromCacheRow(r)];

  if (sb == null || sb.auth.currentUser == null) return fromCache();
  try {
    final rows = await sb
        .from('progress_reports')
        .select('period_type, period_start, period_end, metrics, deltas')
        .order('period_start', ascending: false)
        .limit(30);
    final fetchedAt = DateTime.now();
    await dao.replaceAll([
      for (final row in rows)
        if (companionFromRemote(row, fetchedAt) != null)
          companionFromRemote(row, fetchedAt)!,
    ]);
    return fromCache();
  } on Object {
    // Offline / backend not deployed — the cache is the report history.
    return fromCache();
  }
});
