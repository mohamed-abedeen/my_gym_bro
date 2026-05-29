# 🏋️ MyGymBro — Master Plan

A paid, offline-first fitness training app for iOS and Android. Local-first workout tracking with a premium "liquid glass" UI, an interactive anatomy body that visualizes muscle recovery and training volume, a social layer (followers, community feed, challenges, global leaderboard), and a tone-adjustable coach that talks to you the way you want.

> **Status:** ~70% built. This plan is the authoritative source of truth for the **vision** and the **roadmap to ship v1**. It documents what already exists (lighter detail) and goes deep on what remains.

---

## 📂 Documentation Structure

**Read in this order:**

1. **[CLAUDE.md](./CLAUDE.md)** — START HERE. Instructions, principles, and rules for Claude Code.
2. **[01-PRD.md](./01-PRD.md)** — Product Requirements (what we're building and why).
3. **[02-ARCHITECTURE.md](./02-ARCHITECTURE.md)** — Technical architecture & stack.
4. **[03-DATABASE.md](./03-DATABASE.md)** — Drift (local) + Supabase (cloud) schema.
5. **[04-BACKEND.md](./04-BACKEND.md)** — Supabase edge functions, sync protocol, contracts.
6. **[05-UI-UX.md](./05-UI-UX.md)** — Design system, components, i18n, anatomy UX.
7. **[06-IMPLEMENTATION.md](./06-IMPLEMENTATION.md)** — Current-state audit + phase-by-phase finish plan.
8. **[07-SETUP.md](./07-SETUP.md)** — Dev environment, accounts, build & release.

---

## 🎯 Quick Overview

**What we're building:**
A subscription fitness app for both beginners and experienced lifters, built solo, iOS-first then Android, with:

- Offline-first workout logging (sessions, sets, RPE, warmup/dropset/failure, cardio)
- Multi-day schedule/program builder + 700+ exercise library with how-to detail
- **Interactive anatomy body** — colors muscles by recovery state *and* training volume
- **Rest timer** with persistent notification + actionable controls
- **Tone-adjustable coach** — every notification ships in 4 voices (supportive / balanced / bold / savage)
- **Social layer** — followers (mutual follow = friends, Instagram-style), community feed, daily + community challenges
- **Leaderboard** — composite score (avg of streak, volume, challenge points); **Global + Friends + Rivals** scopes; all-time + **weekly & monthly seasons** (reset + crowned winner)
- **Rivals** — auto-matched weekly pods of similar-level users for fair, beatable competition
- **Cosmetic skins** for the anatomy body — some earned, some purchasable
- **Progress charts** — compare identical past sessions over time
- **Weekly & monthly reports** — improvement vs. last period, pushed + in Workout → Status → Reports
- **Training calendar** — tap the Home day strip to review which days you trained
- **Share cards** — shareable workout summary on session completion
- **Wearables** — Apple Health/Watch + Google Fit/Health Connect (HR, energy, two-way workout sync)

**Monetization:** Subscription-only, **hard paywall after a 7-day free trial** (RevenueCat). Skins are a secondary purchase/earn layer.

**Languages:** English (primary), German, Spanish, French.

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| App framework | Flutter (Dart SDK ^3.7) |
| State management | Riverpod (`flutter_riverpod` + `riverpod_generator`) |
| Local database | Drift (SQLite), schema v12 |
| Routing | go_router |
| Backend | Supabase (Auth, Postgres + RLS, Storage, Edge Functions) |
| Payments | RevenueCat (`purchases_flutter`) |
| Push / crash | Firebase Cloud Messaging + Crashlytics |
| UI / effects | `oc_liquid_glass`, `flutter_svg`, `google_fonts` (Familjen Grotesk) |
| Notifications | `flutter_local_notifications`, iOS Live Activities, `home_widget` |
| Media / device | `audioplayers`, `vibration`, `wakelock_plus`, `image_picker`, `cached_network_image` |
| i18n | Flutter `gen-l10n` (ARB files, 4 locales) |

---

## 📅 Timeline

The "finish the job" roadmap is **8 phases** building on the existing foundation. See **[06-IMPLEMENTATION.md](./06-IMPLEMENTATION.md)** for the phase-by-phase guide and the current-state audit.

| Phase | Theme |
|-------|-------|
| 1 | Paywall enforcement + DM removal + cleanup |
| 2 | Social graph (followers + mutual=friends) + public profiles |
| 3 | Community feed backend (replace mocks) |
| 4 | Challenges (curated + community) + moderation |
| 5 | Leaderboard (composite scoring; Global + Friends + Rivals scopes) |
| 6 | Anatomy volume + skins + charts + reports + training calendar + share cards + light-mode accent + l10n |
| 7 | Wearables (Apple Health/Watch, Google Fit/Health Connect) |
| 8 | Release prep & store submission |

---

## 🚦 Current-State Snapshot

| Area | Status |
|------|--------|
| Local DB, sync, auth, monetization plumbing | ✅ Production-ready |
| Workout core, schedule builder, exercise browser | ✅ Done |
| Liquid-glass design system | ✅ Done |
| Anatomy body (recovery coloring) | 🟡 Partial — no volume view |
| Localization (DE/ES/FR) | 🟡 ~77% (84 keys missing each) |
| Notifications + tone system | 🟡 Partial — force-kill resilience deferred |
| Community feed, leaderboard, challenges | 🔴 Mock data only |
| Followers / friends / public profiles | 🔴 Not built |
| Leaderboard scopes (Global / Friends / Rivals) | 🔴 Not built |
| Paywall **gate** (enforcement) | 🟡 Partial — gate logic exists (`scaffold`), needs hardening |
| Skins selection (14 wired) | 🟡 Done — picker works |
| Skins economy (own/earn/buy + persistence) | 🔴 Not built |
| Progress charts, share cards | 🔴 Not built |
| Weekly/monthly reports, training calendar | 🔴 Not built |
| Light-mode orange accent | 🔴 Not built (lime hardcoded) |
| Wearables (Apple Health/Watch, Google Fit) | 🔴 Not built |
| DM subsystem | ⚠️ Built — **being removed** |

---

**Document Owner:** Solo developer (you)
**Last Updated:** 2026-05-28
