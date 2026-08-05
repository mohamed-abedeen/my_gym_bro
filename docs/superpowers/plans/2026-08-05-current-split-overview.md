# Current Split Overview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Workout-card pencil with a search entry that opens a reference-faithful current-split overview inside the Workout tab while preserving the shared bottom navigation.

**Architecture:** A small Workout-tab state provider selects between the existing Workout dashboard and a new `CurrentSplitScreen`. A pure aggregation model converts reactive Drift schedule/day/exercise data into metrics, row summaries, and anatomy highlights; the screen consumes that view model and reuses `AnatomyBody`, app tokens, reports/status/settings destinations, and the existing schedule builder.

**Tech Stack:** Flutter, Dart 3.9, Riverpod 2.6, Drift 2.18, go_router 13, Flutter localization ARB, flutter_test, mocktail

---

## File Map

- Create `lib/features/workout/current_split/current_split_models.dart`: immutable overview/day models and pure aggregation logic.
- Create `lib/features/workout/current_split/current_split_providers.dart`: selected-overview state and reactive Drift-backed overview provider.
- Create `lib/features/workout/current_split/current_split_screen.dart`: reference-faithful UI, actions, states, and accessibility.
- Create `test/current_split_models_test.dart`: metric/order/muscle aggregation unit tests.
- Create `test/current_split_screen_test.dart`: entry, layout, interactions, disabled actions, states, and overflow tests.
- Create `test/schedule_dao_current_split_test.dart`: reactive schedule/exercise query test.
- Modify `lib/core/database/daos/schedule_dao.dart`: watch one schedule and all scheduled exercises for it.
- Modify `lib/features/workout/workout_screen.dart`: dashboard/detail switch and search-button entry.
- Modify `lib/features/scaffold/my_gym_bro_scaffold.dart`: system-back handling for the in-tab overview.
- Modify `lib/features/schedule/schedule_builder_screen.dart`: optional initial training-day selection.
- Modify `lib/core/router/app_router.dart`: typed schedule-builder arguments while retaining existing callers.
- Modify `lib/l10n/app_en.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`: all new strings and plural forms.
- Regenerate `lib/l10n/app_localizations*.dart` with Flutter gen-l10n.

## Task 1: Pure Current-Split Aggregation

**Files:**
- Create: `lib/features/workout/current_split/current_split_models.dart`
- Create: `test/current_split_models_test.dart`

- [ ] **Step 1: Write failing aggregation tests**

Create test fixtures for one `Schedule`, three ordered `ScheduleDay` rows (Push, Rest, Pull), four `ScheduledExercise` rows, and matching `Exercise` rows. Assert exact totals, stored day order, rest-day retention, planned-muscle groups, missing exercise metadata fallback, and zero values for an empty plan.

```dart
test('aggregates totals and keeps rest days in dayIndex order', () {
  final result = buildCurrentSplitOverview(
    schedule: schedule,
    days: [pullDay, pushDay, restDay],
    scheduledExercises: scheduled,
    exercises: exercises,
  );

  expect(result.days.map((d) => d.day.localId), [pushDay.localId, restDay.localId, pullDay.localId]);
  expect(result.trainingDayCount, 2);
  expect(result.restDayCount, 1);
  expect(result.totalExerciseCount, 4);
  expect(result.totalPlannedSets, 13);
  expect(result.plannedMuscleGroups, containsAll(<String>{'Chest', 'Triceps', 'Lats'}));
  expect(result.days[1].isRestDay, isTrue);
});

test('retains scheduled rows when exercise metadata is missing', () {
  final result = buildCurrentSplitOverview(
    schedule: schedule,
    days: [pushDay],
    scheduledExercises: [missingMetadataExercise],
    exercises: const [],
  );

  expect(result.totalExerciseCount, 1);
  expect(result.days.single.exerciseCount, 1);
  expect(result.days.single.muscleGroups, isEmpty);
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run: `flutter test test/current_split_models_test.dart`

Expected: FAIL because `current_split_models.dart` and `buildCurrentSplitOverview` do not exist.

- [ ] **Step 3: Implement the immutable models and pure builder**

Use these public interfaces exactly:

```dart
class CurrentSplitDaySummary {
  const CurrentSplitDaySummary({
    required this.day,
    required this.exerciseCount,
    required this.plannedSetCount,
    required this.muscleGroups,
  });

  final ScheduleDay day;
  final int exerciseCount;
  final int plannedSetCount;
  final List<String> muscleGroups;
  bool get isRestDay => day.isRestDay;
}

class CurrentSplitOverviewData {
  const CurrentSplitOverviewData({
    required this.schedule,
    required this.days,
    required this.trainingDayCount,
    required this.restDayCount,
    required this.totalExerciseCount,
    required this.totalPlannedSets,
    required this.plannedMuscleGroups,
  });

  final Schedule schedule;
  final List<CurrentSplitDaySummary> days;
  final int trainingDayCount;
  final int restDayCount;
  final int totalExerciseCount;
  final int totalPlannedSets;
  final Set<String> plannedMuscleGroups;

  List<MuscleStateInfo> get anatomyMuscles => plannedMuscleGroups
      .map((group) => MuscleStateInfo(
            muscleGroup: group,
            state: MuscleState.recovered,
            recoveryPercent: 1,
          ))
      .toList(growable: false);
}

CurrentSplitOverviewData buildCurrentSplitOverview({
  required Schedule schedule,
  required List<ScheduleDay> days,
  required List<ScheduledExercise> scheduledExercises,
  required List<Exercise> exercises,
});
```

Implementation rules:

- Sort a copied day list by `dayIndex`; never mutate provider-owned lists.
- Group `ScheduledExercise` values by `scheduleDayId`.
- Count every scheduled row even if its `Exercise` metadata is missing.
- Sum `targetSets` for planned sets.
- Resolve muscle groups from `Exercise.muscleGroup`; when absent, call `ExerciseMapping.resolveGymMuscleGroup` using the first decoded `targetMuscles` and `bodyParts` entry.
- Remove `Cardio`, blank, and duplicate groups while preserving first-seen order.

- [ ] **Step 4: Run the tests and verify GREEN**

Run: `flutter test test/current_split_models_test.dart`

Expected: PASS with no exceptions or warnings.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/workout/current_split/current_split_models.dart test/current_split_models_test.dart
git commit -m "feat: model current split overview"
```

## Task 2: Reactive Drift Queries and Providers

**Files:**
- Modify: `lib/core/database/daos/schedule_dao.dart`
- Create: `lib/features/workout/current_split/current_split_providers.dart`
- Create: `test/schedule_dao_current_split_test.dart`

- [ ] **Step 1: Write a failing reactive DAO test**

Use `AppDatabase(NativeDatabase.memory())`, insert one schedule, two days, and one scheduled exercise, then listen to `watchExercisesForSchedule(scheduleId)`. Insert a second exercise and assert the stream emits both ordered rows.

```dart
final stream = dao.watchExercisesForSchedule(scheduleId);
expectLater(
  stream,
  emitsInOrder(<Matcher>[
    hasLength(1),
    hasLength(2),
  ]),
);
```

- [ ] **Step 2: Run the DAO test and verify RED**

Run: `flutter test test/schedule_dao_current_split_test.dart`

Expected: FAIL because `watchById` and `watchExercisesForSchedule` are missing.

- [ ] **Step 3: Add the two DAO streams**

```dart
Stream<Schedule?> watchById(int localId) =>
    (select(schedules)..where((t) => t.localId.equals(localId)))
        .watchSingleOrNull();

Stream<List<ScheduledExercise>> watchExercisesForSchedule(int scheduleId) {
  final dayIds = selectOnly(scheduleDays)
    ..addColumns([scheduleDays.localId])
    ..where(scheduleDays.scheduleId.equals(scheduleId));
  return (select(scheduledExercises)
        ..where((t) => t.scheduleDayId.isInQuery(dayIds))
        ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
      .watch();
}
```

- [ ] **Step 4: Add current-split state and data providers**

```dart
final currentSplitScheduleIdProvider = StateProvider<int?>((ref) => null);

final scheduleByIdProvider = StreamProvider.family<Schedule?, int>((ref, id) {
  return ref.watch(scheduleDaoProvider).watchById(id);
});

final scheduledExercisesForScheduleProvider =
    StreamProvider.family<List<ScheduledExercise>, int>((ref, id) {
  return ref.watch(scheduleDaoProvider).watchExercisesForSchedule(id);
});

final currentSplitOverviewProvider =
    FutureProvider.family<CurrentSplitOverviewData?, int>((ref, id) async {
  final requested = await ref.watch(scheduleByIdProvider(id).future);
  final schedule = requested ?? await ref.watch(activeScheduleProvider.future);
  if (schedule == null) return null;
  final resolvedId = schedule.localId;
  final days = await ref.watch(scheduleDaysProvider(resolvedId).future);
  final scheduled =
      await ref.watch(scheduledExercisesForScheduleProvider(resolvedId).future);
  final ids = scheduled.map((item) => item.exerciseId).toSet().toList();
  final exercises = ids.isEmpty
      ? <Exercise>[]
      : await ref.watch(exerciseDaoProvider).findByExerciseIds(ids);
  return buildCurrentSplitOverview(
    schedule: schedule,
    days: days,
    scheduledExercises: scheduled,
    exercises: exercises,
  );
});
```

- [ ] **Step 5: Run tests and verify GREEN**

Run: `flutter test test/schedule_dao_current_split_test.dart test/current_split_models_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/database/daos/schedule_dao.dart lib/features/workout/current_split/current_split_providers.dart test/schedule_dao_current_split_test.dart
git commit -m "feat: stream current split data"
```

## Task 3: Focus the Existing Schedule Builder on a Training Day

**Files:**
- Modify: `lib/features/schedule/schedule_builder_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `test/schedule_builder_initial_day_test.dart`

- [ ] **Step 1: Write a failing builder-focus widget test**

Seed a schedule with Push and Pull days, pump `ScheduleBuilderScreen(scheduleId: id, initialDayLocalId: pullId)`, wait for `_loadExistingSchedule`, then assert Pull’s expanded content is visible and Push’s is collapsed.

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/schedule_builder_initial_day_test.dart`

Expected: FAIL because `initialDayLocalId` is not accepted and the first day always expands.

- [ ] **Step 3: Add typed route arguments and source IDs**

```dart
class ScheduleBuilderArgs {
  const ScheduleBuilderArgs({this.scheduleId, this.initialDayLocalId});
  final int? scheduleId;
  final int? initialDayLocalId;
}
```

Extend `_DayModel` with `int? sourceLocalId`, populate it from each loaded `ScheduleDay`, and choose the initial expanded index after loading:

```dart
final requested = widget.initialDayLocalId;
final requestedIndex = requested == null
    ? -1
    : dayModels.indexWhere((day) => day.sourceLocalId == requested);
_expandedDay = requestedIndex >= 0
    ? requestedIndex
    : (dayModels.isNotEmpty ? 0 : -1);
```

Remove the current rest-day `continue`. Load rest days into `_DayModel` with `isRestDay: day.isRestDay`, show their header/label without exercise controls, and persist `isRestDay: Value(day.isRestDay)` in `_saveSchedule`. This prevents opening and saving the editor from silently deleting or converting rest days.

Keep create-mode callers valid by leaving both constructor arguments nullable. In `app_router.dart`, accept either the new args type or the legacy integer:

```dart
final extra = state.extra;
final args = extra is ScheduleBuilderArgs
    ? extra
    : ScheduleBuilderArgs(scheduleId: extra as int?);
return _platformPage(
  child: ScheduleBuilderScreen(
    scheduleId: args.scheduleId,
    initialDayLocalId: args.initialDayLocalId,
  ),
  state: state,
);
```

- [ ] **Step 4: Run the focused test and router tests**

Run: `flutter test test/schedule_builder_initial_day_test.dart test/root_back_handler_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/schedule/schedule_builder_screen.dart lib/core/router/app_router.dart test/schedule_builder_initial_day_test.dart
git commit -m "feat: focus schedule editor day"
```

## Task 4: Workout-Tab Entry and Back Behavior

**Files:**
- Modify: `lib/features/workout/workout_screen.dart`
- Modify: `lib/features/scaffold/my_gym_bro_scaffold.dart`
- Create: `test/current_split_screen_test.dart`

- [ ] **Step 1: Write failing entry tests**

Pump `WorkoutScreen` with `allSchedulesProvider`, `scheduleDaysProvider`, and recovery providers overridden. Assert `Icons.search_rounded` exists and `Icons.edit_rounded` does not. Tap the search key and assert `CurrentSplitScreen` replaces the dashboard.

Use stable keys:

```dart
const Key('current_split_open_button');
const Key('current_split_back_button');
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/current_split_screen_test.dart --plain-name "opens selected split from workout card"`

Expected: FAIL because the pencil remains and no overview state is wired.

- [ ] **Step 3: Switch Workout tab content from provider state**

At the top of `WorkoutScreen.build`, watch `currentSplitScheduleIdProvider`. When non-null, return `CurrentSplitScreen(scheduleId: selectedId, onBack: () => ref.read(currentSplitScheduleIdProvider.notifier).state = null)`.

Replace only the populated `_DayCard` pencil button:

```dart
GestureDetector(
  key: const Key('current_split_open_button'),
  onTap: () {
    ref.read(currentSplitScheduleIdProvider.notifier).state = schedule.localId;
  },
  child: Container(
    width: 69.w,
    height: 64.h,
    decoration: BoxDecoration(
      color: AppColors.of(context).white,
      borderRadius: BorderRadius.circular(AppRadius.scheduleCircle.r),
    ),
    child: Icon(
      Icons.search_rounded,
      color: AppColors.of(context).black,
      size: 33.sp,
    ),
  ),
);
```

Do not change the Add Day card’s existing exercise-search button or the play button.

- [ ] **Step 4: Add Android root-back support for the in-tab detail**

The root `BackButtonListener` in `MyGymBroScaffold` receives system back before a nested `PopScope`. In `_handleRootBack`, clear the overview before changing tabs:

```dart
if (ref.read(navIndexProvider) == 1 &&
    ref.read(currentSplitScheduleIdProvider) != null) {
  ref.read(currentSplitScheduleIdProvider.notifier).state = null;
  return true;
}
```

The visible back control invokes the same provider reset. Extend `test/root_back_handler_test.dart` to assert the first back closes the overview and keeps nav index 1; a second root back returns to Home.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run: `flutter test test/current_split_screen_test.dart --plain-name "opens selected split from workout card"`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/workout/workout_screen.dart lib/features/scaffold/my_gym_bro_scaffold.dart test/current_split_screen_test.dart test/root_back_handler_test.dart
git commit -m "feat: open current split from workout tab"
```

## Task 5: Reference-Faithful Current Split UI

**Files:**
- Create: `lib/features/workout/current_split/current_split_screen.dart`
- Modify: `test/current_split_screen_test.dart`

- [ ] **Step 1: Write failing UI composition tests**

Override `currentSplitOverviewProvider(scheduleId)` with fixed data and assert, in order, the hero, metric card, four quick actions, `currentSplitPlanHeading`, day list, and disabled discover action. Assert the real `AnatomyBody` receives the selected gender/skin through provider overrides.

Required keys:

```dart
const Key('current_split_hero');
const Key('current_split_metrics');
const Key('current_split_quick_actions');
const Key('current_split_plan_heading');
const Key('current_split_day_1');
const Key('current_split_discover_disabled');
```

- [ ] **Step 2: Run the UI test and verify RED**

Run: `flutter test test/current_split_screen_test.dart --plain-name "matches approved current split hierarchy"`

Expected: FAIL because the screen file and keyed sections do not exist.

- [ ] **Step 3: Build the screen shell and anatomy hero**

Implement `CurrentSplitScreen extends ConsumerWidget` with `scheduleId` and `onBack`. Use `SafeArea`, a black/dark token background, and one `CustomScrollView`. Use `OcGlassBtn`/existing circular glass chrome for back and overflow, but use `GlassSurface` or panel tokens—not refractive glass—inside the scroll view.

The hero must render:

```dart
AnatomyBody(
  height: 245.h,
  gender: ref.watch(anatomyGenderProvider),
  basePngPath: ref.watch(activeSkinPathProvider),
  muscleStates: data.anatomyMuscles,
  highlightColor: colors.accent,
)
```

Position the anatomy body on the right with plan eyebrow/name/pill/description on the left, matching the approved reference proportions. Constrain the plan name to two lines with ellipsis.

- [ ] **Step 4: Build metrics and the moved quick-action grid**

Render exactly four equal metric columns: training days, exercises, planned sets, rest days. Immediately below them, render the two-column grid in this exact order: Progress, Nutrition, Statistics, Settings.

Actions:

- Progress: `Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen()))`.
- Nutrition: `onTap: null`, disabled semantics, coming-soon subtitle.
- Statistics: `showStatusBottomSheet(context)`.
- Settings: `context.push(AppRoutes.settings)`.

- [ ] **Step 5: Build ordered day rows and disabled discover action**

For each `CurrentSplitDaySummary`, show locale-aware weekday/cycle label, day number, label, up to three muscle groups, exercise count, planned-set count, and chevron. Rest days use the moon icon and muted recovery copy. Training-row taps push:

```dart
context.push(
  AppRoutes.scheduleBuilder,
  extra: ScheduleBuilderArgs(
    scheduleId: data.schedule.localId,
    initialDayLocalId: summary.day.localId,
  ),
);
```

The discover control is visually lime but has no callback:

```dart
Semantics(
  button: true,
  enabled: false,
  label: l10n.discoverTrainingPlans,
  child: IgnorePointer(
    child: Opacity(
      opacity: 0.76,
      child: Container(
        key: const Key('current_split_discover_disabled'),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(14.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(Icons.grid_view_rounded, color: colors.todayPillText),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                l10n.discoverTrainingPlans,
                style: TextStyle(
                  color: colors.todayPillText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.todayPillText),
          ],
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 6: Add top-right Edit Plan menu**

Use `showMenu` with one localized item. Selecting it opens `ScheduleBuilderArgs(scheduleId: data.schedule.localId)`. Do not add other speculative menu actions.

- [ ] **Step 7: Run UI tests and verify GREEN**

Run: `flutter test test/current_split_screen_test.dart`

Expected: PASS at 390×844 and 430×932 test viewports with `tester.takeException()` returning null.

- [ ] **Step 8: Commit**

```powershell
git add lib/features/workout/current_split/current_split_screen.dart test/current_split_screen_test.dart
git commit -m "feat: add current split overview UI"
```

## Task 6: Localization, Empty/Error States, and Accessibility

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_fr.arb`
- Modify: `lib/features/workout/current_split/current_split_screen.dart`
- Modify: `test/current_split_screen_test.dart`
- Regenerate: `lib/l10n/app_localizations*.dart`

- [ ] **Step 1: Add failing state and semantics tests**

Test loading skeletons, null schedule, empty days, provider error with retry, long plan/day labels, 200% text scale, disabled Nutrition/discover semantics, and minimum 44×44 back/menu targets.

- [ ] **Step 2: Run state tests and verify RED**

Run: `flutter test test/current_split_screen_test.dart --plain-name "states and accessibility"`

Expected: FAIL until state widgets, localized copy, and semantics exist.

- [ ] **Step 3: Add all localized strings to four ARB files**

Add matching keys for current plan, generic split description, training days per cycle, planned sets, rest days, your training plan, progress subtitle, nutrition/coming soon, statistics subtitle, settings subtitle, discover training plans, edit plan, create plan, no plan, empty plan, load error, retry, and pluralized exercise/set/day counts. Reuse an existing key only when its meaning and capitalization match exactly.

Use these approved base translations:

| Key | English | German | Spanish | French |
|---|---|---|---|---|
| `currentSplitEyebrow` | Current plan | Aktueller Plan | Plan actual | Programme actuel |
| `currentSplitDescription` | Focus on strength, muscle building, and balanced development. | Fokus auf Kraft, Muskelaufbau und eine ausgewogene Entwicklung. | Enfocado en la fuerza, el desarrollo muscular y un progreso equilibrado. | Axé sur la force, le développement musculaire et une progression équilibrée. |
| `currentSplitTrainingDays` | Training days | Trainingstage | Días de entrenamiento | Jours d’entraînement |
| `currentSplitPlannedSets` | Planned sets | Geplante Sätze | Series planificadas | Séries prévues |
| `currentSplitRestDays` | Rest days | Ruhetage | Días de descanso | Jours de repos |
| `currentSplitYourPlan` | Your training plan | Dein Trainingsplan | Tu plan de entrenamiento | Votre plan d’entraînement |
| `currentSplitProgressSubtitle` | Track your development | Verfolge deine Entwicklung | Sigue tu evolución | Suivez votre progression |
| `currentSplitNutrition` | Nutrition | Ernährung | Nutrición | Nutrition |
| `currentSplitComingSoon` | Coming soon | Demnächst verfügbar | Próximamente | Bientôt disponible |
| `currentSplitStatisticsSubtitle` | Detailed insights | Detaillierte Einblicke | Análisis detallados | Analyses détaillées |
| `currentSplitSettingsSubtitle` | Customize plan and app | Plan und App anpassen | Personaliza el plan y la app | Personnalisez le programme et l’app |
| `discoverTrainingPlans` | Discover other training plans | Andere Trainingspläne entdecken | Descubre otros planes de entrenamiento | Découvrir d’autres programmes |
| `currentSplitEditPlan` | Edit plan | Plan bearbeiten | Editar plan | Modifier le programme |
| `currentSplitNoPlanTitle` | No training plan yet | Noch kein Trainingsplan | Aún no hay plan de entrenamiento | Aucun programme pour le moment |
| `currentSplitLoadError` | Couldn’t load your training plan. | Dein Trainingsplan konnte nicht geladen werden. | No se pudo cargar tu plan de entrenamiento. | Impossible de charger votre programme. |

Define ICU plural keys `currentSplitTrainingDaysCount`, `currentSplitExercisesCount`, `currentSplitSetsCount`, and `currentSplitRestDaysCount` in all four ARBs with singular and `other` branches.

Run: `flutter gen-l10n`

Expected: generated getters compile for all four locales.

- [ ] **Step 4: Implement deterministic loading/empty/error widgets**

Use `AsyncValue.when`:

- `loading`: fixed-height neutral skeleton blocks preserving hero/metrics/grid/list order.
- `data: null`: icon, no-plan copy, and enabled create-plan action using `ScheduleBuilderArgs()`.
- `data` with zero days: hero + zero metrics + edit-plan inline action.
- `error`: inline error copy, retry button calling `ref.invalidate(currentSplitOverviewProvider(scheduleId))`, and back action.

- [ ] **Step 5: Add semantics and overflow protection**

Wrap icon-only controls and day rows in localized `Semantics`. Use one/two-line bounds plus ellipsis, `Flexible`, and `FittedBox(fit: BoxFit.scaleDown)` only for compact metric values. Respect `MediaQuery.disableAnimationsOf(context)`; add no decorative animation.

- [ ] **Step 6: Run generated localization and widget tests**

Run: `flutter gen-l10n; flutter test test/current_split_screen_test.dart`

Expected: PASS with no overflow exceptions.

- [ ] **Step 7: Commit**

```powershell
git add lib/l10n lib/features/workout/current_split/current_split_screen.dart test/current_split_screen_test.dart
git commit -m "feat: localize current split overview"
```

## Task 7: Full Verification and Documentation Consistency

**Files:**
- Modify only if verification exposes a scoped defect.

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format lib/features/workout/current_split lib/features/workout/workout_screen.dart lib/features/scaffold/my_gym_bro_scaffold.dart lib/features/schedule/schedule_builder_screen.dart lib/core/database/daos/schedule_dao.dart lib/core/router/app_router.dart test/current_split_models_test.dart test/current_split_screen_test.dart test/schedule_dao_current_split_test.dart test/schedule_builder_initial_day_test.dart test/root_back_handler_test.dart
```

Expected: formatter completes successfully.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/current_split_models_test.dart test/schedule_dao_current_split_test.dart test/schedule_builder_initial_day_test.dart test/current_split_screen_test.dart test/root_back_handler_test.dart
```

Expected: all focused tests PASS.

- [ ] **Step 3: Run full regression suite**

Run: `flutter test`

Expected: all existing and new tests PASS.

- [ ] **Step 4: Run static analysis**

Run: `flutter analyze`

Expected: “No issues found”.

- [ ] **Step 5: Review the final diff against the approved spec**

Confirm all of these explicitly: search replaces only populated-card edit; bottom nav remains shared; anatomy uses real gender/skin; quick actions precede plan list; unsupported metrics are absent; Nutrition/discover are disabled; all locales compile; no schema/cloud files changed.

- [ ] **Step 6: Commit verification fixes, if any**

If verification required scoped corrections, stage only those files and commit:

```powershell
git add lib test
git commit -m "fix: complete current split verification"
```

If the working tree is already clean apart from `.superpowers/` browser mockups, do not create an empty commit.
