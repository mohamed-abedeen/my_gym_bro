# SETUP-STATUS — external services & release readiness

> **Last verified: 2026-08-04.** This doc covers what a fresh clone can NOT tell you: which
> cloud services are live, which are half-configured, and what must change before a store
> release. It exists because this state lives in dashboards (App Store Connect, RevenueCat,
> Supabase, Firebase), not in code. When you complete an item here, update this doc in the
> same PR. The historical code audit is `STATUS.md` (2026-05-28, stale); the test checklist
> is `TESTING.md`.
>
> ⚠️ Never commit secret **values** to this repo — this doc names secrets, it never contains them.

---

## TL;DR

| Service | State |
|---|---|
| TestFlight CI lane | ✅ **Green.** Builds distributed to external testers |
| App Store Connect subscriptions | 🟡 Created, stuck at "Missing Metadata" (screenshot pending) |
| RevenueCat | 🟡 Project + products exist; entitlement/offering/webhook/keys pending |
| Supabase **cloud** | 🟡 Live for auth/data, but behind the repo (db push, function secrets, config push pending) |
| Apple sign-in (Supabase side) | 🔴 Provider not enabled in dashboard — errors until then |
| Firebase (Crashlytics + FCM) | 🔴 Untouched — no config files in repo, Crashlytics inert, no push |
| Exercise data license | 🔴 **Store-release blocker** — running on non-commercial OSS data |
| Paywall in beta builds | ⚠️ Disabled via `BETA_FREE=true` — must be removed for store builds |

---

## TestFlight / CI (working — don't regress)

`.github/workflows/testflight.yml`, manual `workflow_dispatch` from `main`. Builds a signed
IPA on GitHub's Mac runners and uploads to TestFlight — no local Mac needed.

- **Pins that must not change casually:** runner `macos-26` (Xcode 26 — `cupertino_native_better`
  needs Liquid Glass APIs), Flutter **3.41.1** (newer stable removed
  `CupertinoPageTransitionsBuilder` used in `lib/app.dart`), iOS deployment target **15.0**.
- Build number = CI `run_number` (cancelled runs still consume numbers).
- **`--dart-define=BETA_FREE=true` is in the lane** — it short-circuits the paywall/trial gate
  (`kBetaFreeAccess` in `lib/features/workout/workout_providers.dart`). **Remove it the day
  this lane produces store builds.**
- `--dart-define=REVENUECAT_IOS_KEY=${{ secrets.REVENUECAT_IOS_KEY }}` is wired in the yml,
  but the GitHub secret is **not set yet** (verified 2026-08-04) — resolves empty, app skips
  RevenueCat configure. Set it once RevenueCat setup (below) finishes.
- GitHub secrets currently set: `APP_STORE_CONNECT_ISSUER_ID` / `_KEY_IDENTIFIER` /
  `_PRIVATE_KEY`, `CERTIFICATE_PRIVATE_KEY` (backup of the Apple distribution cert key —
  losing it orphans the cert), `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- External tester group "my gym bro testers1" with a public TestFlight link exists. Since
  2026-08-10 the lane handles distribution itself: `app-store-connect publish` runs with
  `--testflight --beta-group "my gym bro testers1"`, which waits for Apple processing, submits
  for beta review, and assigns the group (assignment alone would not auto-submit;
  post-first-review approvals are instant). No manual ASC step remains for beta builds.
- Gotcha: `purchases_flutter` on iOS **fatalErrors (uncatchable)** if any `Purchases.*` call
  runs before `configure()` — every new call site needs an `await Purchases.isConfigured`
  guard (Android throws catchably, so you won't see it in dev).

## RevenueCat + App Store Connect (in progress — stopped mid-way 2026-08-03)

**Done:** ASC subscription group "Premium" with `mgb_premium_monthly` + `mgb_premium_annual`
(prices, en/de/es/fr localizations, 1-week free intro offers matching the app's 7-day-trial
copy). RevenueCat project "My Gym Bro" with both products; ASC API key connected. Code uses
the real product IDs; entitlement id in code is **`premium`**
(`subscription_sync_service.dart`); the paywall falls back to the offering's Monthly/Annual
packages if IDs mismatch.

**Pending — owner, in the dashboards, in this order:**
1. ASC: add a review screenshot on BOTH subscriptions → status must reach "Ready to Submit"
   (currently "Missing Metadata"; sandbox fetches can fail until then). Do NOT press "Add
   for Review" — first subscriptions ride along with an app version.
2. ASC → Business: confirm the **Paid Applications agreement** is Active with banking + tax
   (most common cause of empty offerings).
3. RevenueCat: upload an **In-App Purchase key** (separate key type: ASC → Users and Access →
   Integrations → In-App Purchase).
4. RevenueCat: entitlement **`premium`** (exact string) attached to both products; `default`
   offering with Monthly → `mgb_premium_monthly`, Annual → `mgb_premium_annual`.
5. RevenueCat: webhook → `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`
   with a long random Authorization header value (save the string — it becomes
   `REVENUECAT_WEBHOOK_SECRET`).

**Then — repo/CLI side:** set the `REVENUECAT_IOS_KEY` GitHub secret (`appl_…` public SDK
key), set `REVENUECAT_WEBHOOK_SECRET` on Supabase, deploy (next section), then an end-to-end
sandbox purchase test.

**Skin one-time products (Phase 6.2, added 2026-08-17):** the client + `purchase-skin`
edge function are wired for three **non-consumable** IAPs — `mgb_skin_gold`,
`mgb_skin_galaxy`, `mgb_skin_teddy_bear` (ids must match the `skins` catalog seeds in
migration 016 and `skin_provider.dart`). Owner steps, after the subscription flow above:
1. ASC: create the three in-app purchases (type **Non-Consumable**), price + en/de/es/fr
   localizations + review screenshot each.
2. RevenueCat: add the three products to the project (no entitlement needed — ownership is
   granted via `purchase-skin`, not an entitlement).
3. Supabase: `supabase secrets set REVENUECAT_SECRET_KEY=sk_…` (a RevenueCat **secret** API
   key — new secret, separate from the webhook one). `purchase-skin` returns 503 until set;
   the app degrades to a local, receipt-derived unlock and heals server-side on the next
   restore once the secret exists.
⚠️ The whole server-verification path is **deployable but untested** until this setup
finishes — test a sandbox skin purchase + restore end-to-end then.

## Supabase cloud (behind the repo — deploy pending)

The cloud project serves auth + data for beta builds, but repo state has NOT been fully
pushed. As of the last check the following were pending — **verify with
`supabase migration list` before relying on cloud state**:

- `supabase db push` — repo migrations go up to `016_skins.sql`
  (012 = Bros Phase B friendships, 013 = feed/bucket drop + `delete_account_data`
  rewrite, 014 = Phase 4 challenges + leaderboard points wiring +
  another `delete_account_data` rewrite; authored 2026-08-15/16, **never run
  against cloud**); cloud is known
  to be several behind (at minimum 007–014, incl. `009_security_hardening.sql` which
  closes a real paywall-bypass hole). ⚠️ 012 and 013 must land together: 012 drops
  `follows` and only 013 rewrites `delete_account_data` to stop referencing it —
  012 without 013 breaks account deletion (store blocker). After pushing, run the
  RLS matrix in 012's header (request/accept/decline/block both sides, username-claim
  race, `leaderboard_friends` still returns rows) and verify delete-account end to end.
- **Challenges (014) deploy notes:** the completion-push trigger reads the same
  Vault secrets 010 documents (`project_url`, `cron_secret`) — it silently
  skips pushes until they exist. `notify-social-challenge` must be redeployed
  with `verify_jwt` **off** (it self-authenticates: user JWT for PRs,
  `x-cron-secret` from the DB trigger — config.toml already set). 014 also
  schedules the `seed-daily-challenge` pg_cron job and seeds deploy-day's
  curated challenge immediately. Post-deploy check: curated card appears in
  the app, join → complete → `points_awarded` set by the trigger, hourly
  `compute-leaderboard` picks points up in the composite.
- **Skins (016) deploy notes (2026-08-17):** schedules `evaluate-earned-skins-daily`
  (00:20 UTC, after finalize_season) — same Vault secrets as 010; run
  `SELECT evaluate_earned_skins();` once after push so existing users get their
  session-based grants immediately. Deploy the `purchase-skin` function (verify_jwt stays
  ON — no config change) and set `REVENUECAT_SECRET_KEY` (RevenueCat section above).
  ✅ **Grants audit resolved by `018_api_role_grants.sql` (2026-08-18):** confirmed
  empirically on a fresh local stack — WITHOUT 018, every table from 001–015 had no
  DML grants for `authenticated` OR `service_role` (challenge joins/friend requests/
  profile PATCHes 403'd; the RevenueCat webhook 500'd on "permission denied for table
  subscriptions"). 018 backfills grants for both roles per the RLS policy surface
  (user_profiles keeps 009's column-scoped write lockdown; anon gets nothing). The
  existing cloud project predates the 2026-05-30 default flip, so 018 is a no-op
  there — it protects fresh projects, preview branches, and local stacks. Post-deploy check: gallery shows owned skins after
  a `skin_ownership` grant; profile-field sync verified (a 2026-08-17 client fix — 
  `user_profiles` PATCHes were silently matching zero rows by keying on `id` instead of
  `user_id`, which also broke tone/username sync; verify tone + skin selection land in
  the cloud row). Also note: 013's storage cleanup was rewritten 2026-08-17 (current
  Storage API forbids direct DML on storage tables; the DO block downgrades it to a
  NOTICE) — if the cloud bucket ever had objects, empty it via the Storage API.
- ✅ **Workout-data push RESOLVED (2026-08-18, was the blocker for every
  server-side workout feature):** `push_workout` RPC (migration 019) + a new
  `rpc` outbox op — one atomic item per finished session, client-generated
  uuids for idempotent re-push, sign-in backfill for all pre-019 history
  (stateless: any finished session without a remoteId), server soft-delete on
  history deletion, sync parked while signed out. Adversarially reviewed
  (a reproduced concurrent-backfill double-push bug was fixed with atomic
  in-transaction uuid claims) and validated end-to-end on the local stack.
  Post-deploy: existing beta users' full history uploads on their next
  sign-in (capped 200 sessions/scan), after which leaderboard volume,
  challenge validation, the bros strip, earned skins, and reports all have
  real data.
- **Reports (017) deploy notes (2026-08-18):** schedules `generate-reports-weekly`
  (Wed 00:15 UTC) + `generate-reports-monthly` (3rd 00:15) — 48 h after each period
  boundary (015's late-sync grace precedent) — pure SQL, same Vault secrets as 010
  for the `report_ready` pushes. Nothing to run at deploy: the first reports
  generate at the next Wednesday/3rd. Post-deploy check: `progress_reports` has
  rows, the Reports window lists them, and users with sessions got the
  tone-resolved push. (Depends on the workout-data sync blocker above.)
- **Seasons (015) deploy notes:** schedules `finalize-season-weekly` (Wed
  00:02 UTC), `finalize-season-monthly` (3rd 00:02) — 48 h after each
  boundary so offline late-syncs still count — plus `assign-rivals-weekly`
  (Mon 00:10), and runs `assign_rivals()` once at deploy so pods exist
  immediately. Season pushes go through `send-push-notification`
  (`kind: season_ended`, tone-resolved) — same Vault secrets as 010.
  Post-deploy check: rivals scope shows a pod; after the first Monday,
  `season_results` has rows, the winner banner renders, and top-3 got the
  push.
- **Bros invite deep link** — `https://mygymbro.app/bro/<username>` is generated/QR-encoded
  by the client and the in-app `/bro/:username` route exists, but the universal-link
  platform config (Apple AASA, Android assetlinks, and the web fallback page with the App
  Store link) is NOT set up; external links won't open the app until it is.
- `supabase functions deploy` — 7 functions in `supabase/functions/`; deployed versions are
  stale. Mind `verify_jwt`: `revenuecat-webhook` and cron-invoked functions must be deployed
  with JWT verification off (config or `--no-verify-jwt`) or they're dead behind the gate.
- **Function secrets** (`supabase secrets set …`): `SERVICE_ROLE_KEY` (custom name — the
  code does NOT read the auto-injected `SUPABASE_SERVICE_ROLE_KEY`), `FCM_SERVER_KEY`,
  `REVENUECAT_WEBHOOK_SECRET`.
- `supabase config push` — `config.toml` carries SMTP (Resend) settings; owner must also
  create the Resend account, verify the sending domain, mirror SMTP in dashboard Auth
  settings, and raise Auth email rate limits. Also outstanding from the security audit:
  `otp_expiry` (reset links 60 min, want ≤30) and `site_url`/redirects still `127.0.0.1`.
- **Auth → Providers → Apple: enable + authorized client ID `com.mygymbro.myGymBro`.** The
  app is OAuth-only (Google all platforms + native Apple on iOS; email/password removed from
  the UI) — **Apple sign-in fails until this is flipped.**

## Firebase — untouched

No `android/app/google-services.json`, no `ios/Runner/GoogleService-Info.plist` (verified
2026-08-04). Consequences: Crashlytics is inert in all builds; FCM push (and the
notification edge functions' delivery) cannot work. Owner must register both apps (iOS
`com.mygymbro.myGymBro`, Android `com.mygymbro.my_gym_bro`), enable Crashlytics, set up
FCM V1 + APNs key, and produce a service-account JSON for the edge functions.

## Exercise data license — store-release blocker

The app currently syncs its catalogue from the free **ExerciseDB OSS v1 API**
(`oss.exercisedb.dev`) whose license is **non-commercial — it must not ship in the paid
release**. Decision on record: buy the **ExerciseDB.io one-time dataset license** (Mobile
$299) at deployment and swap the source. `assets/exercises_starter.json` is the small
bundled fallback. History in `08-WORKOUTX-MIGRATION.md` (superseded WorkoutX era).

## Security audit — known-open items (as of 2026-07-14; re-verify before fixing)

- Onboarding **Skip button** has no `kDebugMode` guard (owner is keeping it during beta —
  remove/gate before store release).
- Supabase session tokens in plaintext `SharedPreferences`; Drift DB unencrypted;
  `subscriptionLockedProvider` fails open on a null profile.
- `otp_expiry` / `site_url` (see Supabase section). Fixed already: column-level REVOKE on
  subscription columns (009), cron-secret on `send-push-notification`, fail-fast release
  signing (no debug-keystore fallback).

## Testing state

`TESTING.md` is the authoritative checklist. Big picture: the backend phases were verified
against a **local** Supabase stack, not cloud; large parts of the app have never had an
on-device pass with real keys (cloud auth, paywall purchase/restore, sync).

**2026-08-18 local validation:** migrations 001→019 replay cleanly on a current stack,
and `supabase/tests/local_integration.sh` (44 assertions, incl. workout push/heal/
hijack; needs the stack +
`supabase functions serve` with CRON_SECRET/REVENUECAT_WEBHOOK_SECRET test env) passes
end-to-end: RevenueCat webhook purchase/expiration → gate flips, verify-subscription,
challenge join/award/moderation RLS + triggers, leaderboard scoring + friends/rivals/
season RPCs + winner, earned-skin grants (sessions + season-win rules, idempotent),
skin anti-spoof + selection sync + public profile, purchase-skin auth/fail-soft,
weekly report metrics/deltas/PR-count + RLS, delete_account_data full wipe. NOT
covered (impossible without a device + finished RevenueCat setup): real StoreKit/Play
purchases, purchase-skin's happy path against live RevenueCat, push delivery via FCM. A plain
`flutter run` with no `--dart-define`s runs fully offline (Supabase/RevenueCat inert) —
that's the safe default for UI work.

## Only-the-owner-can-do list (short form)

ASC/RevenueCat dashboard steps above · Paid Apps agreement · Firebase project + config
files · Supabase dashboard toggles (Apple provider, SMTP, rate limits) · ExerciseDB $299
license · store listings/policy pages/data-safety forms · anything needing a physical Mac
(iOS widget-extension target, VoiceOver labels on the native tab bar).
