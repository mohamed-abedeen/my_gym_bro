# CLAUDE.md — MyGymBro (project root)

MyGymBro is a paid, offline-first Flutter fitness app (iOS-first, then Android).

> **The full working contract lives in [`docs/plan/CLAUDE.md`](docs/plan/CLAUDE.md)** plus the numbered docs in `docs/plan/` (PRD, architecture, database, backend, UI/UX, implementation). Read `docs/plan/CLAUDE.md` before building a feature — it covers offline-first, i18n (en/de/es/fr), Apple/Play compliance, the paywall gate, and the Drift+Supabase sync rules. This root file does NOT repeat that; it captures the **UI glass system** and a few cross-cutting facts that must be honored on every screen.

---

## 🪟 Glass / UI chrome — the glass system

The app has **three** glass styles. Reuse the shared widgets below — **don't invent new chrome**.

### "Make it glassy" → pick the style by context, and say which you chose
When the user says **"make X glassy"** (or "glass", "glassify"), the look is **context-dependent** — choose based on what X is, then tell them which you applied:
- **General surfaces** (cards, sheets, list rows, secondary/icon buttons, panels) → **frosted `GlassSurface`**.
- **Prominent, nav-like chrome** (floating bars, the bottom-nav family, hero/primary action buttons, top-of-screen chrome) → **refractive `RefractiveGlass`** (the "liquid" shader look).
- If it's genuinely ambiguous, default to frosted and ask.

**Frosted `GlassSurface`** is the Telegram-style look: a real `BackdropFilter` Gaussian blur + a translucent tint + a hairline border.

- Widget: `lib/shared/widgets/glass_surface.dart`
- Tokens: `AppGlass` in `lib/shared/constants.dart` — `blur` (24; bars/sheets/cards), `blurButton` (16; chips/buttons), `blurStrong` (30; scroll-edge), `borderDark` / `borderLight`.
- Do **not** use flat tint-only "fake glass" or a raw inline `BackdropFilter` — route through `GlassSurface`.
- `BackdropFilter` only frosts what's painted *behind* it, so place glass *above* content (e.g. a `Stack` over a scroll view), and it looks glassiest over busy/bright content.
- Real blur is GPU-heavier than flat fills — scope it to bars/sheets/cards; use `AppGlass.blurButton` for small chips.

### Refractive — `RefractiveGlass` (prominent / nav-like chrome)
The `oc_liquid_glass` shader look (iOS-26-ish refraction + specular). Use it for prominent, nav-like chrome (floating bars, hero buttons, the nav family) — or whenever the user asks for the "refractive / liquid" look.

- Widget: `lib/shared/widgets/refractive_glass.dart` (wraps `oc_liquid_glass`).
- **Currently dormant** — no call site passes `refractive: true`; every live surface is frosted (or the native iOS nav). The opt-in flag on `LiquidGlassButton`/`OcGlassBtn` is the entry point when something deliberately goes refractive. The active-workout chrome is now fully **frosted**: full-bleed frosted top bar (no floating capsule), frosted Add Set bar, frosted `GlassSurface` set rows/check pills. The non-iOS nav pill is frosted, rebuilt to a Figma spec — see the nav section.
- **Never place it inside a scrolling viewport.** The shader is an *unclipped* BackdropFilter that force-writes opaque pixels across the whole enclosing clip — inside a list on Android (Impeller) it paints the entire viewport black while scrolling (visible in light mode; dark mode hides it). Outside scrollables (floating bars, overlays) it's fine.
- `oc_liquid_glass` is retained **only** for this refractive look. Don't add it to new surfaces unless you're deliberately going refractive.

### Native iOS Liquid Glass — bottom tab bar only
Real Apple Liquid Glass via `cupertino_native_better` (`CNTabBar`), **iOS only**, used only for the bottom nav (`lib/shared/widgets/ios_native_nav.dart`). Don't extend native glass to other screens — each is a `UiKitView` platform view (expensive; the package itself forbids it inside scrolling lists), and it can't be verified from a Windows toolchain.

### Shared glass widgets (in `lib/shared/widgets/`)
| Widget | Look | Notes |
|---|---|---|
| `GlassSurface` | frosted | the primitive; everything frosted routes through it |
| `LiquidGlassButton` | frosted | pass `refractive: true` for the nav-matching refractive look |
| `OcGlassBtn` | frosted | typed icon button (close/done/save/share/delete/hint); `refractive: true` opt-in |
| `RefractiveGlass` | refractive | the `oc_liquid_glass` primitive |
| `GlassDecoration` | — | shared tint/shadow math used by the frosted widgets |
| `BottomNavPill` | frosted | non-iOS bottom nav pill (built to the Figma neutral spec) |
| `IosNativeNav` | native | iOS bottom tab bar (CNTabBar) |

### Glass rules
- **"make it glassy" is context-dependent** (see the rule above): frosted for general surfaces, refractive for prominent nav-like chrome — and state which you used.
- When glassifying a **button**, keep its existing tint — add the frost, don't restyle it. (Standing rule: don't bulk-restyle/replace buttons without per-change approval.)
- New glass surfaces should compose the shared widgets above, not new one-off chrome.

---

## 🧭 Bottom nav is platform-adaptive — don't break it
`MyGymBroScaffold` (`lib/features/scaffold/`) branches on platform: **iOS → `IosNativeNav`** (native CNTabBar) as the `bottomNavigationBar`; **every other platform → `BottomNavPill`** (frosted, built to the Figma spec) floating in a `Stack`. Both are driven by `navIndexProvider` (defined in `bottom_nav_pill.dart`). `CNTabBarRouteObserver` is registered in the GoRouter `observers` (`app_router.dart`) so the native iOS bar hides under bottom sheets — keep it registered.

---

## 📌 Cross-cutting product facts (newer than some plan docs — these win)
- **Auth is Google + Apple sign-in only** (native Sign in with Apple on iOS). There is no email/password flow; don't add one.
- **RevenueCat product IDs**: `mgb_premium_monthly` / `mgb_premium_annual`.
- **Big numbers always get thousands separators** — "10,000 kg", never "10000 kg" — on every screen.
- **Streak mechanic (locked 2026-08-10)**: schedule-aware rest allowance (longest recorded rest run, or `7 − cycle length` inferred when the schedule stores training days only, clamped 1–3) **plus 2 automatic "streak skips" per calendar month, never two in the same Monday-week** — computed deterministically in `computeStreak` (`workout_providers.dart`), no stored state. The old manual claim-a-rest-day flow (2/week, `rest_day_provider.dart`) was **removed**; Settings only displays skips remaining.
- **Bros tab (decision 2026-08-15)**: the Community feed and follower model are **cut**. The third tab is the **Bros tab** = the leaderboard/challenges screen, with a friends-with-requests graph coming in Phase B (invite link/QR + unique @username exact search only — no real-name search; block+report required) and challenges backend in Phase C. Canonical spec: `docs/plan/01-PRD.md` §5.6/§5.8. Don't rebuild a feed or follower mechanics.
- **Status sheet**: converting it from weekly to all-time (weekly stats move to reports) was attempted once and **rejected/reverted**. Don't retry without designing it with the user first.
- Don't bulk-restyle or bulk-replace buttons (e.g. swapping to `OcGlassBtn` en masse) — each restyle needs per-change approval.
- Every change must stay compliant with Apple App Store and Google Play policies (see `docs/plan/CLAUDE.md`).
- **External services are half-configured** (RevenueCat/ASC, Supabase cloud deploy, Firebase, exercise-data license). Read [`docs/plan/SETUP-STATUS.md`](docs/plan/SETUP-STATUS.md) before touching billing, sync, push, CI, or anything cloud-side — and keep that doc updated when you change service state.

---

## 🗄️ Drift migrations must stay idempotent
`lib/core/database/app_database.dart` is at **schemaVersion 18** (v17 = Bros friendships, v18 = challenge caches). Columns are declared in the table definitions, so a fresh `createAll()` already adds them — which means raw `ALTER TABLE … ADD COLUMN` in `onUpgrade` can crash with "duplicate column" on version-inconsistent DBs.

- **Every `ADD COLUMN` migration must go through `_addColumnIfMissing(table, column, definition)`.**
- **Guard `createTable(...)` with `_hasTable(name)`.**
- Still bump `schemaVersion` + add the `onUpgrade` step on any schema change, and regenerate `.g.dart` with `dart run build_runner build --delete-conflicting-outputs`.
