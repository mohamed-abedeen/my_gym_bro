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

## Direct Messaging (DM) providers — `lib/features/community/dm/dm_providers.dart`

| Provider | Type | Returns | Notes |
|---|---|---|---|
| `dmDaoProvider` | `Provider<DmDao>` | `DmDao` | Provides access to `DmMessages` local cache |
| `dmRepositoryProvider` | `Provider<DmRepository?>` | `DmRepository?` | Handles Supabase & Drift sync (null if unauth) |
| `dmConversationsProvider` | `StreamProvider<List<DmConversation>>` | `List<DmConversation>` | Live updates from Supabase `dm_conversations` table |
| `dmMessagesProvider` | `StreamProvider.family<List<DmMessage>, String>` | `List<DmMessage>` | Realtime stream per `conversationId` |
| `activeDmConversationProvider` | `StateProvider<String?>` | `String?` | Tracks currently opened chat |

---

## Data Models

### DM Models (`dm_models.dart`)
```dart
enum DmMessageType { text, image, schedule }

class DmConversation {
  String id; String otherUserId; String otherUserName;
  String? otherAvatarUrl; String? lastMessageText; DateTime? lastMessageAt; int unreadCount;
}

class SharedSchedule { String name; List<SharedScheduleDay> days; }
class SharedScheduleDay { int dayIndex; String? label; bool isRestDay; }
```

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
