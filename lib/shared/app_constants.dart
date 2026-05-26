/// App-wide business logic constants.
///
/// Keep magic numbers, URIs, and durations here so they're easy to find
/// and change without hunting through individual feature files.
class AppConstants {
  AppConstants._();

  // ── Auth / OAuth ────────────────────────────────────────────────────────
  static const oauthRedirectUri = 'io.supabase.mygymbro://callback';

  // ── Subscription ────────────────────────────────────────────────────────
  static const trialDurationDays = 7;
  static const defaultNotificationTone = 'balanced';

  // ── Session ─────────────────────────────────────────────────────────────
  static const defaultRestSeconds = 90;

  // ── DB migration ────────────────────────────────────────────────────────
  static const dbMigrationVersion = '3'; // v3: shoulder delt sub-group split
}
