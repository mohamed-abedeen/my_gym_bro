# Current Split Overview — Design Specification

**Date:** 2026-08-05
**Status:** Approved for implementation
**Scope:** Flutter client only; no Drift schema, Supabase, or cloud changes

## Goal

Replace the white edit button on each populated Workout schedule card with a search button. Tapping that button opens a dedicated overview inside the Workout tab for the schedule currently selected in the swipeable card.

The overview must closely follow the user-provided “Current Plan — Push / Pull / Legs” reference: the same visual hierarchy, dense but readable card layout, black base, neon lime accents, anatomy hero, plan metrics, action tiles, weekly plan rows, and discover-plans call to action. It must still use MyGymBro’s existing typography, design tokens, responsive sizing, glass primitives, real data, localization, and platform-adaptive navigation.

## Entry Point and Navigation

- On a populated Workout day card, replace the existing white pencil button with a white circular search button.
- The play button and its behavior remain unchanged.
- The search button replaces the Workout tab content with the overview for the schedule currently displayed by the Workout card, including a non-active schedule selected through the card’s program picker.
- Keep the overview inside the existing Workout tab rather than adding a top-level route. This preserves the existing platform-adaptive bottom navigation from the reference without duplicating navigation chrome.
- The overview back button restores the normal Workout tab content.
- The top-right overflow menu contains “Edit plan” and opens the existing schedule builder for the displayed schedule.
- Tapping a weekly-plan row opens the existing schedule builder with that schedule day initially selected.
- If the referenced schedule no longer exists, fall back to the active schedule. If no schedule exists, show the empty state instead of failing.

## Screen Layout

The scrollable content order is fixed:

1. iOS-style circular back button and overflow button
2. Anatomy hero with plan identity
3. Four-column plan metrics card
4. Four quick-action tiles in a two-column grid
5. “Your training plan” heading
6. Ordered schedule-day rows, including rest days
7. “Discover other training plans” lime call-to-action

The existing platform-adaptive MyGymBro bottom navigation remains outside the scrollable content and is supplied by `MyGymBroScaffold`.

### Anatomy Hero

- Show the localized “Current plan” eyebrow, schedule name, and a pill containing the number of training days per cycle/week.
- Show a short localized description suitable for any split; do not invent a schedule-specific stored description.
- Render the existing MyGymBro anatomy body, not a new placeholder illustration.
- Respect the user’s stored gender and selected anatomy skin.
- Highlight the primary muscles covered by scheduled exercises using the existing exercise-to-muscle mapping and the app’s lime accent.
- If muscle or profile data is loading or unavailable, render the body without highlights; the rest of the screen remains usable.

### Plan Metrics

Maintain the four equal columns and neon-lime icons from the reference while using metrics that can be calculated from current local data:

1. Training days per schedule cycle
2. Total scheduled exercises
3. Total planned target sets
4. Rest days per schedule cycle

Do not display unsupported duration, phase length, per-session time, or progress percentages.

### Quick Actions

Place these four compact tiles directly between the metrics card and the training-plan heading:

- Progress: opens the existing reports/progress experience.
- Nutrition: visible but disabled, labeled as coming soon because full nutrition tracking is outside v1 scope.
- Statistics: opens the existing status/statistics experience.
- Settings: opens the existing Settings screen.

Disabled actions must expose disabled semantics and must not navigate.

### Training Plan Rows

- Display all schedule days in stored `dayIndex` order, including rest days.
- Each training row shows a localized weekday/cycle label, day number, day name, primary muscle summary, exercise count, planned set count, and chevron.
- Each rest row shows the rest-day label and recovery copy, with muted styling and a moon/rest icon.
- Lime accents are limited to icons, status dots, key counts, and chevrons, matching the reference.
- Tapping a row opens the schedule builder focused on that day.

### Discover Plans Action

- Show the full-width neon-lime “Discover other training plans” button at the bottom of the content.
- Keep it intentionally non-functional in this iteration.
- Implement it as disabled while preserving the requested visible styling and accessible disabled state.

## Visual System

- Follow the reference layout and proportions as closely as practical on a phone viewport.
- Use the app’s existing dark background, typography, spacing scale, corner radii, and lime accent token instead of hardcoded lookalikes.
- General cards use the existing frosted `GlassSurface` system where the screen background provides meaningful content to blur; otherwise use the established panel surface token. Do not introduce refractive glass inside the scroll view.
- Reuse existing shared button and navigation components. Do not bulk-restyle unrelated controls.
- On iOS, preserve the existing native bottom navigation behavior. On other platforms, preserve the existing frosted navigation pill behavior. The overview must not create a second navigation bar.
- Adapt spacing and text sizing for supported phone widths without changing the content hierarchy.
- Long schedule and day names use bounded lines and ellipsis rather than overflowing.

## Data Flow

- Store the overview’s visibility and selected schedule identifier in a small Workout-tab view-state provider when the user taps the search button.
- Watch the schedule, its ordered days, scheduled exercises, exercise metadata, profile gender, and selected skin through Riverpod providers backed by Drift/local state.
- Aggregate metric totals and per-day exercise/set/muscle summaries in a small immutable view model/provider, keeping calculation logic out of the widget tree.
- All reads are local-first and reactive. Editing the schedule and returning to the overview refreshes the screen automatically.
- No network request may block rendering or interaction.

## Loading, Empty, and Error States

- Loading: preserve the screen structure with restrained skeleton/placeholders for data-dependent sections.
- No schedules: show a localized empty state with an enabled “Create training plan” action that opens the schedule builder.
- Schedule with no days: show the hero and zeroed metrics plus an inline action to edit the plan.
- Provider error: show a localized inline error with retry and back navigation; do not replace the entire app with a raw exception.
- Missing exercise metadata: retain the row with exercise and set counts where possible and omit only the unavailable muscle summary.

## Localization and Accessibility

- Add every new user-facing string to English, German, Spanish, and French ARB files.
- Use locale-aware weekday labels and pluralization for days, exercises, and sets.
- Add semantic labels for the search entry button, back button, overflow menu, metric columns, day rows, and disabled actions.
- Maintain at least 44×44 logical-pixel touch targets and support text scaling without clipping.
- Respect reduced-motion settings; no new decorative motion is required.

## Testing

Widget and provider tests must cover:

- The search icon replaces the pencil icon on populated Workout day cards.
- Tapping search replaces the Workout tab content with the overview for the schedule currently selected on the card while the shared bottom navigation remains visible.
- Training-day, exercise, set, and rest-day totals are calculated correctly.
- Days remain ordered and rest days receive the correct presentation.
- The real anatomy widget receives gender, skin, and mapped-muscle inputs.
- A day row opens the schedule builder with that day selected.
- The overflow edit action opens the schedule builder for the displayed schedule.
- Progress, statistics, and settings navigate to their existing destinations.
- Nutrition and discover-plans actions are visible, disabled, and do not navigate.
- Loading, missing-schedule, empty-plan, missing-exercise, and provider-error states render safely.
- Long names and supported phone widths do not overflow.

Run the focused tests first, then the full Flutter test suite and `flutter analyze` before completion.

## Non-Goals

- Building the other-training-plans browser
- Adding nutrition tracking
- Adding schedule phase length, planned duration, or progress tracking fields
- Changing the schedule database schema or sync contract
- Redesigning the existing schedule builder
- Restyling unrelated buttons or screens
