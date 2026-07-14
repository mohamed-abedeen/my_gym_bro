import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/subscription_sync_service.dart';

/// A CustomerInfo payload as the purchases_flutter platform side would send
/// it; [entitlements] maps entitlement ids to their EntitlementInfo json.
Map<String, Object?> _customerInfoJson({
  Map<String, Object?> entitlements = const {},
}) =>
    {
      'entitlements': {'all': entitlements, 'active': entitlements},
      'allPurchaseDates': <String, Object?>{},
      'activeSubscriptions': <Object?>[],
      'allPurchasedProductIdentifiers': <Object?>[],
      'nonSubscriptionTransactions': <Object?>[],
      'firstSeen': '2026-07-01T00:00:00Z',
      'originalAppUserId': 'test-user',
      'allExpirationDates': <String, Object?>{},
      'requestDate': '2026-07-14T00:00:00Z',
    };

Map<String, Object?> _premiumEntitlement({required String expirationDate}) => {
      'identifier': 'premium',
      'isActive': true,
      'willRenew': true,
      'latestPurchaseDate': '2026-07-01T00:00:00Z',
      'originalPurchaseDate': '2026-07-01T00:00:00Z',
      'productIdentifier': 'mgb_yearly',
      'isSandbox': false,
      'expirationDate': expirationDate,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');

  late AppDatabase db;
  late UserProfileDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = UserProfileDao(db);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
  });

  void mockCustomerInfo(Map<String, Object?> payload) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCustomerInfo') return payload;
      return null;
    });
  }

  Future<void> seedProfile({
    required String status,
    DateTime? expiresAt,
  }) =>
      db.into(db.userProfiles).insert(
            UserProfilesCompanion.insert(
              subscriptionStatus: Value(status),
              subscriptionExpiresAt: Value(expiresAt),
            ),
          );

  group('SubscriptionSyncService.syncNow', () {
    test('active premium entitlement marks the local profile active with '
        'the entitlement expiry', () async {
      await seedProfile(status: 'trial');
      mockCustomerInfo(_customerInfoJson(entitlements: {
        'premium': _premiumEntitlement(
          expirationDate: '2026-08-01T00:00:00.000Z',
        ),
      }));

      await SubscriptionSyncService.syncNow(dao);

      final profile = (await dao.getFirst())!;
      expect(profile.subscriptionStatus, 'active');
      expect(profile.subscriptionExpiresAt?.toUtc(), DateTime.utc(2026, 8));
    });

    test('an entitlement under a different id does not unlock', () async {
      final trialEnd = DateTime.now().subtract(const Duration(days: 1));
      await seedProfile(status: 'trial', expiresAt: trialEnd);
      mockCustomerInfo(_customerInfoJson(entitlements: {
        'not_premium': _premiumEntitlement(
          expirationDate: '2026-08-01T00:00:00.000Z',
        ),
      }));

      await SubscriptionSyncService.syncNow(dao);

      expect((await dao.getFirst())!.subscriptionStatus, 'expired');
    });

    test('no entitlement + elapsed trial marks the profile expired',
        () async {
      final trialEnd = DateTime.now().subtract(const Duration(days: 1));
      await seedProfile(status: 'trial', expiresAt: trialEnd);
      mockCustomerInfo(_customerInfoJson());

      await SubscriptionSyncService.syncNow(dao);

      expect((await dao.getFirst())!.subscriptionStatus, 'expired');
    });

    test('no entitlement but trial still running is preserved', () async {
      // Second precision — drift round-trips DateTimes as unix seconds.
      final trialEnd = DateTime.fromMillisecondsSinceEpoch(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3 * 86400) * 1000,
      );
      await seedProfile(status: 'trial', expiresAt: trialEnd);
      mockCustomerInfo(_customerInfoJson());

      await SubscriptionSyncService.syncNow(dao);

      final profile = (await dao.getFirst())!;
      expect(profile.subscriptionStatus, 'trial');
      expect(profile.subscriptionExpiresAt, trialEnd);
    });

    test('platform failure is swallowed and leaves local state untouched',
        () async {
      await seedProfile(status: 'trial');
      // No mock handler installed → MissingPluginException inside syncNow.
      await SubscriptionSyncService.syncNow(dao);

      expect((await dao.getFirst())!.subscriptionStatus, 'trial');
    });
  });
}
