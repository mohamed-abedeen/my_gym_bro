import 'package:drift/drift.dart';

import '../app_database.dart';

part 'schedule_dao.g.dart';

/// Data access object for schedules, schedule days, and scheduled exercises.
@DriftAccessor(tables: [Schedules, ScheduleDays, ScheduledExercises])
class ScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduleDaoMixin {
  ScheduleDao(super.db);

  /// Get all schedules.
  Future<List<Schedule>> getAll() => select(schedules).get();

  /// Stream all schedules.
  Stream<List<Schedule>> watchAll() => select(schedules).watch();

  /// Get the active schedule.
  Future<Schedule?> getActive() =>
      (select(schedules)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  /// Stream the active schedule.
  Stream<Schedule?> watchActive() =>
      (select(schedules)..where((t) => t.isActive.equals(true)))
          .watchSingleOrNull();

  /// Create a new schedule.
  Future<int> createSchedule(SchedulesCompanion companion) =>
      into(schedules).insert(companion);

  /// Set a schedule as active (deactivating all others).
  Future<void> setActive(int localId) async {
    await (update(schedules)).write(
      const SchedulesCompanion(isActive: Value(false)),
    );
    await (update(schedules)..where((t) => t.localId.equals(localId))).write(
      const SchedulesCompanion(isActive: Value(true)),
    );
  }

  /// Get days for a schedule.
  Future<List<ScheduleDay>> getDays(int scheduleId) => (select(scheduleDays)
        ..where((t) => t.scheduleId.equals(scheduleId))
        ..orderBy([(t) => OrderingTerm.asc(t.dayIndex)]))
      .get();

  /// Add a day to a schedule.
  Future<int> addDay(ScheduleDaysCompanion companion) =>
      into(scheduleDays).insert(companion);

  /// Get exercises for a schedule day.
  Future<List<ScheduledExercise>> getExercises(int scheduleDayId) =>
      (select(scheduledExercises)
            ..where((t) => t.scheduleDayId.equals(scheduleDayId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Add an exercise to a schedule day.
  Future<int> addExercise(ScheduledExercisesCompanion companion) =>
      into(scheduledExercises).insert(companion);

  /// Update a schedule's fields.
  Future<void> updateSchedule(int localId, SchedulesCompanion companion) =>
      (update(schedules)..where((t) => t.localId.equals(localId)))
          .write(companion);

  /// Delete a schedule and all its days/exercises.
  Future<void> deleteSchedule(int localId) async {
    final days = await getDays(localId);
    for (final day in days) {
      await (delete(scheduledExercises)
            ..where((t) => t.scheduleDayId.equals(day.localId)))
          .go();
    }
    await (delete(scheduleDays)
          ..where((t) => t.scheduleId.equals(localId)))
        .go();
    await (delete(schedules)..where((t) => t.localId.equals(localId))).go();
  }

  /// Delete all days and exercises for a schedule (used before re-saving).
  Future<void> clearScheduleContent(int scheduleId) async {
    final days = await getDays(scheduleId);
    for (final day in days) {
      await (delete(scheduledExercises)
            ..where((t) => t.scheduleDayId.equals(day.localId)))
          .go();
    }
    await (delete(scheduleDays)
          ..where((t) => t.scheduleId.equals(scheduleId)))
        .go();
  }
}
