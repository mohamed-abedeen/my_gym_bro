import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_codec.dart';

/// Writes a fetched share payload into the local DB as ordinary schedule
/// rows. Resolution is id-first (the payload's catalogue id used verbatim
/// when it resolves locally or via the API cache), falling back to
/// [ProgramSeeder.resolveExerciseId] — local name match → API by name →
/// a new `custom_*` row. The IMPORT itself never requires network: offline,
/// everything lands on cached or custom rows. Only the share fetch does.
class RoutineShareImporter {
  RoutineShareImporter(AppDatabase db, this._repo, this._seeder)
      : _db = db,
        _scheduleDao = ScheduleDao(db),
        _exerciseDao = ExerciseDao(db);

  final AppDatabase _db;
  final ScheduleDao _scheduleDao;
  final ExerciseDao _exerciseDao;
  final ExerciseRepository _repo;
  final ProgramSeeder _seeder;

  /// Imports the payload as a new (inactive) schedule; returns its local id.
  Future<int> importAsNewSchedule(RoutineSharePayload payload) async {
    final resolved = await _resolveAll(payload);
    return _db.transaction(() async {
      final scheduleId = await _scheduleDao.createSchedule(
        SchedulesCompanion(
          name: Value(payload.title),
          isActive: const Value(false),
          createdAt: Value(DateTime.now()),
        ),
      );
      for (var i = 0; i < payload.days.length; i++) {
        await _writeDay(scheduleId, i, payload.days[i], resolved);
      }
      return scheduleId;
    });
  }

  /// Appends a day-share's single day to the end of [scheduleId]'s cycle.
  Future<int> appendDayToSchedule(
    RoutineSharePayload payload,
    int scheduleId,
  ) async {
    assert(payload.kind == RoutineShareKind.day, 'day payloads only');
    final resolved = await _resolveAll(payload);
    final existing = await _scheduleDao.getDays(scheduleId);
    return _db.transaction(() async {
      await _writeDay(scheduleId, existing.length, payload.days.first, resolved);
      return scheduleId;
    });
  }

  /// Resolves every exercise BEFORE the write transaction — resolution may
  /// hit the network (API backfill) and network never belongs inside a DB
  /// transaction. Keyed by instance identity (payload objects are unique).
  Future<Map<SharedExercise, String>> _resolveAll(
    RoutineSharePayload payload,
  ) async {
    final all = [
      for (final day in payload.days)
        if (!day.isRest) ...day.exercises,
    ];
    // Best-effort batch backfill of unknown catalogue ids (silent offline).
    final ids = all.map((e) => e.exerciseId).whereType<String>().toSet();
    if (ids.isNotEmpty) {
      try {
        await _repo.ensureCached(ids);
      } on Object {
        // Offline — the per-exercise fallbacks below still resolve.
      }
    }

    final resolved = <SharedExercise, String>{};
    for (final exercise in all) {
      resolved[exercise] = await _resolve(exercise);
    }
    return resolved;
  }

  Future<String> _resolve(SharedExercise exercise) async {
    final id = exercise.exerciseId;
    if (id != null) {
      final row = await _exerciseDao.findByExerciseId(id);
      if (row != null) return id;
    }
    return _seeder.resolveExerciseId(
      exercise.name,
      muscleGroup: exercise.muscleGroup,
    );
  }

  Future<void> _writeDay(
    int scheduleId,
    int dayIndex,
    SharedDay day,
    Map<SharedExercise, String> resolved,
  ) async {
    final dayId = await _scheduleDao.addDay(
      ScheduleDaysCompanion(
        scheduleId: Value(scheduleId),
        dayIndex: Value(dayIndex),
        label: Value(day.label.isEmpty ? null : day.label),
        isRestDay: Value(day.isRest),
      ),
    );
    if (day.isRest) return;
    for (var i = 0; i < day.exercises.length; i++) {
      final exercise = day.exercises[i];
      await _scheduleDao.addExercise(
        ScheduledExercisesCompanion(
          scheduleDayId: Value(dayId),
          exerciseId: Value(resolved[exercise]!),
          orderIndex: Value(i),
          targetSets: Value(exercise.sets),
          targetReps: Value(exercise.reps),
          targetDurationSeconds: Value(exercise.durationSeconds),
          targetDistance: Value(exercise.distance),
        ),
      );
    }
  }
}

final routineShareImporterProvider = Provider<RoutineShareImporter>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(exerciseRepositoryProvider);
  return RoutineShareImporter(db, repo, ProgramSeeder(db, repo));
});
