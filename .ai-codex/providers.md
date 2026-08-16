# Riverpod Providers — my_gym_bro

## Global providers — `lib/core/providers/providers.dart`

| Provider | Type | Returns | Notes |
|---|---|---|---|
| `databaseProvider` | `Provider<AppDatabase>` | `AppDatabase` | Overridden at startup |
| `localeProvider` | `StateProvider<Locale?>` | `Locale?` | null = system locale |
| `themeModeProvider` | `StateProvider<ThemeMode>` | `ThemeMode` | Default: `ThemeMode.dark` |
| `supabaseProvider` | `Provider<SupabaseClient?>` | `SupabaseClient?` | null if not initialised |
| `syncServiceProvider` | `Provider<SyncService>` | `SyncService` | Watches `databaseProvider` + `supabaseProvider` |
| `authNotifierProvider` | `StateNotifierProvider<AuthNotifier, AppAuthState>` | `AppAuthState` | Auth state |
| `isSupabaseAvailableProvider` | `Provider<bool>` | `bool` | `supabaseProvider != null` |
| `anatomyGenderProvider` | `StateProvider<AnatomyGender>` | `AnatomyGender` | `.male` / `.female`; default male |

---

## Workout providers — `lib/features/workout/workout_providers.dart`

### DAO providers
| Provider | Type | Returns |
|---|---|---|
| `sessionDaoProvider` | `Provider<SessionDao>` | `SessionDao` |
| `exerciseDaoProvider` | `Provider<ExerciseDao>` | `ExerciseDao` |
| `scheduleDaoProvider` | `Provider<ScheduleDao>` | `ScheduleDao` |
| `userProfileDaoProvider` | `Provider<UserProfileDao>` | `UserProfileDao` |

### Schedule providers
| Provider | Type | Returns |
|---|---|---|
| `activeScheduleProvider` | `StreamProvider<Schedule?>` | Active schedule or null |
| `allSchedulesProvider` | `StreamProvider<List<Schedule>>` | All schedules |
| `scheduleDaysProvider` | `FutureProvider.family<List<ScheduleDay>, int>` | Days for scheduleId |

### Workout Stats & derived providers
| Provider | Type | Returns |
|---|---|---|
| `recentSessionsProvider` | `StreamProvider<List<Session>>` | Last 3 completed sessions |
| `weekStripProvider` | `FutureProvider.family<List<DayData>, Locale>` | 7 DayData for current week |
| `weeklyStatsProvider` | `FutureProvider<WeeklyStats>` | Aggregated week totals + trends |
| `enrichedRecentSessionsProvider` | `FutureProvider<List<EnrichedSession>>` | Last 3 sessions with exercise details |
| `enrichedAllSessionsProvider` | `FutureProvider<List<EnrichedSession>>` | All finished sessions enriched |
| `muscleRecoveryProvider` | `FutureProvider<List<MuscleStateInfo>>` | Recovery state per muscle group |
| `streakProvider` | `FutureProvider<int>` | Consecutive training days |
| `recordsProvider` | `FutureProvider<RecordsData>` | Count of personal bests |
| `weeklyCaloriesProvider` | `FutureProvider<int>` | Estimated kcal (6 cal/min approx) |

---

## Data Models

### Workout Models (`workout_providers.dart`)
```dart
class WeeklyStats {
  double totalVolume; int totalDurationSeconds; double avgStrength;
  double? volumeTrend; double? durationTrend; double? strengthTrend;
}

class EnrichedSession {
  Session session; String workoutName; List<SessionExerciseDetail> exercises;
}
```
