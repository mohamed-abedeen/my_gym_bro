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
| TestFlight CI lane | ✅ **Green.** Builds distributed to external testers. Last build 2026-10-02 (run 37011215218, `main` @ `6a3ad0e`: onboarding v3 + save-day-changes) |
| App Store Connect subscriptions | 🟡 Created, stuck at "Missing Metadata" (screenshot pending) |
| RevenueCat | 🟡 Project + products exist; entitlement/offering/webhook/keys pending |
| Supabase **cloud** | 🟡 **001–022 applied; 021 + 022 verified live 2026-10-02.** The anon-key hole on `public_profiles`/`friends` is closed. **Merging a PR that adds migrations to `main` deploys them to production** (GitHub integration, confirmed 2026-10-02; see below). `delete-account` v8 (Apple token revocation) deployed + smoke-tested. Pending: in-app checks for 021/022, function secrets (`APPLE_*` etc.), `purchase-skin` deploy, config push, Apple provider toggle |
| Onboarding paywall | ⚠️ **Hard paywall since onboarding v3 (2026-09-30)** — a store build without a working RevenueCat offering leaves new users stuck at "Free Trial" (dev/beta builds show a Skip). Finish the RevenueCat checklist below before any store submission |
| Apple sign-in (Supabase side) | 🔴 Provider not enabled in dashboard — errors until then |
| Firebase (Crashlytics + FCM) | 🟡 **Wired (2026-09-08)** — CI derives options from base64 config secrets; owner still has to create the project + set the secrets |
| Exercise data license | 🔴 **Store-release blocker** — OSS default; the licensed source is a config switch (`EXERCISEDB_BASE_URL` / `EXERCISEDB_API_KEY`), see below |
| Paywall in beta builds | ⚠️ `BETA_FREE=true` stays in the TestFlight lane only |
| **App Store lane** (`app-store.yml`, 2026-09-08) | ✅ Exists — paywall ON, requires `REVENUECAT_IOS_KEY`; uploads + waits for processing, submission stays manual in ASC |

---

## TestFlight / CI (working — don't regress)

`.github/workflows/testflight.yml`, manual `workflow_dispatch` from `main`. Builds a signed
IPA on GitHub's Mac runners and uploads to TestFlight — no local Mac needed.

- **Pins that must not change casually:** runner `macos-26` (Xcode 26 — `cupertino_native_better`
  needs Liquid Glass APIs), Flutter **3.41.1** (newer stable removed
  `CupertinoPageTransitionsBuilder` used in `lib/app.dart`), iOS deployment target **15.0**.
- **Build number = App Store Connect's latest + 1** (`.github/actions/asc-build-number`,
  since 2026-09-08; was `github.run_number`, which is per-workflow and would collide with the
  store lane). Both iOS lanes share the `ios-upload` concurrency group so they never upload
  at the same time.
- **`--dart-define=BETA_FREE=true` is in this lane only** — it short-circuits the
  paywall/trial gate (`kBetaFreeAccess` in `lib/features/workout/workout_providers.dart`).
  Store builds come from `app-store.yml`, which omits it. Never add it there.
- Firebase (`FIREBASE_IOS_PLIST_B64`) and the licensed exercise source
  (`EXERCISEDB_BASE_URL` / `EXERCISEDB_API_KEY`) are picked up automatically when set —
  a TestFlight build with those + `REVENUECAT_IOS_KEY` is the on-device test build.
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

## App Store lane (`.github/workflows/app-store.yml`, added 2026-09-08)

Manual `workflow_dispatch` from `main`. Same runner/Flutter/signing as the TestFlight lane,
but: **no `BETA_FREE`** (gate live), **`REVENUECAT_IOS_KEY` required** (fails fast without
it), Firebase + licensed exercise defines when their secrets exist (warns when not). It
uploads the IPA and waits for Apple to process it, then prints the build number in the run
summary. Submission is deliberately manual: App Store Connect → App Store → version →
pick the build → complete metadata → **Add for Review** (the first subscription review
rides along with the version). The build also appears under TestFlight like any upload.

`ios/Runner/PrivacyInfo.xcprivacy` (added 2026-09-08, registered in the Xcode project)
declares the collected data types + required-reason APIs — keep it in sync with the App
Privacy labels in ASC when data collection changes.

## Secrets & variables checklist (owner — values never go in this repo)

`gh secret set NAME` prompts for the value; `gh variable set` is for non-secret config.
Already set: the four App Store Connect / certificate secrets, `SUPABASE_URL`,
`SUPABASE_ANON_KEY`. Still to set, in the order the lanes need them:

```bash
gh secret set REVENUECAT_IOS_KEY          # appl_… public SDK key (RevenueCat → API keys)
gh secret set REVENUECAT_ANDROID_KEY      # goog_… (Play lane)
# Firebase console → project settings → your apps → download config, then:
gh secret set FIREBASE_IOS_PLIST_B64     --body "$(base64 -w0 GoogleService-Info.plist)"
gh secret set FIREBASE_ANDROID_JSON_B64  --body "$(base64 -w0 google-services.json)"
# Licensed exercise data (after purchase): base URL is a plain variable, key a secret
gh variable set EXERCISEDB_BASE_URL      --body "https://…"
gh secret set EXERCISEDB_API_KEY
# Supabase deploy lane (supabase-deploy.yml): personal access token from the Supabase
# dashboard → Account → Access Tokens, plus the Sign in with Apple key for delete-account's
# token revocation — the lane pushes these to the project's function secrets:
gh secret set SUPABASE_ACCESS_TOKEN
gh secret set APPLE_TEAM_ID; gh secret set APPLE_KEY_ID
gh secret set APPLE_PRIVATE_KEY < AuthKey_XXXXXXXXXX.p8
# Play release signing (build-aab job), when ready:
gh secret set ANDROID_KEYSTORE_BASE64    --body "$(base64 -w0 upload-keystore.jks)"
gh secret set ANDROID_KEYSTORE_PASSWORD; gh secret set ANDROID_KEY_ALIAS; gh secret set ANDROID_KEY_PASSWORD
```
(macOS: `base64 -i file` instead of `base64 -w0 file`.) The lanes' first step reports
which of these are missing.

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

## Supabase cloud (001–022 applied — secrets and config pending)

Project `mygym-bro-prod` (ref `konzjrklgyuodzrrhwwv`, eu-west-1). Verified through the
Supabase connector on 2026-09-08 and again on 2026-09-30: **migrations 001–020 are all applied** and
`delete_account_data` is the 017 version. Re-verify with `supabase migration list` (or the
connector's `list_migrations`) before assuming anything newer is applied.

**⚠️ Merging to `main` IS the production deploy (confirmed 2026-10-02).** The Supabase
GitHub integration (Project Settings → Integrations → GitHub) is connected to
`mohamed-abedeen/my_gym_bro` with working directory `.`, and **Deploy to production** is on with
production branch `main`. Every PR merged to `main` that adds a migration applies it to the
production database, with no `db push` or approval step. The connector also lists the `main`
branch as `FUNCTIONS_DEPLOYED`, so edge functions probably ride along too (not checked).
Consequences:
- **The PR review is the deploy gate.** Read every migration as production SQL before merging,
  and make it safe against live data (021 was: 0 profiles, `IF NOT EXISTS`, idempotent).
- **Don't merge a migration PR you aren't ready to run in production**, even if the app code
  isn't released yet. Migrations go live on merge, while app builds only ship on TestFlight/App
  Store runs.
- After a merge, verify with the connector's `list_migrations` (or `supabase migration list`)
  and run the post-push checks the migration's header documents.
- First seen with PR #38: 021 + 022 entered the history on merge with no manual push, and
  `npx supabase db push --dry-run` then reported "Remote database is up to date".

The "Supabase Preview" PR check has failed on every PR where it ran (#1, #29, #38; the preview
branch for #38 was `MIGRATIONS_FAILED`). #29 and #38 were merged anyway. The cause hasn't been
read. The same settings panel says per-PR preview branches ("Branching") need the **Pro plan**,
and the org is on Free, so that may be related. Otherwise it's something in 001–020 that
doesn't replay on a fresh stack (the history skips 002/003/005). Until it's fixed, treat the
check as noise and review migrations by hand.

Still pending:

- ✅ **022 verified live (2026-10-02, SQL editor)** (`022_privacy_boundaries.sql`). The `pg_class`
  check shows no `anon` entry on `public_profiles`, `friends` or `friend_sessions`.
  `friends` has `security_invoker=true`, `public_profiles` `security_invoker=false` (on purpose),
  and `friend_sessions` `security_barrier=true`. `sessions_select_friends` is gone. Before the merge
  the same check showed `anon=arwdDxtm` on both views. **Still to do in the app:** @username
  lookup, a Bro's profile (Bro count), the Friends leaderboard.
  Background — read-only catalog checks on 2026-09-30 found that the project's pre-2026-05-30 default
  privileges gave `anon` AND `authenticated` ALL on `public_profiles` and `friends` (ACL
  `arwdDxtm`). Both views run as postgres (BYPASSRLS), and `public_profiles` is auto-updatable.
  So anyone holding the anon key can read every profile and friendship and INSERT/UPDATE/DELETE
  any `user_profiles` row through the view, past RLS and 009's column lockdown. The retained
  API logs (~7 days) show no request to either view or to `sessions`. Anything older can't be
  checked. 022 revokes anon, makes authenticated SELECT-only, makes `friends`
  `security_invoker`, and replaces `sessions_select_friends` with the `friend_sessions` view.
  No client change is needed. **The same default privileges still apply to every future
  migration:** new tables, views and functions are auto-granted to anon + authenticated here but
  not on fresh/local stacks, so REVOKE explicitly (03-DATABASE §4). Post-push check: the
  `pg_class` query in 022's header (no `anon` entry, `authenticated=r`,
  `security_invoker=true` on `friends`), then in the app: @username lookup, a Bro's profile
  (Bro count), the Friends leaderboard.

- ✅ **021 verified live (2026-10-02, SQL editor): all 12 columns and the
  `user_profiles_health_needs_consent` CHECK exist** (`021_onboarding_answers.sql`: onboarding answers +
  body metrics on `user_profiles`, `health_consent_at` + the
  `user_profiles_health_needs_consent` CHECK (no health values without a consent time), CHECKs
  + column grants). The pre-merge check on 2026-10-02 found none of its columns and 0
  profiles, so the CHECK could not fail. Before 021 landed, sign-up profile updates got
  PostgREST's unknown-column error. That's a transient code in `SyncService`, so such updates
  stay queued and go through on the next sync pass. **Still to do in the app** (TestFlight
  build of 2026-10-02): sign up through onboarding, then confirm the row's `training_days` /
  `focus_areas` / `birth_date` and `health_consent_at`. Turn Settings → Health data off and
  confirm the six health columns and `health_consent_at` are NULL.
  When a new migration merges to `main` (which deploys it, see above), re-run the checks its header documents (012's RLS
  matrix, the 013/014 `delete_account_data` contract). 012 and 013 must always land
  together: 012 drops `follows` and only 013 stops `delete_account_data` referencing it.
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
- **Routine shares (020) deploy notes (2026-08-29):** `routine_shares` table + 4
  SECURITY DEFINER RPCs (`create_routine_share`, `get_routine_share`,
  `increment_share_import`, `revoke_routine_share`) — plain `db push`, nothing to
  schedule, no function secrets, anon keeps zero grants (recipients are signed in).
  Post-deploy check: share a split from the app → link created; paste the
  link/code on a second account → preview renders and the import lands locally;
  `supabase/tests/local_integration.sh` has a `== routine shares ==` block.
- **Universal links (bros invite + routine shares)** — the client generates/QR-encodes
  `https://mygymbro.app/bro/<username>` and `https://mygymbro.app/s/<code>`, and the
  in-app `/bro/:username` + `/s/:code` routes exist (an `app_links` listener,
  `DeepLinkService`, handles both; Flutter's built-in deep linking is explicitly
  disabled in the manifests — do not remove those flags, they keep the Supabase
  OAuth callback out of GoRouter). **External links won't open the app until the
  owner does ALL of the following** (until then, users import via the paste-link
  dialog on the Discover screen — fully functional today):
  1. Host `https://mygymbro.app/.well-known/apple-app-site-association`
     (Content-Type `application/json`, no file extension):
     `{"applinks":{"apps":[],"details":[{"appIDs":["<TEAMID>.com.mygymbro.myGymBro"],"components":[{"/":"/s/*"},{"/":"/bro/*"}]}]}}`
  2. Host `https://mygymbro.app/.well-known/assetlinks.json` (Play App Signing
     SHA-256 from Play Console):
     `[{"relation":["delegate_permission/common.handle_all_urls"],"target":{"namespace":"android_app","package_name":"com.mygymbro.my_gym_bro","sha256_cert_fingerprints":["<RELEASE-SHA256>"]}}]`
  3. Host fallback pages at `/s/<code>` and `/bro/<username>`: "Open in My Gym Bro"
     + store badges. Until assetlinks verifies, Android 12+ opens https links in the
     browser (no chooser), so the page's open button should use
     `intent://s/<code>#Intent;scheme=https;package=com.mygymbro.my_gym_bro;end`.
  4. Apple Developer portal: enable **Associated Domains** on the App ID and
     regenerate profiles, THEN add `applinks:mygymbro.app` to
     `ios/Runner/Runner.entitlements` (deliberately NOT added yet — with the
     capability missing from the profile it breaks the green TestFlight lane) and
     verify the TestFlight lane still passes.
  5. Flip `android:autoVerify="true"` on the https intent-filter in
     `AndroidManifest.xml` once assetlinks.json is live and verified.
- `supabase functions deploy` — 8 functions in `supabase/functions/`. Cloud state 2026-09-08:
  `delete-account` **v8 = repo (Apple token revocation), deployed via the connector and
  smoke-tested (401 gates, CORS preflight 200)**; the webhook/cron functions were redeployed
  2026-09-07, `verify-subscription` 2026-08-29; **`purchase-skin` has never been deployed**;
  `moderate-content` and `report-content` exist only in the cloud (community-feed leftovers,
  delete when convenient). **No local CLI needed:** `gh workflow run supabase-deploy.yml -f functions=all`
  (`.github/workflows/supabase-deploy.yml`, added 2026-09-08) deploys from CI with
  `SUPABASE_ACCESS_TOKEN` + the project ref derived from `SUPABASE_URL`, and first syncs
  every function secret that exists as a GitHub secret of the same name. `verify_jwt` per
  function comes from `config.toml` (`revenuecat-webhook` and the cron-invoked functions are
  off there); the lane passes no flags, so keep those blocks intact.
- **Function secrets** (`supabase secrets set …`): `FCM_SERVICE_ACCOUNT` (service-account
  JSON), `REVENUECAT_SECRET_KEY`, `REVENUECAT_WEBHOOK_SECRET`, `CRON_SECRET`, and — for
  Sign in with Apple token revocation on account deletion (`delete-account`, App Store
  guideline 5.1.1(v)) — `APPLE_TEAM_ID`, `APPLE_KEY_ID`,
  `APPLE_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"` (the same .p8 the Apple provider's
  client secret is generated from; optional `APPLE_CLIENT_ID`, defaults to the bundle id).
  The service-role key is auto-injected as `SUPABASE_SERVICE_ROLE_KEY` — nothing to set.
  Without the `APPLE_*` secrets deletion still completes; the function logs
  `Apple token revocation failed (not_configured)`. Easiest path: store each as a GitHub
  secret of the same name and run the deploy lane above — it syncs whichever exist.
- `supabase config push` — `config.toml` carries SMTP (Resend) settings; owner must also
  create the Resend account, verify the sending domain, mirror SMTP in dashboard Auth
  settings, and raise Auth email rate limits. Also outstanding from the security audit:
  `otp_expiry` (reset links 60 min, want ≤30) and `site_url`/redirects still `127.0.0.1`.
- **Auth → Providers → Apple: enable + authorized client ID `com.mygymbro.myGymBro`.** The
  app is OAuth-only (Google all platforms + native Apple on iOS; email/password removed from
  the UI) — **Apple sign-in fails until this is flipped.**

## Firebase — wired, waiting for the project (2026-09-08)

The app no longer needs `google-services.json` / `GoogleService-Info.plist` in the native
projects: `Firebase.initializeApp` takes options from build-time defines
(`lib/core/services/firebase_options_env.dart`), and CI derives those defines from the
console config files stored as base64 secrets (`.github/actions/firebase-defines`, used by
the TestFlight, App Store and Android lanes). Without the secrets Firebase stays inert
exactly as before — Crashlytics off, no push. Both files are now git-ignored; never commit
them.

Owner steps: create the Firebase project, register iOS `com.mygymbro.myGymBro` and Android
`com.mygymbro.my_gym_bro`, enable Crashlytics, download both config files and set
`FIREBASE_IOS_PLIST_B64` / `FIREBASE_ANDROID_JSON_B64` (checklist above). For push on iOS
additionally: APNs key in Firebase, **Push Notifications capability on the App ID** in the
developer portal (regenerates profiles — like Associated Domains, do this before touching
`Runner.entitlements` or the green lanes break), FCM V1 + a service-account JSON for the
edge functions.

## Exercise data license — store-release blocker

The app currently syncs its catalogue from the free **ExerciseDB OSS v1 API**
(`oss.exercisedb.dev`) whose license is **non-commercial — it must not ship in the paid
release**. Decision on record: buy the **ExerciseDB.io one-time dataset license** (Mobile
$299) at deployment and swap the source. `assets/exercises_starter.json` is the small
bundled fallback.

**The swap is a config change (2026-09-08):** `ExerciseApiService` reads
`EXERCISEDB_BASE_URL`, `EXERCISEDB_API_KEY` and `EXERCISEDB_API_KEY_HEADER`
(default `x-api-key`) from dart-defines; every lane passes the repo variable + secret
through. If the licensed delivery is an API with the same `/exercises` cursor contract,
set the variable/secret and you're done; if it's a dataset dump, host it behind that
contract (e.g. a Supabase edge function) or bundle it, then point the URL there. The
store lane warns loudly while the URL is unset. History in `08-WORKOUTX-MIGRATION.md` (superseded WorkoutX era).

## Website & legal texts (added 2026-09-30)

`website/public/` is the static site for mygymbro.app. `website/README.md` has the deploy steps
(Cloudflare Pages, output dir `website/public`) and the owner placeholder checklist. The privacy
policy and terms were drafted from the app's real data flows as of 2026-09-30, for a German
registered company, users aged 16+, English only. Before publishing: fill the placeholders, have
a lawyer or legal-text service review, restore the domain, deploy. (Migration 022, which §7 depends on, is live since 2026-10-02.)

**The privacy policy assumes these app/backend changes. Ship them with the store release:**
1. ✅ **Done in the app (2026-09-30); the server half is 021, live since 2026-10-02.** Explicit
   consent for health data (GDPR Art. 9): a consent step before the body-data section, with an
   unticked box, the statement, and a link to privacy §4 (`/privacy#health`).
   "Continue without health data" skips weight, height, target, issues, injuries and rest days,
   and stores none of them. `health_consent_at` records the consent time, and 021's CHECK
   refuses health values without it. Settings → Data & Account → Health data withdraws consent
   (deletes the values locally and on the account) or grants it again. Privacy §4 and §19 only
   name email and account deletion for withdrawing, so add the Settings switch there. §4 also says
   health data "may cover your training data", but workout logging doesn't depend on this
   consent. Have the legal review decide which wording is right.
2. ✅ **Done (2026-09-30).** Minimum age 16: the birth-year wheel ends 16 years back
   (`ObUnits.lastBirthYear`). Until the date is 16+, Continue stays disabled and the step says
   why (`OnboardingData.isOldEnough`, `AppConstants.minUserAge`).
3. ✅ **Done (2026-09-30).** Sign-up and sign-in now show a Terms acknowledgement:
   "By continuing, you confirm you're at least 16 and agree to our Terms of Use. Our Privacy
   Policy explains how we handle your data." Both are links (`LegalAgreementText`, URLs in
   `AppConstants`). The paywall and Settings links point at the same mygymbro.app URLs.
4. ✅ **Fixed in `022_privacy_boundaries.sql` (2026-09-30), live since 2026-10-02** (Supabase section
   above). The anon key could list every profile and friendship without signing in: the views
   bypass RLS, and 018 grants but never revokes. It was worse than a read. `public_profiles` is
   an auto-updatable view, and anon + authenticated also held INSERT/UPDATE/DELETE on it, so
   anyone could rewrite or delete any profile row. Signed-in users could also list anyone's Bros
   through `friends`, although the policy only makes the count public. After 022, anon has no
   access, signed-in users read profiles only (Bro count still exact), and `friends` shows each
   user only their own edges.
5. ✅ **Fixed in 022, live since 2026-10-02.** `sessions_select_friends` is dropped. Bros read the new
   `friend_sessions` view instead: `user_id`, `started_at`, `finished_at`, `duration_seconds` and
   `total_volume_kg`, for accepted Bros' non-deleted sessions only. No app code read friends'
   sessions or notes (the bros strip isn't built yet). If it ever needs to show the workout name,
   the view and privacy §7 have to change together.
6. **`has_active_subscription(uuid)` answers for any user** (found 2026-09-30, open). It is
   SECURITY DEFINER and anon + authenticated can call it with any user id, so the API tells anyone
   whether a given user subscribes. The policy doesn't make that visible, and signed-in users can
   still list every user id through `public_profiles`. RLS policies call it as `authenticated`, so
   a plain REVOKE isn't enough: add a no-argument variant (or move it out of the exposed schema) and
   rewire the policies and RPCs that call it (008/014/015).

**Disclosed as-is in the policy but worth fixing (update the policy when you do):**
- The public display name falls back to the email prefix (Apple users) and can't be edited in
  the app.
- Familjen Grotesk is fetched from Google Fonts at runtime. Bundle it, then delete the Google
  Fonts paragraph in privacy §12.
- Crashlytics is always on: there is no toggle, and fatal errors skip `SafeLogger` scrubbing.
  German regulators may require consent under § 25 TDDDG, so ask on the new consent screen.
  (Still open: the onboarding consent step built on 2026-09-30 covers only Art. 9 health data.
  Consent has to be specific, so a crash-report opt-in needs its own switch, not the same box.)
- Account deletion leaves the RevenueCat customer in place. Call RevenueCat's delete-subscriber
  API from `delete-account`.
- Deleted workouts stay soft-deleted on the server, and their sets still count toward
  leaderboard volume.
- There is no leaderboard opt-out.
- Supabase auth audit-log retention needs checking, so privacy §18's "at most 90 days" holds.
- Cloud leftovers to delete: the `moderate-content` function (it would send data to OpenAI),
  the `report-content` function, and the `community-images` and `dm-media` buckets.
- The iOS camera and microphone purpose strings mention a profile picture the app doesn't have.
  `PrivacyInfo.xcprivacy` probably also needs "Other User Content" (challenge text, share
  titles, report reasons).
- @username claims look broken on the server: `friend_repository.dart:310` keys on `id`, and
  there is no `UPDATE (username)` grant. Invite links can't resolve until this is fixed.
- The "Rate the App" links use a placeholder App Store ID and the wrong Android package
  (`settings_screen.dart:536,539`).

**Operational promises made in the texts:**
- act on abuse reports within 24 hours (Apple 1.2);
- answer privacy requests within one month;
- keep the Impressum phone line reachable.

## Security audit — known-open items (as of 2026-07-14; re-verify before fixing)

- ~~Onboarding **Skip button** has no `kDebugMode` guard~~ — **gated 2026-09-30:** the
  Welcome, paywall and sign-up Skips only render when `kDebugMode || kBetaFreeAccess`, so
  they stay in TestFlight (`BETA_FREE=true`) and are absent from store builds.
- ~~Supabase session tokens in plaintext `SharedPreferences`~~ — done earlier: the
  session is persisted through `SecureSessionStorage` (Keychain /
  EncryptedSharedPreferences, `lib/core/security/secure_storage.dart`).
- ~~`subscriptionLockedProvider` fails open on a null profile~~ — **fixed 2026-09-08:**
  the gate now fails closed on an unknown status, a trial without expiry, and a
  signed-in device with no profile row (`isSignedInProvider`); it stays open only while
  the profile stream is loading and for a missing row on a signed-out device. Tests in
  `test/subscription_gate_test.dart`.
- Drift DB unencrypted — **deliberate**, not a to-do: SQLCipher was removed on purpose
  (`docs/plan/CLAUDE.md` §3, "do not re-add").
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
