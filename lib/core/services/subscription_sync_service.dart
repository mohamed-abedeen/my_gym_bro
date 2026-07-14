import 'package:flutter/foundation.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reconciles RevenueCat entitlements into the local [UserProfiles] row.
///
/// Two entry points:
///   - [syncNow] — pulls the current CustomerInfo once. Call after a
///     successful purchase, after restorePurchases, and on app start.
///   - [listen] — installs a customer-info listener so renewals,
///     cancellations, and refunds flow through without explicit calls.
class SubscriptionSyncService {
  SubscriptionSyncService._();

  /// Entitlement identifier configured in the RevenueCat dashboard.
  static const String entitlementId = 'premium';

  /// Pull the latest CustomerInfo from RevenueCat and write it through to
  /// the local profile. Best-effort — a network or auth failure is logged
  /// in debug mode and swallowed so the app keeps running.
  static Future<void> syncNow(UserProfileDao dao) async {
    try {
      final info = await Purchases.getCustomerInfo();
      await _apply(dao, info);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[SubSync] syncNow failed: $e');
    }
  }

  /// Install a one-time listener that mirrors CustomerInfo updates into
  /// the profile. Safe to call repeatedly — the SDK deduplicates listeners.
  static void listen(UserProfileDao dao) {
    Purchases.addCustomerInfoUpdateListener((info) {
      _apply(dao, info);
    });
  }

  static DateTime? _lastServerVerify;

  /// Ask the `verify-subscription` edge function for the authoritative
  /// entitlement and mirror the verdict into the local profile, so a
  /// rolled-back device clock can't stretch the trial. Called on app launch
  /// and on resume; debounced to at most one call per minute.
  ///
  /// Offline-first: any failure (signed out, Supabase not initialised,
  /// offline, function not deployed) leaves local state untouched.
  static Future<void> verifyServer(UserProfileDao dao) async {
    final now = DateTime.now();
    if (_lastServerVerify != null &&
        now.difference(_lastServerVerify!) < const Duration(minutes: 1)) {
      return;
    }
    _lastServerVerify = now;
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return; // signed out
      final res = await client.functions
          .invoke('verify-subscription')
          .timeout(const Duration(seconds: 10));
      final verdict = parseVerdict(res.data);
      if (verdict == null) return;
      final (status, expiresAt) = verdict;
      final profile = await dao.getFirst();
      if (profile == null) return;
      if (profile.subscriptionStatus == status &&
          profile.subscriptionExpiresAt == expiresAt) {
        return; // no-op
      }
      await dao.updateSubscription(
        profile.localId,
        status: status,
        expiresAt: expiresAt,
      );
    } on Object catch (e) {
      // Silence is the contract: server verify is a best-effort tightener,
      // never a blocker for the offline-first app.
      if (kDebugMode) debugPrint('[SubSync] verifyServer failed: $e');
    }
  }

  /// Maps a verify-subscription response body
  /// (`{status, product_id, expires_at, is_trial}`) to a `(status, expiresAt)`
  /// verdict, or null when the shape/status is unexpected (keep local state).
  @visibleForTesting
  static (String, DateTime?)? parseVerdict(dynamic data) {
    if (data is! Map) return null;
    final status = data['status'];
    if (status is! String ||
        !const {'active', 'trial', 'expired', 'grace_period'}
            .contains(status)) {
      return null;
    }
    final raw = data['expires_at'];
    return (status, raw is String ? DateTime.tryParse(raw) : null);
  }

  static Future<void> _apply(
      UserProfileDao dao, CustomerInfo info) async {
    final profile = await dao.getFirst();
    if (profile == null) return; // signed-out or pre-onboarding

    final ent = info.entitlements.active[entitlementId];
    String status;
    DateTime? expiresAt;

    if (ent != null) {
      // Active paying user. RevenueCat reports an ISO-8601 string in
      // ent.expirationDate or null for lifetime entitlements.
      status = 'active';
      final raw = ent.expirationDate;
      expiresAt = raw == null ? null : DateTime.tryParse(raw);
    } else {
      // No active premium entitlement. Preserve trial state until the
      // existing trialExpiresAt window has passed — otherwise mark as
      // expired so the paywall gate's stored status matches reality.
      final trialEnd = profile.subscriptionExpiresAt;
      final stillInTrial = profile.subscriptionStatus == 'trial' &&
          trialEnd != null &&
          trialEnd.isAfter(DateTime.now());
      status = stillInTrial ? 'trial' : 'expired';
      expiresAt = trialEnd;
    }

    if (profile.subscriptionStatus == status &&
        profile.subscriptionExpiresAt == expiresAt) {
      return; // no-op
    }

    await dao.updateSubscription(
      profile.localId,
      status: status,
      expiresAt: expiresAt,
    );
  }
}
