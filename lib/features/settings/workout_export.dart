import 'dart:io';
import 'dart:ui' show Rect;

import 'package:drift/drift.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// CSV export of the user's workout history — one row per logged set.
///
/// Columns: date, workout, exercise, set, weight, unit, reps, completed,
/// warmup, dropset, failure, rpe, duration_seconds, distance. Weights are
/// stored in kg and exported in the user's preferred [WeightUnit].
// ponytail: CSV only; add JSON / a format picker if users ask for it.

/// Escapes one CSV cell per RFC 4180: wrap in quotes when the cell contains
/// a comma, quote, or line break, doubling embedded quotes.
String csvEscape(String cell) {
  if (cell.contains(',') ||
      cell.contains('"') ||
      cell.contains('\n') ||
      cell.contains('\r')) {
    return '"${cell.replaceAll('"', '""')}"';
  }
  return cell;
}

String _num(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _flag(bool b) => b ? '1' : '0';

/// Builds the CSV, oldest session first. Returns `null` when no sets exist
/// (nothing to export).
Future<String?> buildWorkoutCsv(AppDatabase db, WeightUnit unit) async {
  final sets = db.workoutSets;
  final sessionExercises = db.sessionExercises;
  final sessions = db.sessions;
  final exercises = db.exercises;
  final schedules = db.schedules;

  final rows = await (db.select(sets).join([
    innerJoin(
      sessionExercises,
      sessionExercises.localId.equalsExp(sets.sessionExerciseId),
    ),
    innerJoin(
      sessions,
      sessions.localId.equalsExp(sessionExercises.sessionId),
    ),
    leftOuterJoin(
      exercises,
      exercises.exerciseId.equalsExp(sessionExercises.exerciseId),
    ),
    leftOuterJoin(
      schedules,
      schedules.localId.equalsExp(sessions.scheduleId),
    ),
  ])
        ..where(
          sets.deletedAt.isNull() &
              sessionExercises.deletedAt.isNull() &
              sessions.deletedAt.isNull(),
        )
        ..orderBy([
          OrderingTerm.asc(sessions.startedAt),
          OrderingTerm.asc(sessionExercises.orderIndex),
          OrderingTerm.asc(sets.setIndex),
        ]))
      .get();
  if (rows.isEmpty) return null;

  final unitLabel = weightUnitLabel(unit);
  final buffer = StringBuffer(
    'date,workout,exercise,set,weight,unit,reps,completed,warmup,dropset,'
    'failure,rpe,duration_seconds,distance\r\n',
  );
  for (final row in rows) {
    final set = row.readTable(sets);
    final sessionExercise = row.readTable(sessionExercises);
    final session = row.readTable(sessions);
    final exercise = row.readTableOrNull(exercises);
    final schedule = row.readTableOrNull(schedules);

    final weight = set.weight;
    final weightCell = weight == null ? '' : _num(convertFromKg(weight, unit));
    final distance = set.distance;
    final distanceCell = distance == null ? '' : _num(distance);
    final cells = [
      session.startedAt.toIso8601String().split('T').first,
      schedule?.name ?? '',
      exercise?.name ?? sessionExercise.exerciseId,
      '${set.setIndex + 1}',
      weightCell,
      unitLabel,
      set.reps?.toString() ?? '',
      _flag(set.isCompleted),
      _flag(set.isWarmup),
      _flag(set.isDropset),
      _flag(set.isFailure),
      set.rpe?.toString() ?? '',
      set.durationSeconds?.toString() ?? '',
      distanceCell,
    ];
    buffer.write('${cells.map(csvEscape).join(',')}\r\n');
  }
  return buffer.toString();
}

/// Writes [csv] to a fixed temp file (overwritten each call, mirroring
/// `ShareCardExporter.writeTempPng`) and opens the system share sheet.
///
/// Pass [sharePositionOrigin] (the tapped row's global rect) so the iPad
/// share popover has an anchor.
Future<void> shareWorkoutCsv(String csv, {Rect? sharePositionOrigin}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/mygymbro_workouts.csv');
  await file.writeAsString(csv, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
