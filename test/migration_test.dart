import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';

/// Opens a raw executor at [version] so we can hand-build an old-schema
/// database file before AppDatabase's onUpgrade runs over it.
class _SchemaStamp extends QueryExecutorUser {
  _SchemaStamp(this.version);
  final int version;

  @override
  int get schemaVersion => version;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

/// The v11-era shape of the tables the 11→16 migration steps touch.
/// user_profiles lacks body_weight_kg / height_cm (added in v12); the
/// exercise tables were already at their current shape by v11.
const _v11Ddl = [
  '''
  CREATE TABLE user_profiles (
    local_id INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER, updated_at INTEGER, deleted_at INTEGER,
    display_name TEXT, avatar_url TEXT, banner_url TEXT,
    goal TEXT, experience TEXT, gender TEXT,
    weight_unit TEXT NOT NULL DEFAULT 'kg',
    preferred_language TEXT NOT NULL DEFAULT 'system',
    trial_started_at INTEGER,
    subscription_status TEXT NOT NULL DEFAULT 'trial',
    subscription_expires_at INTEGER,
    default_rest_seconds INTEGER NOT NULL DEFAULT 90,
    fcm_token TEXT,
    notification_tone TEXT NOT NULL DEFAULT 'balanced'
  )''',
  '''
  CREATE TABLE exercises (
    local_id INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER, updated_at INTEGER, deleted_at INTEGER,
    exercise_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    body_parts TEXT, target_muscles TEXT, secondary_muscles TEXT,
    equipments TEXT, gif_url TEXT, instructions TEXT,
    muscle_group TEXT, muscle_group_key TEXT, difficulty TEXT,
    is_custom INTEGER NOT NULL DEFAULT 0,
    usage_count INTEGER NOT NULL DEFAULT 0,
    is_favorite INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE session_exercises (
    local_id INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER, updated_at INTEGER, deleted_at INTEGER,
    session_id INTEGER NOT NULL,
    exercise_id TEXT NOT NULL,
    order_index INTEGER NOT NULL
  )''',
  '''
  CREATE TABLE scheduled_exercises (
    local_id INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER, updated_at INTEGER, deleted_at INTEGER,
    schedule_day_id INTEGER NOT NULL,
    exercise_id TEXT NOT NULL,
    order_index INTEGER NOT NULL,
    target_sets INTEGER NOT NULL DEFAULT 3,
    target_reps INTEGER NOT NULL DEFAULT 10,
    target_duration_seconds INTEGER,
    target_distance REAL
  )''',
];

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mgb_migration_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('upgrade from v11 reaches v16 with columns, follows table and '
      'catalogue wipe keeping referenced rows', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}old.db');

    // ── Build the old (v11) database by hand ──
    final old = NativeDatabase(file);
    await old.ensureOpen(_SchemaStamp(11));
    for (final ddl in _v11Ddl) {
      await old.runCustom(ddl);
    }
    // Catalogue rows: one referenced by history, one by a routine, one
    // unreferenced (must be wiped), one custom unreferenced (must survive).
    await old.runCustom(
      'INSERT INTO exercises (exercise_id, name, is_custom) VALUES '
      "('hist01', 'bench press', 0), "
      "('sched01', 'deadlift', 0), "
      "('orphan01', 'cable fly', 0), "
      "('custom01', 'my curl', 1)",
    );
    await old.runCustom(
      'INSERT INTO session_exercises (session_id, exercise_id, order_index) '
      "VALUES (1, 'hist01', 0)",
    );
    await old.runCustom(
      'INSERT INTO scheduled_exercises (schedule_day_id, exercise_id, '
      "order_index) VALUES (1, 'sched01', 0)",
    );
    await old.runCustom(
      "INSERT INTO user_profiles (display_name) VALUES ('bro')",
    );
    await old.close();

    // ── Reopen through AppDatabase → onUpgrade(11 → 16) runs ──
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    Future<List<QueryRow>> query(String sql) => db.customSelect(sql).get();

    // Migration completed and stamped the current version.
    final version = await query('PRAGMA user_version');
    expect(version.single.read<int>('user_version'), 16);

    // v12 _addColumnIfMissing columns were added to user_profiles.
    final profileCols = (await query('PRAGMA table_info(user_profiles)'))
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(profileCols, containsAll(['body_weight_kg', 'height_cm']));

    // v15 created the follows table.
    final tables = (await query(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(tables, contains('follows'));

    // v14/v16 catalogue wipe: referenced + custom rows survive, the
    // unreferenced catalogue row is deleted.
    final remaining =
        (await db.select(db.exercises).get()).map((e) => e.exerciseId).toSet();
    expect(remaining, {'hist01', 'sched01', 'custom01'});

    // The pre-existing profile row survived and the new columns read null.
    final profile = await (db.select(db.userProfiles)..limit(1)).getSingle();
    expect(profile.displayName, 'bro');
    expect(profile.bodyWeightKg, isNull);
    expect(profile.heightCm, isNull);
  });

  test('running the same upgrade twice is idempotent (no duplicate column '
      'crash)', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}twice.db');

    final old = NativeDatabase(file);
    await old.ensureOpen(_SchemaStamp(11));
    for (final ddl in _v11Ddl) {
      await old.runCustom(ddl);
    }
    // Simulate a version-inconsistent DB: the v12 columns already exist
    // even though user_version says 11 — _addColumnIfMissing must not crash.
    await old.runCustom('ALTER TABLE user_profiles ADD COLUMN body_weight_kg REAL');
    await old.runCustom('ALTER TABLE user_profiles ADD COLUMN height_cm REAL');
    await old.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').get();
    expect(version.single.read<int>('user_version'), 16);
  });

  test('fresh createAll builds every table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Touching each table fails loudly if createAll missed one.
    for (final table in db.allTables) {
      await db.select(table).get();
    }
    expect(db.allTables.length, 10);
  });
}
