# Pages / Screens — my_gym_bro

## Primary Layout
### `MyGymBroScaffold` — `scaffold/my_gym_bro_scaffold.dart`
- Shell for major tabs (Home, Workout, Community).

---

## Feature: Workout (Tab 1)
### `WorkoutScreen` — `workout/workout_screen.dart`
- **Flow Update**: `_NoScheduleCard` (Page 0) now provides two distinct entry points:
  - **Option 1 (Green Button)**: "Quick Start" for one-off sessions. Bypasses program building and goes straight to recording.
  - **Option 2 (White Button)**: "Build Program" for formal multi-day schedules with names and rest-day settings.

### `ScheduleBuilderScreen` — `schedule/schedule_builder_screen.dart`
- **New Feature**: "Rest Days" between exercise days. 
- **Structure**: Name field + List of `_DayModel` (Exercise days or Rest days).

### `ActiveSessionScreen` — `workout/active_session/active_session_screen.dart`
- Handles both scheduled and one-off session tracking.
- Logs results to `Sessions` and `SessionExercises` in local SQLite.

---

## Core Workflows
| Task | Goal |
|---|---|
| **Create Program** | Name → Add Days → Define Rest Intervals → Pick Exercises per Day → Save. |
| **Log One-off** | Choose activity type/Random → Start Recording → Save to History. |
| **Track Recovery** | Automatically calculated based on finished sessions and muscle groups involved. |
