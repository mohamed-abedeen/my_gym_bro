# 01 — Product Requirements Document (PRD)
## MyGymBro — Paid Fitness Training App

**Version:** 1.0
**Date:** May 2026
**Status:** Approved for Implementation (finish & ship)

---

## 📋 Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Problem & Solution](#2-problem--solution)
3. [Target Users](#3-target-users)
4. [Monetization](#4-monetization)
5. [Feature Specifications](#5-feature-specifications)
6. [Localization](#6-localization)
7. [Out of Scope (v1)](#7-out-of-scope-v1)
8. [Decisions Log](#8-decisions-log)

---

## 1. Executive Summary

### 1.1 Vision
MyGymBro is a **premium, offline-first** training companion that makes serious lifting feel personal and motivating. It pairs fast, reliable workout logging with a **living anatomy body** that shows what you trained and what's recovered, a **motivational voice** (your "gym bro") that talks to you in **the tone you choose**, and a **social layer** (followers, community, challenges, a global leaderboard) that turns consistency into something visible and competitive.

### 1.2 Value Proposition
- **Offline-first & fast** — log a full session in the gym with zero connectivity, no spinners.
- **Visual & personal** — the anatomy body turns abstract training into a recovery/volume picture you can read at a glance; cosmetic skins make it yours.
- **Motivating, not preachy** — pick how hard your gym bro pushes (supportive → savage); compete on a leaderboard; chase challenges.
- **Premium feel** — a cohesive "liquid glass" interface, not a spreadsheet with a logo.

### 1.3 Positioning
A paid app for people who train regularly and want a tool that's both rigorous (real set/rep/RPE logging, programs) and emotionally engaging (visuals, social, voice). Not a generic habit tracker, not a bloated all-in-one.

---

## 2. Problem & Solution

### 2.1 Pain Points
- Most trackers are either **clinical spreadsheets** (powerful, joyless) or **gamified toys** (fun, shallow).
- Logging often **requires connectivity** or feels slow mid-set.
- Recovery is invisible — users don't know what's ready to train.
- Motivation copy is **one-size-fits-all**; some users find it harsh, others find it limp.

### 2.2 Our Solution
- Local-first logging that is instant and reliable, syncing in the background.
- An interactive anatomy body visualizing **recovery state** and **training volume**.
- A **4-tone** coaching voice across every notification and motivation message.
- A social layer that rewards consistency: followers, feed, challenges, and a composite leaderboard.

---

## 3. Target Users

- **Primary:** committed lifters (intermediate→advanced) who want detailed logging + visual recovery + competition.
- **Also served:** beginners — guided by seeded programs (Arnold, Bro, PPL), the exercise library's how-to detail, and supportive tone.
- **Platform:** iOS **and** Android — likely a **simultaneous** launch on both; if sequenced, iOS first. Either way, iOS readiness is on the critical path (APNs, Live Activities, HealthKit, on-device IAP, and App Store review all gate on the Apple Developer account).

### 3.1 Personas
- **The Optimizer** — tracks every set/RPE, wants progress charts and recovery accuracy.
- **The Competitor** — motivated by the leaderboard, streaks, and challenges.
- **The Newcomer** — needs a ready-made program, clear instructions, and a gentle voice.

---

## 4. Monetization

### 4.1 Model — Hard Paywall + Trial
- **Subscription-only.** The entire app is premium.
- **7-day free trial**, then a subscription is **required** to continue.
- Products: `mgb_monthly`, `mgb_yearly` via **RevenueCat**.
- Entitlement source of truth: `UserProfiles.subscriptionStatus` (`trial` / `active` / `grace_period` / `expired`), reconciled by `SubscriptionSyncService`; server truth via RevenueCat webhook; trial-window fallback via `verify-subscription`.

### 4.2 Trial & Gate Behavior
- Trial begins at first sign-up (`trial_started_at`).
- During trial: full access.
- On expiry without active subscription: app routes to the **paywall** and blocks core use until subscribed or restored.
- **Restore Purchases** and **Delete Account** always available (store requirement).

### 4.3 Skins — Secondary Layer
- Cosmetic anatomy-body skins follow a **mixed model**: some **earned** (streaks, leaderboard placement, challenge completion), some **purchasable** (one-time IAP via RevenueCat).
- Skins are cosmetic only — never gate training data or fairness.

### 4.4 Compliance
- IAP only through RevenueCat; no external payment links.
- Privacy manifest, ATT prompt (if any tracking), data-deletion path — all required for review.

---

## 5. Feature Specifications

### 5.1 Onboarding & Auth *(built)*
- Multi-screen intake: language, gender, birthday, height, weight, goal, experience, target zones, **notification tone**, trial intro.
- Email + password (validated) and Google/Apple OAuth.
- Intake persists to Supabase `user_profiles` on sign-up; exercises seed on first launch.
- **To add:** the paywall gate at trial expiry (see §4.2).

### 5.2 Workout Logging & Active Session *(built)*
- Start a session from a schedule day or freeform.
- Log sets with weight, reps, RPE, and flags: **warmup / dropset / failure / completed**.
- Cardio fields supported (duration, distance, speed, incline).
- **Rest timer**: countdown with sound + haptics, persistent across app kill, actionable notification (complete set / skip / ±15s).
- Wakelock during active sessions.
- Session logs + a status sheet (body/workout status, trends).

### 5.3 Schedules & Exercise Library *(built)*
- Multi-day program builder (named, day tabs, rest days, per-exercise target sets/reps/duration/distance), one active schedule.
- 3 seeded default programs (Arnold, Bro, PPL).
- Exercise browser: search + filter by muscle / equipment / difficulty; recents + A–Z; favorites; usage counts.
- Exercise detail: GIF/how-to, target & secondary muscles, equipment, instructions.

### 5.4 Anatomy Body *(partial → finish)*
The visual centerpiece. Per-muscle SVG overlays on a gendered base body.

- **Recovery view** *(built)*: colors each muscle group by recovery state (fatigued red → amber → recovered green) derived from recent volume and time. Tap a muscle for detail.
- **Volume view** *(to build)*: a second mode that colors/annotates muscles by **training emphasis/volume** over a selectable window (e.g., this week). Lets users see what they're over/under-training.
- **Mode toggle** between Recovery and Volume.
- **Skins** restyle the base body (see §5.10).
- Both genders, front view minimum; posterior assets exist and may be surfaced.

### 5.5 Coaching Tone System *(partial → finish)*
- Every notification and motivation message ships in **4 tones**: `supportive`, `balanced` (default), `bold`, `savage`.
- Tone chosen in onboarding and editable in Settings; each option shows an example line.
- Resolution at delivery time; null/missing → `balanced` fallback.
- Local notifications already tone-aware; **Supabase motivation messages** must resolve tone server-side (see `04-BACKEND.md`).
- **Compliance:** copy is **preset, human-written templates** — not AI-generated and not medical/professional advice. Never market this as an "AI coach"; avoid wording that implies clinical guidance or guaranteed results (App Store guidelines 1.4.1 / 2.3).

### 5.6 Social Graph — Followers & Friends *(to build)*
- **One-way following** (no approval) — follow/unfollow anyone, Instagram-style.
- **Mutual follow = friends:** when A follows B *and* B follows A, they become **friends** automatically (no separate request flow).
- Friends unlock the **Friends leaderboard** scope (head-to-head competition) and friend-only surfacing.
- Profiles show **followers / following counts** (and friend count).
- No DMs (the DM subsystem is being removed).

### 5.7 Public Profiles *(partial → finish)*
- Public profile shows: avatar, banner, display name, **gendered anatomy body**, **streak**, **achievements**, **posts**, follower/following counts.
- Tabs: Status / Achievements / Posts.
- Privacy: profiles are viewable by other users; sensitive raw data (exact bodyweight, etc.) stays private unless the user opts to show it.

### 5.8 Community Feed *(mock → build)*
- Subscriber-only feed of posts (text + image), likes, comments.
- Post composer (text + image upload to Supabase Storage `community-images`).
- Backed by Supabase `posts` / `post_likes` / `post_comments` (tables + RLS already exist) — replace `CommunityMockData` with a real `SupabaseCommunityRepository`.

### 5.9 Challenges *(mock → build)*
- **Two sources:** **curated** (you / a Supabase table + cron define a daily challenge) and **community-created** (users submit challenges others can join).
- Community submissions require **moderation** (report + review/hide).
- Completing challenges awards **challenge points** (feeds the leaderboard composite).
- Per-challenge participation; a challenge has a goal, window, and participant set.

### 5.10 Cosmetic Skins *(partial → finish)*
- Restyle the anatomy body (≈20 PNG variants per gender already in `assets/skins/`).
- **Mixed economy:** some skins **earned** via achievements/leaderboard/challenges; premium/exclusive ones **purchasable** (RevenueCat one-time products).
- Needs: a **skins gallery** (owned / earnable / buyable), ownership records, preview, and selection (current code wires only 3 of ~20).

### 5.11 Leaderboard *(mock → build)*
- **Scopes:** **Global** (everyone), **Friends** (mutual follows, §5.6), and **Rivals** (auto-matched peers, below). Same scoring within each scope.
- **Composite score** = **average of three normalized components**:
  1. **Workout streak** (consistency)
  2. **Total volume** (weight × reps)
  3. **Challenge points** (from §5.9)
- **Boards:** **All-time** (cumulative, never resets) + **Weekly season** (resets every Monday) + **Monthly season** (resets on the 1st), within each scope.
- **Seasons reset and crown a winner:** at each weekly/monthly boundary the standings finalize, a winner is recorded, and the board starts fresh. Aligns with the weekly Rivals pods and weekly reports for a shared re-engagement beat. (All-time never resets.)
- Season placements feed achievements and can unlock **earned skins** (§5.10).
- Each component is normalized to a comparable 0–100 scale before averaging, so no single metric dominates (see `04-BACKEND.md` for the scoring contract).
- Shows rank, score, a **countdown to next reset**, the last winner, and the user's own position; tap a row → that user's public profile.

**Rivals scope:** the app auto-matches the user against a small cohort of people with **similar data and progress** — comparable composite score, experience level, and recent volume — so competition feels fair and winnable.
- Matched into a **rivals pod** (~10–20 users including you), refreshed **weekly** — so the pod *is* your weekly season competition (Rivals aligns naturally with the weekly reset).
- Ranked within the pod by composite (and surfacing progress deltas), creating a personal, beatable rivalry; the weekly pod winner is crowned at reset.
- New/low-data users are matched with other newcomers.

### 5.12 Progress Charts (Status Log) *(to build)*
- Visual graphs comparing **identical past sessions** over time (e.g., this week's Leg Day vs. last week's): volume, top set, est. 1RM trend per exercise.
- Lives in the status/profile area.

### 5.13 Share Cards *(to build)*
- On session completion, generate a **shareable summary card** (volume, duration, PRs, streak) as an image to share externally or post to the feed.

### 5.16 Training Calendar *(to build)*
- On **Home**, tapping the day strip opens a **calendar** view.
- The calendar marks every day the user trained (worked days highlighted) across past months.
- Tapping a day shows that day's session(s) with a summary and a route into the full session log.
- Data is local (Drift `Sessions`) so the calendar works fully offline.

### 5.17 Periodic Reports — Weekly & Monthly *(to build)*
- The app generates **weekly and monthly progress reports** showing the user's **improvement vs. the previous period**: total volume, sessions completed, PRs, streak, and muscle-group balance, each with a **delta** (▲/▼ vs. last week/month).
- Reports are **pushed as notifications** (tone-aware) when a new one is ready (weekly on a fixed day, monthly at month end).
- Reports are also browsable in-app at **Workout → Status sheet → "Reports" button**, opening a Reports window listing past weekly/monthly reports.
- Complements Progress Charts (§5.12): charts are exercise-level trends; reports are period summaries with deltas.
- Generated server-side (scheduled edge function) and snapshotted so history is reviewable; see `03-DATABASE.md` / `04-BACKEND.md`.

### 5.18 Wearable & Health Integration *(to build — v1)*
- Integrate with **Apple Health / Apple Watch** (iOS) and **Google Fit / Health Connect** (Android) via the Flutter `health` package.
- **Read** (with explicit user permission): heart rate, active energy/calories, bodyweight, and externally-logged workouts — used to enrich sessions, status, and recovery.
- **Write back:** completed MyGymBro sessions are written as workouts to Health/Fit so the user's broader health profile stays in sync.
- **Apple Watch:** during an active session, surface **live heart rate** and write the workout via a HealthKit workout session; (a dedicated standalone watchOS app is a candidate follow-up, not required for v1).
- **Permissions & compliance:** request Health scopes contextually with clear rationale; satisfy HealthKit usage-string + entitlement and Health Connect requirements; **never use Health data for advertising** (store policy). Health access is optional — the app fully works without it.
- New session fields capture imported metrics (avg/max heart rate, active energy) — see `03-DATABASE.md`.

### 5.14 Settings *(partial)*
- Profile, language, weight unit, default rest time, notification tone, subscription management, data/sync, support, **delete account**, version.
- Skins entry → gallery.

### 5.15 Notifications & Widgets *(partial → finish)*
- Local notifications (rest timer, reminders, active session) + FCM push.
- Workout-reminder escalation by rest days, per tone.
- iOS Live Activity (best-effort) + home-screen widget (streak / next focus).
- **To finish:** force-kill resilience (resync on resume), reminder scheduling clarity.

---

## 6. Localization

- Locales: **English (source), German, Spanish, French**.
- All UI via ARB + `gen-l10n`.
- **Gap to close:** DE/ES/FR are ~77% (≈84 keys missing each) — backfill before launch.
- Tone voice **sample lines** may intentionally stay in English to preserve voice; everything else must be translated.
- Numbers/dates/units formatted per locale; weight unit (kg/lb) user-selectable.

---

## 7. Out of Scope (v1)

- ❌ Direct messages (the existing DM subsystem is being **removed**).
- ❌ Country/region or per-challenge leaderboard scopes (future; v1 has Global + Friends + Rivals).
- ❌ Web/desktop clients.
- ❌ Dedicated standalone watchOS app (v1 uses HealthKit/Watch via the phone; native watch app is a follow-up).
- ❌ Nutrition / calorie tracking as a full feature.
- ❌ Voice/video, real-time chat.

---

## 8. Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Monetization | Hard paywall after 7-day trial | Simple, premium positioning, predictable revenue |
| Social graph | One-way followers; **mutual follow = friends** | Instagram-style; low friction, no request flow; mutual unlocks Friends competition |
| Leaderboard score | Composite avg of streak + volume + challenge points | Rewards balanced behavior, not one metric |
| Leaderboard scope | **Global + Friends + Rivals** | Global for reach, Friends for personal rivalry, Rivals for fair matched competition |
| Rivals matching | Similar composite + experience + volume; weekly pod of ~10–20 | Fair, beatable competition vs. peers of equal level |
| Leaderboard windows | All-time + **fixed weekly & monthly seasons** (reset + crowned winner) | Re-engagement beat; pairs with weekly Rivals + reports; winners feed achievements/skins |
| Periodic reports | Weekly + monthly, pushed + in Status→Reports | Show improvement vs. past; drives re-engagement |
| Home day strip | Tap → training calendar of worked days/sessions | Easy review of training history |
| Light-mode accent | **Orange** (lime stays dark-mode only) | Lime is low-contrast on light backgrounds |
| Wearables | Apple Health/Watch + Google Fit/Health Connect in v1 | Enrich sessions/recovery with HR & energy; sync workouts to health profile |
| Challenges | Curated + community-created (moderated) | Fresh content + engagement, with safety |
| Skins | Earned + purchasable mix | Engagement driver + secondary revenue |
| Anatomy view | Recovery + Volume modes | Recovery guides training; volume reveals balance |
| Coaching voice | 4 tones, balanced default | Avoids alienating sensitive users; opt-in to harsh |
| DMs | Removed | Out of scope; reduces moderation/abuse surface |
| Languages | en/de/es/fr | Current target markets |
| Offline-first | Local Drift write → queued Supabase sync | Reliability in the gym |
| Security scope | No biometric/SQLCipher/cert-pinning/jailbreak | Solo project, ship pragmatically |

---

**End of PRD**
