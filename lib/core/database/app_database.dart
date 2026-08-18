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

  /// Unique @handle, the only social lookup key (lowercase a-z/0-9/_, 3–20).
  /// Null until claimed; uniqueness is enforced server-side on sync.
  TextColumn get username => text().nullable()();
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
  /// Selected cosmetic skin id (ids from the static catalog in
  /// skin_provider.dart). Null = default body. Synced like any other
  /// profile field; lock-gating happens at selection time.
  TextColumn get activeSkinId => text().nullable()();
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
/// Local cache of the current user's friendship edges — requests in and out,
/// accepted bros, and blocked pairs (both directions, mirroring the Supabase
/// `friendships` rows the user is a side of).
class Friendships extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Auth id of the user who sent the request.
  TextColumn get requesterId => text()();

  /// Auth id of the user who received it.
  TextColumn get addresseeId => text()();

  /// 'pending' | 'accepted' | 'blocked'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Auth id of whichever side blocked — set exactly when status is 'blocked'.
  TextColumn get blockedBy => text().nullable()();

  /// When the addressee accepted (declines delete the row instead).
  DateTimeColumn get respondedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {requesterId, addresseeId},
      ];
}

/// Local cache of challenges (PRD §5.9) — the curated daily plus community
/// challenges snapshotted from Supabase, and the user's own creations before
/// they push. [remoteId] is the client-generated UUID used as the Supabase
/// `id` (server rows carry theirs), so joins/reports can target the row
/// without a read-back.
class Challenges extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 'curated' | 'community'
  TextColumn get source => text()();

  /// Auth id of the creator — null for curated.
  TextColumn get creatorId => text().nullable()();

  /// Curated template id — the client localizes known ids via ARB keys and
  /// falls back to [title]/[description] for unknown ones.
  TextColumn get templateId => text().nullable()();

  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// 'volume' | 'sessions' | 'sets' | 'streak' | 'custom'
  TextColumn get goalType => text()();
  RealColumn get goalValue => real()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  IntColumn get points => integer().withDefault(const Constant(0))();

  /// 'active' | 'ended' | 'hidden' | 'pending_review'
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {remoteId},
      ];
}

/// Local cache of the current user's challenge participation rows. Progress
/// is recomputed locally from sessions/sets and synced up; completion and
/// points are server-confirmed on refresh (the award trigger is the source
/// of truth — see 04-BACKEND.md §3.2).
class ChallengeParticipants extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Supabase `challenges.id` this row belongs to.
  TextColumn get challengeRemoteId => text()();

  /// Auth id of the participant (the current user).
  TextColumn get userId => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  DateTimeColumn get joinedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get pointsAwarded => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {challengeRemoteId, userId},
      ];
}

/// Offline cache of leaderboard rows, one snapshot per (scope, board).
/// Read-only mirror of the `leaderboard_*` RPC results — no sync queue; a
/// fresh fetch replaces the (scope, board) slice wholesale.
class LeaderboardCache extends Table {
  IntColumn get localId => integer().autoIncrement()();

  /// 'rivals' | 'global' | 'friends'
  TextColumn get scope => text()();

  /// 'weekly' | 'monthly' | 'all_time'
  TextColumn get board => text()();
  IntColumn get rank => integer()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().nullable()();
  RealColumn get volume => real().withDefault(const Constant(0))();
  RealColumn get composite => real().withDefault(const Constant(0))();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  DateTimeColumn get fetchedAt => dateTime()();
}

/// Offline cache of the last season winner per (scope, board) — feeds the
/// winner banner. One row per (scope, board), replaced on refresh.
class SeasonWinnerCache extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get scope => text()();
  TextColumn get board => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get seasonStart => dateTime().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {scope, board},
      ];
}

/// Offline mirror of server `skin_ownership` — earned/purchased skin grants.
/// Server-authoritative (purchase-skin verify / evaluate_earned_skins), so no
/// sync queue: a successful refresh replaces the whole set, and a verified
/// purchase upserts its row directly.
class SkinOwnerships extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get skinId => text().unique()();

  /// 'earned' | 'purchased'
  TextColumn get source => text()();
  DateTimeColumn get acquiredAt => dateTime().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
}

/// Offline mirror of server `progress_reports` — weekly/monthly period
/// summaries with deltas, generated server-side (migration 017). Read-only
/// cache (LeaderboardCache doctrine): no sync queue; a refresh replaces the
/// whole set. metrics/deltas are the server's jsonb, stored verbatim.
class ProgressReports extends Table {
  IntColumn get localId => integer().autoIncrement()();

  /// 'weekly' | 'monthly'
  TextColumn get periodType => text()();
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();
  TextColumn get metricsJson => text()();
  TextColumn get deltasJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {periodType, periodStart},
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
    Friendships,
    Challenges,
    ChallengeParticipants,
    LeaderboardCache,
    SeasonWinnerCache,
    SkinOwnerships,
    ProgressReports,
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
  int get schemaVersion => 21;

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
        await _addColumnIfMissing('user_profiles', 'gender', 'TEXT');
      }
      // (v4 previously created the dm_messages table; DMs were removed in v13,
      //  so the table is no longer created here and is dropped below.)
      if (from < 5) {
        await _addColumnIfMissing('exercises', 'difficulty', 'TEXT');
      }
      if (from < 6) {
        await _addColumnIfMissing(
          'user_profiles',
          'notification_tone',
          "TEXT NOT NULL DEFAULT 'balanced'",
        );
      }
      if (from < 7) {
        await _addColumnIfMissing('workout_sets', 'duration_seconds', 'INTEGER');
        await _addColumnIfMissing('workout_sets', 'distance', 'REAL');
        await _addColumnIfMissing('workout_sets', 'speed', 'REAL');
        await _addColumnIfMissing('workout_sets', 'incline', 'REAL');
        await _addColumnIfMissing(
          'scheduled_exercises', 'target_duration_seconds', 'INTEGER');
        await _addColumnIfMissing(
          'scheduled_exercises', 'target_distance', 'REAL');
      }
      if (from < 8) {
        await _addColumnIfMissing('user_profiles', 'banner_url', 'TEXT');
      }
      if (from < 9) {
        await _addColumnIfMissing(
          'exercises', 'usage_count', 'INTEGER NOT NULL DEFAULT 0');
        await _addColumnIfMissing(
          'exercises', 'is_favorite', 'INTEGER NOT NULL DEFAULT 0');
      }
      if (from < 10) {
        await _addColumnIfMissing(
          'workout_sets', 'is_failure', 'INTEGER NOT NULL DEFAULT 0');
      }
      if (from < 11) {
        // Persist set completion so crash-recovery + cardio volume math
        // stop inferring "complete" from `weight != null && reps != null`,
        // which mis-classifies warm-ups and cardio without weight.
        // Existing rows: mark completed when they have either weight+reps
        // or any cardio signal — best-effort backfill of inferred state.
        await _addColumnIfMissing(
          'workout_sets', 'is_completed', 'INTEGER NOT NULL DEFAULT 0');
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
        // User-created custom exercises (is_custom = 1) are preserved, as
        // are rows the user's history/routines reference (see helper).
        await _deleteUnreferencedCatalogue();
      }
      // (v15 previously created the follows table; the one-way follow model
      //  was superseded by friendships in v17, so the table is no longer
      //  created here and is dropped below.)
      if (from < 16) {
        // Exercise source switched from the WorkoutX API to the ExerciseDB
        // OSS v1 API (testing until the ExerciseDB.io license is bought).
        // WorkoutX ids ("0025") don't exist in the ExerciseDB scheme
        // ("2gPfomN"), so wipe the cached catalogue; it re-syncs from the
        // API on the next browse. Custom exercises are preserved, as are
        // rows the user's history/routines reference (see helper).
        await _deleteUnreferencedCatalogue();
      }
      if (from < 17) {
        // Bros Phase B — friends graph (PRD §5.6). @username claim on the
        // profile plus a local cache of friendship edges (requests in/out,
        // accepted, blocked). The one-way follows cache is superseded and
        // dropped; the server-side follows table goes in migration 012.
        await _addColumnIfMissing('user_profiles', 'username', 'TEXT');
        if (!await _hasTable('friendships')) {
          await m.createTable(friendships);
        }
        await customStatement('DROP TABLE IF EXISTS follows');
      }
      if (from < 18) {
        // Phase 4 — challenges (PRD §5.9): local mirror of the server's
        // challenges plus the user's participation rows, so the Bros tab's
        // challenge list, progress, and completions all work offline.
        if (!await _hasTable('challenges')) {
          await m.createTable(challenges);
        }
        if (!await _hasTable('challenge_participants')) {
          await m.createTable(challengeParticipants);
        }
      }
      if (from < 19) {
        // Phase 5 — leaderboard offline caches (PRD §5.11): ranked rows per
        // scope×board plus the last season winner, so the Bros tab's
        // leaderboard renders offline instead of an empty state.
        if (!await _hasTable('leaderboard_cache')) {
          await m.createTable(leaderboardCache);
        }
        if (!await _hasTable('season_winner_cache')) {
          await m.createTable(seasonWinnerCache);
        }
      }
      if (from < 20) {
        // Phase 6.2 — skins economy (PRD §5.10): the selected skin joins the
        // synced profile, and server-granted ownership (earned/purchased)
        // gets a local mirror so the gallery renders offline.
        await _addColumnIfMissing('user_profiles', 'active_skin_id', 'TEXT');
        if (!await _hasTable('skin_ownerships')) {
          await m.createTable(skinOwnerships);
        }
      }
      if (from < 21) {
        // Phase 6.4a — periodic reports (PRD §5.17): local mirror of the
        // server-generated weekly/monthly summaries so the Reports window
        // renders offline.
        if (!await _hasTable('progress_reports')) {
          await m.createTable(progressReports);
        }
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

  /// Wipe cached (non-custom) catalogue rows on an exercise-source switch —
  /// but keep any row the user's workout history (`session_exercises`) or
  /// routines (`scheduled_exercises`) references, so their names/details
  /// keep rendering instead of degrading to a generic "Exercise" until the
  /// rate-limited API re-caches them.
  ///
  /// Kept legacy rows are then flagged `is_custom = 1` so they stop counting
  /// as catalogue: `ExerciseDao.countCatalogue` feeds the sync's "cache is
  /// complete" shortcut, and off-scheme leftovers counted there would make
  /// the sync declare itself done before fetching the catalogue's tail. Rows
  /// whose id does exist in the new scheme self-heal — the sync's upsert
  /// (`ExerciseDao.cacheAll`) rewrites them with `is_custom = 0`. At this
  /// point in the migration every surviving non-custom row IS a kept legacy
  /// row, so the blanket UPDATE is safe. Plain DELETE/UPDATE — naturally
  /// idempotent, safe to re-run.
  Future<void> _deleteUnreferencedCatalogue() async {
    await customStatement(
      'DELETE FROM exercises WHERE is_custom = 0 '
      'AND exercise_id NOT IN (SELECT exercise_id FROM session_exercises) '
      'AND exercise_id NOT IN (SELECT exercise_id FROM scheduled_exercises)',
    );
    await customStatement('UPDATE exercises SET is_custom = 1');
  }

  /// True if [table] exists. Keeps `createTable` migrations idempotent for a
  /// database that already created the table at an inconsistent version.
  Future<bool> _hasTable(String table) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '$table'",
    ).get();
    return rows.isNotEmpty;
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
