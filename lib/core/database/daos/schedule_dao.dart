import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

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
    await update(schedules).write(
      const SchedulesCompanion(isActive: Value(false)),
    );
    await (update(schedules)..where((t) => t.localId.equals(localId))).write(
      const SchedulesCompanion(isActive: Value(true)),
    );
  }

  /// Get a single schedule by its local ID, or null if not found.
  Future<Schedule?> getScheduleById(int localId) =>
      (select(schedules)..where((t) => t.localId.equals(localId)))
          .getSingleOrNull();

  /// Get days for a schedule.
  Future<List<ScheduleDay>> getDays(int scheduleId) => (select(scheduleDays)
        ..where((t) => t.scheduleId.equals(scheduleId))
        ..orderBy([(t) => OrderingTerm.asc(t.dayIndex)]))
      .get();

  /// Get a single schedule day by its local ID, or null if not found.
  Future<ScheduleDay?> getDayById(int dayLocalId) =>
      (select(scheduleDays)..where((t) => t.localId.equals(dayLocalId)))
          .getSingleOrNull();

  /// Stream days for a schedule — emits a new list on any insert/update/delete.
  Stream<List<ScheduleDay>> watchDays(int scheduleId) => (select(scheduleDays)
        ..where((t) => t.scheduleId.equals(scheduleId))
        ..orderBy([(t) => OrderingTerm.asc(t.dayIndex)]))
      .watch();

  /// Add a day to a schedule.
  Future<int> addDay(ScheduleDaysCompanion companion) =>
      into(scheduleDays).insert(companion);

  /// Append a rest day after the schedule's last day — the same shape the
  /// builder and share importer create, so `isRestScheduleDay` holds.
  Future<int> addRestDay(int scheduleId) async {
    final days = await getDays(scheduleId);
    final nextIndex = days.isEmpty ? 0 : days.last.dayIndex + 1;
    return addDay(
      ScheduleDaysCompanion(
        scheduleId: Value(scheduleId),
        dayIndex: Value(nextIndex),
        isRestDay: const Value(true),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Persist a new day order: each id in [orderedDayIds] takes its list
  /// position as `dayIndex`. One transaction, so [watchDays] never emits a
  /// half-applied order.
  Future<void> reorderDays(List<int> orderedDayIds) => transaction(() async {
    final now = DateTime.now();
    for (var i = 0; i < orderedDayIds.length; i++) {
      await (update(scheduleDays)
            ..where((t) => t.localId.equals(orderedDayIds[i])))
          .write(
            ScheduleDaysCompanion(
              dayIndex: Value(i),
              syncStatus: const Value('pending'),
              updatedAt: Value(now),
            ),
          );
    }
  });

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
