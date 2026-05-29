# 05 — UI / UX & Design System
## MyGymBro — "Liquid Glass" Design Language, Navigation, i18n, Anatomy UX

---

## 1. Design Language

A dark-first, high-contrast "liquid glass" aesthetic: frosted translucent surfaces floating over a near-black canvas, accented by a single electric lime.

### 1.1 Color (`lib/shared/constants.dart` — `AppColorsTheme`)
| Token | Dark | Light |
|-------|------|-------|
| Background | `#000000` (pure black) | `#F2F2F7` (light grey) |
| Accent | `#D2FF00` (electric lime) | **Orange** (lime is low-contrast on light) |
| Text | White | Near-black |
| Danger / Success | red / green | red / green |
| Glass tint alpha | `~0.10` | `~0.06` |

- **Light-mode accent is orange, not lime.** Lime (`#D2FF00`) reads poorly on the light grey background, so in light mode the accent — and specifically these elements — switch to orange:
  - accent **font/text** color
  - **selected** bottom-nav icon
  - **Start Workout** button
  - **streak** icon (flame)
  - Dark mode keeps lime everywhere.
  - Implement as a single theme token (e.g. `accent` in `AppColorsTheme`) resolved per brightness, so widgets read the token rather than hardcoding lime.
- **Recovery gradient:** grey (untrained) → red → amber → green (recovered), driven by `MuscleStateInfo` (unchanged across themes).
- Use theme tokens, never hardcoded hex in widgets.

### 1.2 Typography (`lib/shared/app_fonts.dart`)
- **Primary:** system font (San Francisco / Roboto) for body & UI.
- **Accent:** **Familjen Grotesk** (`google_fonts`) reserved for trend/number indicators (small, e.g., 10px deltas).

### 1.3 Glass Component Family (`lib/shared/widgets/`)
| Component | Role |
|-----------|------|
| `GlassCard` | Standard frosted card (tint + soft shadow). |
| `GlassSurface` | `oc_liquid_glass` container with theme-aware refraction/lightband. |
| `GlassDecoration` | Centralized tint + shadow math (dark-mode aware). |
| `LiquidGlassButton` | Flat frosted button. |
| `OcGlassBtn` | iOS-26-style icon buttons (circle/pill), state-colored. |
| `BottomNavPill` | Floating nav pill with animated active indicator. |

> **Standing rule:** do **not** bulk-replace existing buttons with `OcGlassBtn` — change buttons individually, with approval.

### 1.4 Theming
- Light/dark via theme extensions wired in `lib/app.dart` (`MaterialApp.router`).
- `themeModeProvider` controls mode; `anatomyGenderProvider` controls body gender.

---

## 2. Navigation & Shell

- `go_router` (`lib/core/router/app_router.dart`).
- `MyGymBroScaffold` hosts the primary tabs with an animated page switcher.
- **Bottom nav:** floating `BottomNavPill` (Android/custom) / native tab bar (iOS).
- Primary destinations: **Home**, **Workout**, **Community** (+ Leaderboard, Profile, Settings reached contextually).

---

## 3. Screen Inventory & States

Every screen handles **loading / empty / error** and an **offline** path. Premium screens route to the **paywall** when the gate is closed.

| Screen | Key UX |
|--------|--------|
| Onboarding | Stepper intake; tone picker shows example lines; ends at trial intro. |
| Home | Leaderboard card, weekly strip (**tap a day → Training Calendar**), status section (recovery/cals/next session). |
| Training Calendar | Month calendar marking worked days; tap a day → that day's session(s) + route to log. |
| Workout | Anatomy body (recovery/volume), stats row, swipeable schedule card, streak badge. Status sheet has a **Reports** button. |
| Reports window | List of past **weekly/monthly** reports; each shows improvement deltas (▲/▼) vs. prior period. |
| Active session | Set logging (weight/reps/RPE, warmup/dropset/failure), rest timer, wakelock. **Live heart rate** (when Health/Watch connected). |
| Rest timer | Countdown + sound/haptics + actionable notification. |
| Schedule builder | Day tabs, rest-day toggle, exercise picker, per-exercise targets. |
| Exercise browser/detail | Search + filter chips; how-to GIF, muscles, equipment, steps. |
| Community feed | Posts (text/image), likes, comments, composer. |
| Leaderboard | Scope switch (Global / Friends / Rivals) + board switch (All-time / Weekly / Monthly seasons), **countdown to next reset**, last winner banner, ranked rows → profile, Challenges tab. Rivals shows your weekly matched pod. |
| Challenges | Curated daily + community list; join; progress; create (community); report. |
| Profile | Avatar/banner, anatomy body, streak; tabs Status / Achievements / Posts; follow button + counts. |
| Settings | Profile, language, weight unit, rest time, tone, subscription, skins, **Health/Wearable connect + permissions**, data/sync, support, delete account. |
| Skins gallery | Owned / earnable / buyable; preview; select; purchase. |
| Paywall | Plan select (monthly/yearly), start trial, restore. |

---

## 4. Anatomy Body UX (centerpiece)

`lib/shared/widgets/anatomy_body.dart` + `MuscleRecoveryService` + `muscle_detail_sheet.dart`.

- **Render:** gendered base PNG (or skin override via `basePngPath`) + per-muscle SVG overlays from `assets/anatomy/`.
- **Recovery mode** *(built):* each muscle colored by recovery % (red→amber→green); tap → detail sheet (last trained, volume, recovery %).
- **Volume mode** *(to build):* toggle to color/annotate muscles by training emphasis/volume over a window (week/month) — reveals over/under-trained areas.
- **Mode toggle:** clear segmented control (Recovery | Volume).
- **Skins:** restyle the base body; selected via Skins gallery; ≈20 variants/gender exist — wire all, not just 3.
- **Polish targets:** smooth color transitions on state change; consider surfacing posterior view (assets exist).

---

## 5. Internationalization

- Locales: **en (source), de, es, fr**. Flutter `gen-l10n`, ARB files in `lib/l10n/`.
- `en` = 377 keys; **de/es/fr ≈ 293 (≈84 missing each)** → **backfill before launch**.
- Generated `app_localizations_*.dart` fall back to English on missing keys; don't rely on that for shipped UI.
- `_LocaleSyncBoundary` (in `app.dart`) pushes localized labels to background services (widgets, notifications) via `WidgetSyncService`.

### 5.1 i18n Rules
- No hardcoded user-facing strings — add the key to **all four** ARB files.
- Tone **sample lines** in the picker may stay in English to preserve voice; everything else translates.
- Format numbers/dates per locale; weight unit (kg/lb) per user setting (`units.dart`).
- Keep keys semantic (`leaderboard_board_all_time`), not positional.

---

## 6. Notification & Widget UX

- Rest-timer notification: actionable (complete / skip / ±15s), silent by default, haptic on tap.
- Tone-aware copy across rest-complete, reminders (escalating by rest days), active session.
- iOS Live Activity (best-effort) for active session/rest; Android ongoing notification.
- Home-screen widget: streak days + next focus/CTA (`widget_sync_service`).
- **v1 fix:** resync notification state on app resume to avoid stale action buttons after force-kill.

---

## 7. Accessibility & Responsiveness

- Support dynamic text sizes; min tap target 44pt.
- Sufficient contrast on glass surfaces (the tint math is dark-mode aware — verify legibility in light mode).
- `lib/shared/responsive.dart` for layout scaling across phone sizes.
- Test both genders and both themes on the anatomy body.

---

## 8. UI Definition of Done

- [ ] Reuses the glass component family (no ad-hoc chrome).
- [ ] Loading / empty / error / offline states present.
- [ ] Premium screens respect the paywall gate.
- [ ] All strings in en/de/es/fr.
- [ ] Light + dark verified; tap targets ≥44pt; dynamic type OK.
- [ ] Anatomy changes verified for male & female, recovery & volume.

---

**End of UI/UX Document**
