# 02 — Technical Architecture
## MyGymBro — System Architecture Specification

---

## 1. High-Level Architecture

```
┌───────────────────────────────────────────────────────────┐
│                     Flutter App (iOS / Android)             │
│                                                             │
│  UI (screens, glass widgets)                                │
│        │  watches/reads                                     │
│  Riverpod providers  ──────────────┐                        │
│        │                           │                        │
│  Repositories / Services           │                        │
│   ├─ WorkoutLogRepository          │                        │
│   ├─ CommunityRepository           │                        │
│   ├─ MuscleRecoveryService         │                        │
│   ├─ NotificationService (+tone)   │                        │
│   ├─ SubscriptionSyncService       │                        │
│   └─ SyncService  ─────────┐       │                        │
│        │ writes local      │ push  │ auth/purchase          │
│  ┌─────▼──────┐      ┌──────▼───────▼─────────────────────┐ │
│  │ Drift DB   │      │ Supabase  │ RevenueCat │ Firebase   │ │
│  │ (SQLite)   │      │ client    │  client    │ (FCM/Crash)│ │
│  └────────────┘      └─────┬─────┴────────────┴────────────┘ │
└────────────────────────────┼─────────────────────────────────┘
                             │ HTTPS
        ┌────────────────────┼───────────────────────────┐
        │                    │                           │
 ┌──────▼───────┐   ┌────────▼─────────┐        ┌────────▼────────┐
 │  Supabase    │   │  Edge Functions  │        │   RevenueCat    │
 │  Postgres    │   │  (Deno)          │        │   (IAP truth)   │
 │  + RLS       │   │  verify-sub,     │        └────────┬────────┘
 │  + Storage   │   │  webhook, push…  │   webhook       │
 └──────────────┘   └──────────────────┘◄────────────────┘
```

**Principle:** the **local Drift DB is the working source of truth** for the user's own data; Supabase is the durable/shared backend reached via a background sync queue. The app is fully usable offline.

---

## 2. Technology Stack

### 2.1 App
| Technology | Purpose |
|-----------|---------|
| Flutter (Dart ^3.7) | Cross-platform UI |
| Riverpod (`flutter_riverpod`, `riverpod_generator`, `riverpod_annotation`) | State & DI |
| Drift (`drift`, `drift_flutter`, `sqlite3_flutter_libs`) | Local SQLite ORM |
| go_router | Declarative routing |
| `oc_liquid_glass` | Liquid-glass shader effects |
| `flutter_svg` | Anatomy muscle overlays |
| `google_fonts` | Familjen Grotesk (accent typography) |
| `flutter_local_notifications` | Local + rest-timer notifications |
| `home_widget` | Home-screen widgets |
| `audioplayers`, `vibration`, `wakelock_plus` | Rest timer feedback, screen-on |
| `cached_network_image`, `image_picker` | Media |
| `connectivity_plus` | Online/offline detection for sync |
| `flutter_secure_storage`, `crypto` | Secrets, hashing |
| `health` | Apple HealthKit / Google Health Connect (heart rate, energy, bodyweight, workouts) |

### 2.2 Backend & Services
| Technology | Purpose |
|-----------|---------|
| Supabase Auth | Email/password + Google/Apple OAuth |
| Supabase Postgres + RLS | Cloud data store |
| Supabase Storage | `community-images`, avatars |
| Supabase Edge Functions (Deno) | Server logic, push, webhooks |
| RevenueCat (`purchases_flutter`) | Subscriptions + one-time skin IAP |
| Firebase Cloud Messaging | Push delivery |
| Firebase Crashlytics | Crash reporting |

---

## 3. App Layering

```
Screens (Widgets)
   │ watch
Providers (Riverpod)        ← DI + reactive state
   │ call
Repositories / Services     ← business logic, orchestration
   │ read/write
DAOs (Drift)  +  Supabase client  +  RevenueCat  +  FCM
   │
SyncService                 ← reconciles local ↔ cloud
```

- **Screens** are dumb-ish: watch providers, render glass UI, dispatch intents.
- **Providers** (`lib/core/providers/providers.dart`) wire the database, Supabase client (nullable), sync service, and auth notifier. Feature providers live beside their features.
- **Repositories/Services** hold logic (workout logging, recovery math, community fetch, scoring, notifications).
- **DAOs** are the only things that touch Drift tables.

### 3.1 Key Providers (DI)
- `databaseProvider` — live Drift instance (overridden at bootstrap).
- `supabaseProvider` — `Supabase.instance.client` or **null** if uninitialized.
- `isSupabaseAvailableProvider` — bool gate for cloud-dependent UI.
- `syncServiceProvider` — `SyncService(db, supabase?)`.
- `authNotifierProvider` — Supabase auth + RevenueCat login.

---

## 4. Offline-First Sync Model

### 4.1 Write Path
1. User action → DAO writes to Drift (instant).
2. The same change is enqueued into **`SyncQueue`** (`syncTableName`, `rowId`, `operation`, JSON `payload`, `isSynced=false`).
3. `SyncService.syncAll()` runs on connect, after login, and fire-and-forget after enqueue.

### 4.2 Push Path
For each pending queue item (oldest first):
- **Insert** → POST payload to the Supabase table → store returned `remote_id` → mark synced.
- **Update** → resolve `remote_id` (from payload or local row) → PATCH → mark synced.
- **Delete** → resolve `remote_id` → DELETE (soft where applicable) → mark synced.
- **Deferred**: if `remote_id` is still null (parent insert not yet synced), skip and retry next pass. This makes ordering self-healing.
- Synced items are cleaned up after each pass. Failures use exponential backoff (1s/2s/4s, max 3 retries).

> **Note:** the historical empty-`{}`-payload bug is **fixed** — payloads serialize real Drift row data (`jsonEncode`).

### 4.3 Conflict Policy
- **Last-write-wins.** Acceptable because data is single-user-owned. No field-level merge. (Document any future multi-device edge cases here if they arise.)

### 4.4 Subscription Sync
- `SubscriptionSyncService` reconciles RevenueCat entitlements → `UserProfiles.subscriptionStatus` + `subscriptionExpiresAt` on app start, purchase, and restore.

### 4.5 Degradation
- If Supabase keys are placeholders / init throws → `supabaseProvider` is null, sync no-ops, auth returns "not connected", RevenueCat calls are best-effort. **The app still runs locally.**

---

## 5. Data Architecture

- **Local:** Drift schema **v12**, every table carries `localId / remoteId / syncStatus / createdAt / updatedAt / deletedAt`.
- **Cloud:** Supabase Postgres with **RLS on every user-scoped table** (`auth.uid() = user_id`), a `has_active_subscription()` helper gating premium reads (community), soft-delete + `updated_at` triggers, and a shared read-only `exercises` catalog.
- Full schema (current + the new tables for followers/leaderboard/challenges/skins) is in **`03-DATABASE.md`**.

---

## 6. Authentication & Authorization

- **Auth:** Supabase email/password + Google/Apple OAuth. OAuth completes via deep link; `onAuthStateChange` is the real login signal. RevenueCat `logIn()` is invoked on every auth event.
- **Authorization:** enforced at the database via **RLS** (users can only touch their own rows; community reads require an active subscription). The client does not hold privileged logic — the server is the boundary.
- **Account deletion:** `delete-account` edge function cascades soft-deletes then removes the auth user.

---

## 7. Monetization Architecture

```
App ──purchase──► RevenueCat ──webhook──► revenuecat-webhook (edge)
                     │                          │ upsert
                     │ entitlements             ▼
                     ▼                    subscriptions (Postgres)
        SubscriptionSyncService                 ▲
                     │ writes                    │ read fallback
                     ▼                    verify-subscription (edge)
          UserProfiles.subscriptionStatus  (uses trial_started_at if no sub)
```

- **Payment rails:** RevenueCat is **not** a payment processor — it wraps **Apple StoreKit IAP** (iOS) and **Google Play Billing** (Android). The native IAP sheet charges the user's App Store / Play payment method. **Apple Pay / Google Pay wallets are not used** (those are for physical goods; Apple forbids them for digital content). No external payment links (Stripe/PayPal/web checkout) for digital subscriptions — that's an automatic rejection.
- **Single gate:** UI reads `subscriptionStatus`; never re-derives entitlement per screen.
- Trial window computed from `trial_started_at`; server reconciled by webhook.
- Skins one-time IAP flow uses the same RevenueCat client; ownership recorded in a `skin_ownership` table (see `03-DATABASE.md`).

---

## 8. Notifications Architecture

- **Local:** `flutter_local_notifications` with 3 channels (rest_timer, workout_reminder, active_session); rest-timer state persisted to disk to survive force-kill; actionable buttons (complete/skip/±15s).
- **Tone:** `notification_tone.dart` resolves title/body per tone + locale. Client notifications already tone-aware.
- **Push:** FCM; edge functions (`schedule-notifications`, `notify-social-challenge`, `send-push-notification`) send to FCM tokens stored on profiles.
- **Server tone:** motivation/push copy must resolve tone at delivery time from the user's stored tone (see `04-BACKEND.md`).
- **iOS Live Activity** (best-effort) + **home_widget** (streak/next focus) via `widget_sync_service`.
- **Known gap:** force-kill leaves stale action buttons; v1 fix = resync on resume (documented in `docs/notification-recovery.md`).

---

## 8a. Wearable & Health Integration

- **Library:** the Flutter `health` package abstracts **Apple HealthKit** (iOS) and **Google Health Connect** (Android; the successor to the deprecated Google Fit APIs).
- **Read:** heart rate, active energy, bodyweight, external workouts — pulled with explicit, contextual permission and merged into the local Drift store (new `Sessions` fields: avg/max HR, active energy).
- **Write:** completed MyGymBro sessions are written back as HealthKit/Health Connect workouts so the user's health profile stays in sync.
- **Apple Watch:** during an active session, a HealthKit workout session provides **live heart rate** on the phone (and Watch). A standalone watchOS app is out of v1 scope.
- **Boundary:** all health data stays on-device / in the user's own Health store; it is **not** uploaded to Supabase except as derived session metrics the user already syncs. Never used for advertising (store policy).
- **Degradation:** Health access is optional and permission-gated; the app is fully functional without it.
- **Platform config:** HealthKit entitlement + `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` (iOS); Health Connect permissions + manifest declarations (Android).

## 9. Security

Pragmatic, store-compliant, solo-scope:
- ✅ Supabase RLS as the authorization boundary.
- ✅ Parameterized access via Supabase/Drift (no string SQL).
- ✅ `input_sanitiser` for user-generated content (posts, names, challenges).
- ✅ `safe_logger` scrubs PII; Crashlytics for errors.
- ✅ Secrets in `.env` / secure storage, never committed.
- ✅ RevenueCat webhook HMAC-SHA256 verification.
- ❌ Deliberately **not** implemented: biometric lock, SQLCipher, cert pinning, jailbreak detection.

---

## 10. Performance

- Local reads are instant (SQLite); lists paginate where they can grow (feed, leaderboard).
- Sync batches and backs off; never blocks UI.
- Anatomy SVGs are static assets; recovery/volume coloring is computed client-side from local sessions.
- `cached_network_image` for remote media; notification images cached with a 2s timeout + text fallback.

---

## 11. Build & Platforms

- iOS-first (APNs/Live Activity needs the Apple Developer account — see `07-SETUP.md`), Android second.
- Native bits: Android home-widget provider (`MgbAppWidgetProvider.kt`), iOS `AppDelegate`/`Info.plist` for notifications/Live Activity.
- CI in `.github/workflows/ci.yml` (analyze/test/build).

---

**End of Architecture Document**
