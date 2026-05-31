import 'package:flutter/foundation.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
