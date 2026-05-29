import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'user_profile_dao.g.dart';

/// Data access object for the [UserProfiles] table.
@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  /// Get the first (and typically only) user profile.
  Future<UserProfile?> getFirst() =>
      (select(userProfiles)..limit(1)).getSingleOrNull();

  /// Stream the current user profile.
  Stream<UserProfile?> watchProfile() =>
      (select(userProfiles)..limit(1)).watchSingleOrNull();

  /// Insert or update the user profile.
  Future<int> upsert(UserProfilesCompanion companion) =>
      into(userProfiles).insertOnConflictUpdate(companion);

  /// Update preferred language.
  Future<void> updateLanguage(int localId, String language) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(preferredLanguage: Value(language)));

  /// Update default rest seconds.
  Future<void> updateRestSeconds(int localId, int seconds) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(defaultRestSeconds: Value(seconds)));

  /// Update weight unit ('kg' or 'lbs').
  Future<void> updateWeightUnit(int localId, String unit) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(weightUnit: Value(unit)));

  /// Update self-reported body weight in kilograms.
  Future<void> updateBodyWeight(int localId, double? kg) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(bodyWeightKg: Value(kg)));

  /// Update FCM token.
  Future<void> updateFcmToken(int localId, String token) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(fcmToken: Value(token)));

  /// Update notification tone ('supportive' | 'balanced' | 'bold' | 'savage').
  Future<void> updateNotificationTone(int localId, String tone) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(notificationTone: Value(tone)));

  /// Update profile banner URL (local file path or null to reset to default).
  Future<void> updateBannerUrl(int localId, String? url) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(bannerUrl: Value(url)));

  /// Delete every profile row on this device. Used by the account-deletion
  /// flow so the next sign-up on the same device starts with a clean slate.
  Future<int> clearAll() => delete(userProfiles).go();

  /// Update subscription status + expiry from a RevenueCat customer info
  /// reconciliation. `expiresAt` may be null for lifetime entitlements or
  /// when there's no active entitlement (status='expired').
  Future<void> updateSubscription(
    int localId, {
    required String status,
    DateTime? expiresAt,
  }) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId))).write(
        UserProfilesCompanion(
          subscriptionStatus: Value(status),
          subscriptionExpiresAt: Value(expiresAt),
        ),
      );
}
