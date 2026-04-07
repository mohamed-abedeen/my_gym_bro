import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────
// T A B L E S
// ─────────────────────────────────────────────

/// User profile — one row per device.
class UserProfiles extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get goal => text().nullable()();
  TextColumn get experience => text().nullable()();
  TextColumn get gender => text().nullable()(); // 'male' | 'female'
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();
  TextColumn get preferredLanguage =>
      text().withDefault(const Constant('system'))();
  DateTimeColumn get trialStartedAt => dateTime().nullable()();
  TextColumn get subscriptionStatus =>
      text().withDefault(const Constant('trial'))();
  DateTimeColumn get subscriptionExpiresAt => dateTime().nullable()();
  IntColumn get defaultRestSeconds =>
      integer().withDefault(const Constant(90))();
  TextColumn get fcmToken => text().nullable()();
}

/// Bundled + custom exercises.
class Exercises extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get exerciseId => text().unique()();
  TextColumn get name => text()();
  TextColumn get bodyParts => text().nullable()();
  TextColumn get targetMuscles => text().nullable()();
  TextColumn get secondaryMuscles => text().nullable()();
  TextColumn get equipments => text().nullable()();
  TextColumn get gifUrl => text().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get muscleGroup => text().nullable()();
  TextColumn get muscleGroupKey => text().nullable()();
  /// 'beginner' | 'intermediate' | 'advanced'
  TextColumn get difficulty => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

/// Training schedules (user-created programs).
class Schedules extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
}

/// Days within a schedule.
class ScheduleDays extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get scheduleId => integer().references(Schedules, #localId)();
  IntColumn get dayIndex => integer()();
  TextColumn get label => text().nullable()();
  BoolColumn get isRestDay => boolean().withDefault(const Constant(false))();
}

/// Exercises assigned to a schedule day.
class ScheduledExercises extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get scheduleDayId => integer().references(ScheduleDays, #localId)();
  TextColumn get exerciseId => text()(); // exerciseId string e.g. "2gPfomN"
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().withDefault(const Constant(10))();
}

/// Workout sessions (completed or in-progress).
class Sessions extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get scheduleId =>
      integer().nullable().references(Schedules, #localId)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get totalVolume => real().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Exercises performed in a session.
class SessionExercises extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get sessionId => integer().references(Sessions, #localId)();
  TextColumn get exerciseId => text()(); // exerciseId string
  IntColumn get orderIndex => integer()();
}

/// Individual sets within a session exercise.
class WorkoutSets extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get sessionExerciseId =>
      integer().references(SessionExercises, #localId)();
  IntColumn get setIndex => integer()();
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  BoolColumn get isDropset => boolean().withDefault(const Constant(false))();
  IntColumn get rpe => integer().nullable()();
}

/// Offline sync queue for pending changes.
class SyncQueue extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get syncTableName =>
      text()(); // renamed to avoid Table.tableName conflict
  IntColumn get rowId => integer()();
  TextColumn get operation => text()(); // 'insert', 'update', 'delete'
  TextColumn get payload => text()(); // JSON serialised row
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

/// Local cache for DM messages (mirrors Supabase dm_messages).
/// Used for optimistic sends and brief offline resilience.
class DmMessages extends Table {
  // UUID from Supabase (or a temp client-generated UUID while optimistic)
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  // 'text' | 'image' | 'schedule'
  TextColumn get type => text().withDefault(const Constant('text'))();
  // text content, or JSON payload for schedule type
  TextColumn get body => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isMine => boolean().withDefault(const Constant(false))();

  /// true while the row has not yet been confirmed by Supabase
  BoolColumn get isOptimistic => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────
// D A T A B A S E
// ─────────────────────────────────────────────

@DriftDatabase(
  tables: [
    UserProfiles,
    Exercises,
    Schedules,
    ScheduleDays,
    ScheduledExercises,
    Sessions,
    SessionExercises,
    WorkoutSets,
    SyncQueue,
    DmMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes(m);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _createIndexes(m);
      }
      if (from < 3) {
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN gender TEXT',
        );
      }
      if (from < 4) {
        await m.createTable(dmMessages);
      }
      if (from < 5) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN difficulty TEXT',
        );
      }
    },
  );

  Future<void> _createIndexes(Migrator m) async {
    // SessionExercises.sessionId — queried every time we load a session's exercises
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_session_exercises_session_id ON session_exercises (session_id)',
    );
    // WorkoutSets.sessionExerciseId — queried every time we load sets for an exercise
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_workout_sets_se_id ON workout_sets (session_exercise_id)',
    );
    // Sessions.finishedAt — filtered in date range queries
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_finished_at ON sessions (finished_at)',
    );
    // Sessions.startedAt — filtered and ordered frequently
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions (started_at)',
    );
    // Exercises.exerciseId — unique lookup (likely auto-indexed, but explicit is safer)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_exercises_exercise_id ON exercises (exercise_id)',
    );
    // SyncQueue.isSynced — filtered for pending items
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_is_synced ON sync_queue (is_synced)',
    );
    // ScheduleDays.scheduleId — queried when loading schedule days
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schedule_days_schedule_id ON schedule_days (schedule_id)',
    );
    // ScheduledExercises.scheduleDayId — queried when loading day exercises
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_scheduled_exercises_day_id ON scheduled_exercises (schedule_day_id)',
    );
  }

  /// Factory that opens a Drift database.
  static AppDatabase create() {
    final queryExecutor = driftDatabase(name: 'my_gym_bro');
    return AppDatabase(queryExecutor);
  }
}
