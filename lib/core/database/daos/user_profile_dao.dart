import 'package:drift/drift.dart';

import '../app_database.dart';

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

  /// Update FCM token.
  Future<void> updateFcmToken(int localId, String token) =>
      (update(userProfiles)..where((t) => t.localId.equals(localId)))
          .write(UserProfilesCompanion(fcmToken: Value(token)));
}
