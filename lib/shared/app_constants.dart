/// App-wide business logic constants.
///
/// Keep magic numbers, URIs, and durations here so they're easy to find
/// and change without hunting through individual feature files.
class AppConstants {
  AppConstants._();

  // ── Auth / OAuth ────────────────────────────────────────────────────────
  // Must exactly match an entry in the Supabase redirect allow-list
  // (supabase/config.toml `additional_redirect_urls` + the hosted dashboard's
  // Auth → URL Configuration). A URI outside the list silently falls back to
  // the project's site_url, which may not deep-link back into the app.
  static const oauthRedirectUri = 'io.supabase.mygymbro://login-callback/';

  // ── Subscription ────────────────────────────────────────────────────────
  static const trialDurationDays = 7;
  static const defaultNotificationTone = 'balanced';

  // ── Legal ───────────────────────────────────────────────────────────────
  /// Terms of Use §2 (and Germany's GDPR age of digital consent).
  static const minUserAge = 16;

  /// Published pages from `website/public/`.
  static const termsUrl = 'https://mygymbro.app/terms';
  static const privacyUrl = 'https://mygymbro.app/privacy';

  /// Privacy Policy §4 — health data and consent.
  static const healthDataUrl = 'https://mygymbro.app/privacy#health';

  // ── Session ─────────────────────────────────────────────────────────────
  static const defaultRestSeconds = 90;

  // ── DB migration ────────────────────────────────────────────────────────
  static const dbMigrationVersion = '3'; // v3: shoulder delt sub-group split
}
