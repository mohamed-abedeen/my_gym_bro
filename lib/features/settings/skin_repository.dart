import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/skin_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How a purchase/restore attempt ended, store-side.
enum SkinFlowStatus {
  /// The store operation succeeded (bought or receipt replayed).
  success,

  /// The user dismissed the store sheet — not an error.
  cancelled,

  /// RevenueCat isn't configured or the product isn't for sale.
  unavailable,

  /// The store operation failed.
  error,
}

/// Result of a purchase/restore: the store outcome, whether the server
/// verified ownership, and the one-time product ids the receipt proves the
/// user owns (for the instant local unlock when verification is offline).
class SkinFlowOutcome {
  const SkinFlowOutcome(
    this.status, {
    this.serverVerified = false,
    this.ownedProductIds = const {},
  });

  final SkinFlowStatus status;

  /// True when `purchase-skin` confirmed and mirrored ownership. False after
  /// a successful store purchase that couldn't be verified yet (offline /
  /// backend not deployed) — the receipt-derived local unlock still applies
  /// and a later restore or refresh heals the server record.
  final bool serverVerified;

  final Set<String> ownedProductIds;
}

/// Client half of the skins economy (PRD §5.10): the skin-ownership offline
/// mirror, RevenueCat one-time purchases with server-side receipt
/// verification, and persisting the selected skin onto the synced profile.
///
/// Fully null-safe against a missing Supabase client and an unconfigured
/// RevenueCat (SETUP-STATUS): every path degrades to the local cache.
class SkinRepository {
  SkinRepository({
    required AppDatabase db,
    required SyncService sync,
    required SupabaseClient? supabase,
  })  : _skinDao = SkinDao(db),
        _profileDao = UserProfileDao(db),
        _sync = sync,
        _supabase = supabase;

  final SkinDao _skinDao;
  final UserProfileDao _profileDao;
  final SyncService _sync;
  final SupabaseClient? _supabase;

  Stream<Set<String>> watchOwnedIds() => _skinDao.watchOwnedIds();

  /// Persist the selected skin to the profile row + sync outbox. SecureStorage
  /// (the instant local render source) is written by the caller — this is the
  /// cross-device half. No-ops before onboarding creates a profile.
  Future<void> persistActiveSkin(String skinId) async {
    final profile = await _profileDao.getFirst();
    if (profile == null) return;
    await _profileDao.updateActiveSkin(profile.localId, skinId);

    final remoteId = profile.remoteId;
    if (remoteId == null) return;
    await _sync.enqueue(
      table: 'user_profiles',
      rowId: profile.localId,
      operation: 'update',
      payload: {
        'remote_id': remoteId,
        'active_skin_id': skinId,
      },
    );
  }

  /// Pull the ownership mirror. Never throws — offline keeps the cache.
  Future<void> refreshFromServer() async {
    final sb = _supabase;
    if (sb == null || sb.auth.currentUser == null) return;
    try {
      final rows = await sb
          .from('skin_ownership')
          .select('skin_id, source, acquired_at');
      await _skinDao.replaceAll([
        for (final r in rows) _ownershipCompanion(r),
      ]);
    } on Object {
      // Offline / backend not deployed — keep the cached mirror.
    }
  }

  /// Buy the one-time [productId], then verify + mirror ownership.
  Future<SkinFlowOutcome> purchase(String productId) async {
    CustomerInfo info;
    try {
      // Unconfigured Purchases fatalErrors on iOS — always gate on
      // isConfigured (SETUP-STATUS gotcha).
      if (!await Purchases.isConfigured) {
        return const SkinFlowOutcome(SkinFlowStatus.unavailable);
      }
      final products = await Purchases.getProducts(
        [productId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (products.isEmpty) {
        return const SkinFlowOutcome(SkinFlowStatus.unavailable);
      }
      info = await Purchases.purchaseStoreProduct(products.first);
    } on PlatformException catch (e) {
      // purchases_flutter surfaces errors as PlatformException; the user
      // closing the sheet is not an error.
      return SkinFlowOutcome(
        PurchasesErrorHelper.getErrorCode(e) ==
                PurchasesErrorCode.purchaseCancelledError
            ? SkinFlowStatus.cancelled
            : SkinFlowStatus.error,
      );
    } on Exception {
      return const SkinFlowOutcome(SkinFlowStatus.error);
    }
    final verified = await _verifyWithServer();
    return SkinFlowOutcome(
      SkinFlowStatus.success,
      serverVerified: verified,
      ownedProductIds: _ownedProducts(info),
    );
  }

  /// Replay the store receipt (restore / reinstall), then re-verify.
  Future<SkinFlowOutcome> restore() async {
    CustomerInfo info;
    try {
      if (!await Purchases.isConfigured) {
        return const SkinFlowOutcome(SkinFlowStatus.unavailable);
      }
      info = await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      return SkinFlowOutcome(
        PurchasesErrorHelper.getErrorCode(e) ==
                PurchasesErrorCode.purchaseCancelledError
            ? SkinFlowStatus.cancelled
            : SkinFlowStatus.error,
      );
    } on Exception {
      return const SkinFlowOutcome(SkinFlowStatus.error);
    }
    final verified = await _verifyWithServer();
    return SkinFlowOutcome(
      SkinFlowStatus.success,
      serverVerified: verified,
      ownedProductIds: _ownedProducts(info),
    );
  }

  static Set<String> _ownedProducts(CustomerInfo info) => {
        for (final tx in info.nonSubscriptionTransactions)
          tx.productIdentifier,
      };

  /// POST purchase-skin: server verifies the receipt against RevenueCat and
  /// returns the full ownership snapshot, which replaces the mirror. Returns
  /// false (and keeps the cache) when offline or the backend isn't deployed.
  Future<bool> _verifyWithServer() async {
    final sb = _supabase;
    if (sb == null || sb.auth.currentUser == null) return false;
    try {
      final response = await sb.functions.invoke('purchase-skin');
      if (response.status >= 400) return false;
      final data = response.data;
      final owned = data is Map ? data['owned'] : null;
      if (owned is! List) return false;
      await _skinDao.replaceAll([
        for (final r in owned)
          if (r is Map) _ownershipCompanion(Map<String, dynamic>.from(r)),
      ]);
      return true;
    } on Object {
      return false;
    }
  }

  SkinOwnershipsCompanion _ownershipCompanion(Map<String, dynamic> row) {
    return SkinOwnershipsCompanion(
      skinId: Value(row['skin_id'] as String),
      source: Value(row['source'] as String? ?? 'earned'),
      acquiredAt: Value(_parseTimestamp(row['acquired_at'])),
      fetchedAt: Value(DateTime.now()),
    );
  }

  static DateTime? _parseTimestamp(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
