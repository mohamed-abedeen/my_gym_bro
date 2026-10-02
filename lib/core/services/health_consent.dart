import 'package:drift/drift.dart' show Value;

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';

/// Health data on the profile and the consent that gates it (GDPR Art. 9).
///
/// Weight, height, target weight, health issue, injuries and rest days are
/// only stored while `healthConsentAt` is set. Onboarding asks before the
/// body-data questions; Settings can withdraw it (which deletes them) or
/// grant it again. Migration 021's `user_profiles_health_needs_consent`
/// CHECK enforces the same rule server-side.

/// Server columns that hold health data.
const healthDataColumns = [
  'body_weight_kg',
  'height_cm',
  'target_weight_kg',
  'health_issue',
  'injuries',
  'injury_rest_days',
];

/// Local columns cleared: every health value and the consent itself.
const clearedHealthData = UserProfilesCompanion(
  bodyWeightKg: Value(null),
  heightCm: Value(null),
  targetWeightKg: Value(null),
  healthIssue: Value(null),
  injuries: Value(null),
  injuryRestDays: Value(null),
  healthConsentAt: Value(null),
);

/// The matching server patch.
Map<String, dynamic> clearedHealthPayload() => {
      for (final c in healthDataColumns) c: null,
      'health_consent_at': null,
    };

/// Wire form of a consent moment.
String healthConsentWire(DateTime at) => at.toUtc().toIso8601String();

/// Withdraws consent: deletes the health data on the device and queues the
/// same deletion for the account (offline-first).
Future<void> withdrawHealthConsent({
  required AppDatabase db,
  required SyncService sync,
}) =>
    _write(db, sync, clearedHealthData, clearedHealthPayload());

/// Records consent given in Settings ([at] defaults to now).
Future<void> grantHealthConsent({
  required AppDatabase db,
  required SyncService sync,
  DateTime? at,
}) {
  final when = at ?? DateTime.now();
  return _write(
    db,
    sync,
    UserProfilesCompanion(healthConsentAt: Value(when)),
    {'health_consent_at': healthConsentWire(when)},
  );
}

Future<void> _write(
  AppDatabase db,
  SyncService sync,
  UserProfilesCompanion local,
  Map<String, dynamic> remote,
) async {
  final dao = UserProfileDao(db);
  await dao.mergeIntoFirst(local);
  final profile = await dao.getFirst();
  final remoteId = profile?.remoteId;
  if (profile == null || remoteId == null) return;
  await sync.enqueue(
    table: 'user_profiles',
    rowId: profile.localId,
    operation: 'update',
    payload: {'remote_id': remoteId, ...remote},
  );
}
