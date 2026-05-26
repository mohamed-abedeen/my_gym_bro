# Shared Components — my_gym_bro

All in `lib/shared/` unless noted.

---

## Design System — `shared/constants.dart`

### `AppColors.of(context)` → `AppColorsTheme`
Dynamic, adapts to light/dark mode. Use `AppColors.of(context).field` in widgets.

| Field | Dark | Light | Usage |
|---|---|---|---|
| `background` | `#000000` | `#F2F2F7` | Screen background |
| `card` | `#161414` | `#FFFFFF` | Card surfaces |
| `accent` | `#D2FF00` | `#D2FF00` | Primary CTA, highlights |
| `textPrimary` | `#FFFFFF` | `#1C1C1E` | Headings, main text |
| `textSecondary` | `#999999` | `#8E8E93` | Captions, labels |
| `success` | `#49995C` | `#34C759` | Completed, positive |
| `amber` | `#EF9F27` | `#FF9500` | Warnings, rest state |
| `danger` | `#FF0004` | `#FF3B30` | Errors, delete |
| `muscleUntrained` | `#888780` | `#C7C7CC` | Muscle SVG default fill |
| `trendPositive` | `#49995C` | `#34C759` | Upward trend arrows |
| `trendNegative` | `#FF0004` | `#FF3B30` | Downward trend arrows |
| `separator` | `#3B3B3B` | `#D1D1D6` | Dividers |
| `panelBackground` | `#1C1C1E` | `#E5E5EA` | Sheet / panel bg |
| `cardElevated` | `#29292B` | `#FFFFFF` | Elevated card |
| `divider` | `#414546` | `#D1D1D6` | Line dividers |
| `subtitleText` | `#9B9B9B` | `#8E8E93` | Subtitle text |

---

## App Flow Concepts

### Training Modes
1. **One-off Session (Ad-hoc)**: 
   - Non-program activities (e.g., biking, random pushups).
   - Logged directly to `Sessions` without a parent `Schedule`.
   - Entry point: **Green Plus Button** on the "Create" card.
2. **Structured Program (Schedule)**: 
   - Named programs (e.g., "PPL", "Upper/Lower") with multiple days and planned exercises.
   - Includes **Rest Day** intervals between training days.
   - Entry point: **White Search/Build Button** on the "Create" card.

---

## Shared Widgets — `shared/widgets/`

### `OCGlassBTN` — `oc_glass_btn.dart`
- **Goal**: Standardized glass icon buttons (X, Done, Save, Share, Delete, Hint) using `oc_liquid_glass`.

### `AnatomyBody` — `anatomy_body.dart`
- **Logic**: Renders PNG base + SVG layers using `BlendMode.color`.
- **States**: Research-backed recovery colors (Red/Amber/Green/Grey).

---

## Research-Backed Muscle Recovery
- **Algorithm**: 24h-72h recovery based on muscle size + 7-day retention window.
