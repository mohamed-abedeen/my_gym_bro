# Database Schema — my_gym_bro (Drift / SQLite)

**File:** `lib/core/database/app_database.dart`
**Schema version:** 4 · **DB name:** `my_gym_bro`

---

## Common columns (all sync-enabled tables)
| Column | Type | Notes |
|---|---|---|
| `localId` | `INTEGER PK AUTOINCREMENT` | Local primary key |
| `remoteId` | `TEXT NULL` | Supabase row UUID |
| `syncStatus` | `TEXT DEFAULT 'pending'` | `'pending' \| 'synced'` |
| `createdAt` | `DATETIME NULL` | |
| `updatedAt` | `DATETIME NULL` | |
| `deletedAt` | `DATETIME NULL` | Soft-delete |

---

## Tables

### `user_profiles`
One row per device/user.
| Column | Type | Default | Notes |
|---|---|---|---|
| `display_name` | TEXT NULL | | |
| `avatar_url` | TEXT NULL | | |
| `goal` | TEXT NULL | | e.g. `'build_muscle'` |
| `experience` | TEXT NULL | | e.g. `'beginner'` |
| `gender` | TEXT NULL | | `'male' \| 'female'` |
| `weight_unit` | TEXT | `'kg'` | `'kg' \| 'lbs'` |
| `preferred_language` | TEXT | `'system'` | |
| `trial_started_at` | DATETIME NULL | | |
| `subscription_status` | TEXT | `'trial'` | `'trial' \| 'active' \| 'expired'` |
| `subscription_expires_at` | DATETIME NULL | | |
| `default_rest_seconds` | INTEGER | `90` | |
| `fcm_token` | TEXT NULL | | Firebase push token |

### `exercises`
Bundled + custom exercises (seeded from `assets/exercises.json`).
| Column | Type | Notes |
|---|---|---|
| `exercise_id` | TEXT UNIQUE | External ID string e.g. `"2gPfomN"` |
| `name` | TEXT | |
| `body_parts` | TEXT NULL | JSON list |
| `target_muscles` | TEXT NULL | JSON list |
| `secondary_muscles` | TEXT NULL | JSON list |
| `equipments` | TEXT NULL | JSON list |
| `gif_url` | TEXT NULL | |
| `instructions` | TEXT NULL | JSON list |
| `muscle_group` | TEXT NULL | Display label e.g. `"Chest"` |
| `muscle_group_key` | TEXT NULL | Key for anatomy SVG mapping |
| `is_custom` | BOOLEAN | `false` |

### `schedules`
User-created training programs.
| Column | Type | Default | Notes |
|---|---|---|---|
| `name` | TEXT | | Schedule name |
| `is_active` | BOOLEAN | `false` | Only one active at a time |

### `schedule_days`
Days within a schedule (FK → `schedules.local_id`).
| Column | Type | Notes |
|---|---|---|
| `schedule_id` | INTEGER FK | |
| `day_index` | INTEGER | 0-based |
| `label` | TEXT NULL | e.g. `"Push"` |
| `is_rest_day` | BOOLEAN | `false` |

### `scheduled_exercises`
Exercises assigned to a schedule day (FK → `schedule_days.local_id`).
| Column | Type | Default | Notes |
|---|---|---|---|
| `schedule_day_id` | INTEGER FK | | |
| `exercise_id` | TEXT | | References `exercises.exercise_id` |
| `order_index` | INTEGER | | |
| `target_sets` | INTEGER | `3` | |
| `target_reps` | INTEGER | `10` | |

### `sessions`
Workout sessions (FK → `schedules.local_id`, nullable).
| Column | Type | Notes |
|---|---|---|
| `schedule_id` | INTEGER FK NULL | |
| `started_at` | DATETIME | |
| `finished_at` | DATETIME NULL | null = in-progress |
| `duration_seconds` | INTEGER NULL | |
| `total_volume` | REAL NULL | kg × reps sum |
| `notes` | TEXT NULL | |

### `session_exercises`
Exercises performed in a session (FK → `sessions.local_id`).
| Column | Type | Notes |
|---|---|---|
| `session_id` | INTEGER FK | |
| `exercise_id` | TEXT | References `exercises.exercise_id` |
| `order_index` | INTEGER | |

### `workout_sets`
Individual sets (FK → `session_exercises.local_id`).
| Column | Type | Default | Notes |
|---|---|---|---|
| `session_exercise_id` | INTEGER FK | | |
| `set_index` | INTEGER | | |
| `weight` | REAL NULL | | |
| `reps` | INTEGER NULL | | |
| `is_warmup` | BOOLEAN | `false` | |
| `is_dropset` | BOOLEAN | `false` | |
| `rpe` | INTEGER NULL | | Rate of Perceived Exertion |

### `sync_queue`
Offline change log for Supabase sync. No soft-delete columns.
| Column | Type | Notes |
|---|---|---|
| `sync_table_name` | TEXT | Target Supabase table |
| `row_id` | INTEGER | `localId` of changed row |
| `operation` | TEXT | `'insert' \| 'update' \| 'delete'` |
| `payload` | TEXT | JSON-serialised row |
| `created_at` | DATETIME | |
| `is_synced` | BOOLEAN | `false` |

### `dm_messages`
Local cache for DM messages (mirrors Supabase `dm_messages`).
| Column | Type | Default | Notes |
|---|---|---|---|
| `id` | TEXT PK | | UUID from Supabase or temp local |
| `conversation_id` | TEXT | | |
| `sender_id` | TEXT | | |
| `type` | TEXT | `'text'` | `'text' \| 'image' \| 'schedule'` |
| `body` | TEXT NULL | | Text content or JSON payload |
| `image_url` | TEXT NULL | | Signed URL for images |
| `created_at` | DATETIME | | |
| `is_mine` | BOOLEAN | `false` | Quick check if sent by me |
| `is_optimistic` | BOOLEAN | `false` | True while not synced |

---

## Relationships (ERD summary)
```
schedules (1) ──< schedule_days (1) ──< scheduled_exercises
sessions (1) ──< session_exercises (1) ──< workout_sets
sessions >── schedules (nullable)
```

---

## DAOs
| DAO | File | Tables |
|---|---|---|
| `ExerciseDao` | `daos/exercise_dao.dart` | Exercises |
| `ScheduleDao` | `daos/schedule_dao.dart` | Schedules, ScheduleDays, ScheduledExercises |
| `SessionDao` | `daos/session_dao.dart` | Sessions, SessionExercises, WorkoutSets |
| `SyncQueueDao` | `daos/sync_queue_dao.dart` | SyncQueue |
| `UserProfileDao` | `daos/user_profile_dao.dart` | UserProfiles |
| `DmDao` | `daos/dm_dao.dart` | DmMessages |

## Migration history
| Version | Change |
|---|---|
| 1 | Initial schema + all tables |
| 2 | Added indexes |
| 3 | `ALTER TABLE user_profiles ADD COLUMN gender TEXT` |
| 4 | `CREATE TABLE dm_messages` |
