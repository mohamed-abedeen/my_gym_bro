import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'user_profile_dao.g.dart';

/// Data access object for the [UserProfiles] table.
@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  /// The body metrics + onboarding answers of a server `user_profiles` row
  /// (migration 021) as local columns — used when an account signs in on a
  /// new device so its intake comes along. Arrays stay JSON text locally.
  static UserProfilesCompanion answersFromRemote(Map<String, dynamic> row) {
    double? decimal(String k) => (row[k] as num?)?.toDouble();
    String? list(String k) {
      final v = row[k];
      return v is List ? jsonEncode(v) : null;
    }

    final birth = row['birth_date'];
    final consent = row['health_consent_at'];
    return UserProfilesCompanion(
      gender: Value(row['gender'] as String?),
      bodyWeightKg: Value(decimal('body_weight_kg')),
      heightCm: Value(decimal('height_cm')),
      weightUnit: Value((row['weight_unit'] as String?) ?? 'kg'),
      heightUnit: Value((row['height_unit'] as String?) ?? 'cm'),
      birthDate: Value(birth is String ? DateTime.tryParse(birth) : null),
      targetWeightKg: Value(decimal('target_weight_kg')),
      focusAreas: Value(list('focus_areas')),
      healthIssue: Value(row['health_issue'] as String?),
      injuries: Value(list('injuries')),
      injuryRestDays: Value((row['injury_rest_days'] as num?)?.toInt()),
      trainingDays: Value(list('training_days')),
      healthConsentAt: Value(
        consent is String ? DateTime.tryParse(consent)?.toLocal() : null,
      ),
    );
  }

  /// Get the first (and typically only) user profile.
  Future<UserProfile?> getFirst() =>
      (select(userProfiles)..limit(1)).getSingleOrNull();

  /// Stream the current user profile.
  Stream<UserProfile?> watchProfile() =>
      (select(userProfiles)..limit(1)).watchSingleOrNull();

  /// Whether this device's local data belongs to an account other than
  /// [userId]: the profile is linked to a different auth user. A profile with
  /// no remote id yet (made before any sign-in) belongs to whoever signs in.
  Future<bool> heldByOtherAccount(String userId) async {
    final owner = (await getFirst())?.remoteId;
    return owner != null && owner != userId;
  }

  /// Insert or update the user profile.
  Future<int> upsert(UserProfilesCompanion companion) =>
      into(userProfiles).insertOnConflictUpdate(companion);

  /// Merge [data] onto the existing profile row, if any. Used by the OAuth
  /// sign-up flow to layer the onboarding answers onto the profile that the
  /// auth listener bootstrapped from the server.
  Future<void> mergeIntoFirst(UserProfilesCompanion data) async {
    final current = await getFirst();
    if (current == null) return;
    await (update(userProfiles)
          ..where((t) => t.localId.equals(current.localId)))
        .write(data);
  }

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

  /// Record the claimed @username (already validated + claimed server-side).
  Future<void> updateUsername(int localId, String username) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(username: Value(username)));

  /// Update the selected cosmetic skin id (null = default body).
  Future<void> updateActiveSkin(int localId, String? skinId) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(activeSkinId: Value(skinId)));

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
