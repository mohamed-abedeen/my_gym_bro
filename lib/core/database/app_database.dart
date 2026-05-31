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
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get goal => text().nullable()();
  TextColumn get experience => text().nullable()();
  TextColumn get gender => text().nullable()(); // 'male' | 'female'
  /// Self-reported body weight in kilograms. Optional — calorie estimates
  /// fall back to a 70kg default when null.
  RealColumn get bodyWeightKg => real().nullable()();
  /// Self-reported height in centimetres. Optional — kept alongside body
  /// weight for future BMI / TDEE features.
  RealColumn get heightCm => real().nullable()();
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
  /// 'supportive' | 'balanced' | 'bold' | 'savage'
  TextColumn get notificationTone =>
      text().withDefault(const Constant('balanced'))();
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
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
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
  // Cardio planning
  IntColumn get targetDurationSeconds => integer().nullable()();
  RealColumn get targetDistance => real().nullable()();
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
  BoolColumn get isFailure => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get rpe => integer().nullable()();
  // Cardio tracking
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distance => real().nullable()();
  RealColumn get speed => real().nullable()();
  RealColumn get incline => real().nullable()();
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

/// Local cache of the current user's outgoing follow edges (who I follow).
///
/// Mirrors Supabase `public.follows`. [remoteId] holds the client-generated
/// UUID used as the row's Supabase `id`, so an unfollow can target that exact
/// row on delete-sync without first reading it back from the server. This is
/// the device's offline source of truth for "am I following X?" and powers
/// optimistic follow/unfollow.
class Follows extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The current user's auth id (the follower).
  TextColumn get followerId => text()();

  /// The followed user's auth id.
  TextColumn get followeeId => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {followerId, followeeId},
      ];
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
    Follows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Factory constructor that opens a Drift database.
  factory AppDatabase.create() {
    final queryExecutor = driftDatabase(name: 'my_gym_bro');
    return AppDatabase(queryExecutor);
  }

  @override
  int get schemaVersion => 15;

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
      // (v4 previously created the dm_messages table; DMs were removed in v13,
      //  so the table is no longer created here and is dropped below.)
      if (from < 5) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN difficulty TEXT',
        );
      }
      if (from < 6) {
        await customStatement(
          "ALTER TABLE user_profiles ADD COLUMN notification_tone TEXT NOT NULL DEFAULT 'balanced'",
        );
      }
      if (from < 7) {
        await customStatement(
          'ALTER TABLE workout_sets ADD COLUMN duration_seconds INTEGER',
        );
        await customStatement(
          'ALTER TABLE workout_sets ADD COLUMN distance REAL',
        );
        await customStatement(
          'ALTER TABLE workout_sets ADD COLUMN speed REAL',
        );
        await customStatement(
          'ALTER TABLE workout_sets ADD COLUMN incline REAL',
        );
        await customStatement(
          'ALTER TABLE scheduled_exercises ADD COLUMN target_duration_seconds INTEGER',
        );
        await customStatement(
          'ALTER TABLE scheduled_exercises ADD COLUMN target_distance REAL',
        );
      }
      if (from < 8) {
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN banner_url TEXT',
        );
      }
      if (from < 9) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 10) {
        await customStatement(
          'ALTER TABLE workout_sets ADD COLUMN is_failure INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 11) {
        // Persist set completion so crash-recovery + cardio volume math
        // stop inferring "complete" from `weight != null && reps != null`,
        // which mis-classifies warm-ups and cardio without weight.
        // Existing rows: mark completed when they have either weight+reps
        // or any cardio signal — best-effort backfill of inferred state.
        await customStatement(
          'ALTER TABLE workout_sets ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE workout_sets SET is_completed = 1 WHERE '
          '(weight IS NOT NULL AND reps IS NOT NULL) '
          'OR duration_seconds IS NOT NULL '
          'OR distance IS NOT NULL',
        );
      }
      if (from < 12) {
        // Body weight + height — feed the calorie estimator. Onboarding
        // already collects these but they were dropped on signup before.
        await _addColumnIfMissing('user_profiles', 'body_weight_kg', 'REAL');
        await _addColumnIfMissing('user_profiles', 'height_cm', 'REAL');
      }
      if (from < 13) {
        // DMs removed — drop the local cache table if it exists.
        await customStatement('DROP TABLE IF EXISTS dm_messages');
      }
      if (from < 14) {
        // Exercise source switched from the bundled ExerciseDB JSON to the
        // WorkoutX API. The old bundled rows use a different id scheme
        // ("2gPfomN") than WorkoutX ("0025"), so wipe the seeded catalogue;
        // it re-caches on demand from the API as the user browses/logs.
        // User-created custom exercises (is_custom = 1) are preserved.
        await customStatement('DELETE FROM exercises WHERE is_custom = 0');
      }
      if (from < 15) {
        // Social graph — local cache of the current user's outgoing follows.
        await m.createTable(follows);
      }
    },
  );

  /// True if [table] already has [column]. Keeps `ADD COLUMN` migrations
  /// idempotent — a database that acquired a column before its migration was
  /// written would otherwise crash with "duplicate column".
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  Future<void> _addColumnIfMissing(
      String table, String column, String definition) async {
    if (await _hasColumn(table, column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

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
}
