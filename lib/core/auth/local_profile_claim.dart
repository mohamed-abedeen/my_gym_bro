import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/core/services/health_consent.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/shared/app_constants.dart';

/// Hands the profile a signed-out device built to the account that signs in.
///
/// The dev/beta Skip (and any pre-sign-in Settings write) leaves a local
/// `user_profiles` row with a null `remoteId`. Everything downstream treats a
/// null `remoteId` as "no account": `WorkoutPushService` skips both the
/// backfill and per-workout pushes, and the outbox has nothing to key on.
/// [claim] links that row to [userId] so the local history uploads, instead of
/// the sign-in creating an empty second identity (or, before this existed,
/// leaving the row unlinked forever).
///
/// Merge rules (the server row is [remote], null when offline / not created
/// yet):
///  * Trial + subscription: the server is authoritative — its trial window
///    and status replace the local defaults. Absent on the server → keep the
///    local value, then the standard 7-day trial.
///  * Onboarding answers and body metrics: the device wins where it has a
///    value (it is what the user sees), the server only fills the gaps. Units
///    are the exception — local columns always hold a default, so the
///    server's choice wins when it has one.
///  * Health data follows consent: server health values are only adopted when
///    the server holds a consent timestamp, and local health values are only
///    uploaded when the merged profile has one (the server CHECK
///    `user_profiles_health_needs_consent` would reject the row otherwise).
///
/// The merged answers are queued as ONE `user_profiles` update, so they reach
/// Supabase whenever the device is online. Idempotent and race-safe: the link
/// is an atomic `UPDATE … WHERE remote_id IS NULL`, so overlapping sign-in
/// events can't double-claim or double-enqueue.
class LocalProfileClaim {
  LocalProfileClaim._();

  /// Claims the device's profile for [userId]. Returns whether this call did
  /// the claim (false: no profile, already linked, or another call won).
  static Future<bool> claim({
    required AppDatabase db,
    required SyncService sync,
    required String userId,
    Map<String, dynamic>? remote,
    String? fallbackDisplayName,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    var claimed = false;
    await db.transaction(() async {
      final dao = UserProfileDao(db);
      final local = await dao.getFirst();
      if (local == null || local.remoteId != null) return;

      final merged = merge(
        local: local,
        userId: userId,
        remote: remote,
        fallbackDisplayName: fallbackDisplayName,
        now: at,
      );
      final linked = await (db.update(db.userProfiles)
            ..where((t) => t.localId.equals(local.localId) & t.remoteId.isNull()))
          .write(merged);
      if (linked != 1) return;
      claimed = true;

      final after = await dao.getFirst();
      final payload = after == null ? null : answersPayload(after);
      if (after != null && payload != null && payload.isNotEmpty) {
        // kickSync:false — inside the transaction zone the drain would race
        // the commit; the caller (auth listener) drains right after.
        await sync.enqueue(
          table: 'user_profiles',
          rowId: after.localId,
          operation: 'update',
          payload: {'remote_id': userId, ...payload},
          kickSync: false,
        );
      }
    });
    if (claimed) unawaited(sync.syncAll());
    return claimed;
  }

  /// The local columns to write when claiming [local] for [userId].
  static UserProfilesCompanion merge({
    required UserProfile local,
    required String userId,
    required DateTime now,
    Map<String, dynamic>? remote,
    String? fallbackDisplayName,
  }) {
    final r = remote;
    String? text(String k) => r?[k] as String?;
    double? decimal(String k) => (r?[k] as num?)?.toDouble();
    String? list(String k) {
      final v = r?[k];
      return v is List ? jsonEncode(v) : null;
    }

    DateTime? time(String k) {
      final v = r?[k];
      return v is String ? DateTime.tryParse(v)?.toLocal() : null;
    }

    // Health values travel with consent: take the server's only when it has
    // one on file.
    final remoteConsent = time('health_consent_at');
    final consent = local.healthConsentAt ?? remoteConsent;
    final takeRemoteHealth = remoteConsent != null;

    final name = local.displayName ?? text('display_name') ?? fallbackDisplayName;
    final birth = r?['birth_date'];

    return UserProfilesCompanion(
      remoteId: Value(userId),
      displayName: Value(
        name == null ? null : InputSanitiser.sanitise(name, maxLength: 100),
      ),
      username: Value(local.username ?? text('username')),
      activeSkinId: Value(local.activeSkinId ?? text('active_skin_id')),
      goal: Value(local.goal ?? text('goal')),
      experience: Value(local.experience ?? text('experience')),
      gender: Value(local.gender ?? text('gender')),
      weightUnit: Value(text('weight_unit') ?? local.weightUnit),
      heightUnit: Value(text('height_unit') ?? local.heightUnit),
      birthDate: Value(
        local.birthDate ?? (birth is String ? DateTime.tryParse(birth) : null),
      ),
      focusAreas: Value(local.focusAreas ?? list('focus_areas')),
      trainingDays: Value(local.trainingDays ?? list('training_days')),
      bodyWeightKg: Value(
        local.bodyWeightKg ?? (takeRemoteHealth ? decimal('body_weight_kg') : null),
      ),
      heightCm: Value(
        local.heightCm ?? (takeRemoteHealth ? decimal('height_cm') : null),
      ),
      targetWeightKg: Value(
        local.targetWeightKg ??
            (takeRemoteHealth ? decimal('target_weight_kg') : null),
      ),
      healthIssue: Value(
        local.healthIssue ?? (takeRemoteHealth ? text('health_issue') : null),
      ),
      injuries: Value(
        local.injuries ?? (takeRemoteHealth ? list('injuries') : null),
      ),
      injuryRestDays: Value(
        local.injuryRestDays ??
            (takeRemoteHealth ? (r?['injury_rest_days'] as num?)?.toInt() : null),
      ),
      healthConsentAt: Value(consent),
      trialStartedAt:
          Value(time('trial_started_at') ?? local.trialStartedAt ?? now),
      subscriptionStatus:
          Value(text('subscription_status') ?? local.subscriptionStatus),
      subscriptionExpiresAt: Value(
        time('subscription_expires_at') ??
            local.subscriptionExpiresAt ??
            now.add(const Duration(days: AppConstants.trialDurationDays)),
      ),
      createdAt: Value(local.createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  /// The `user_profiles` patch for [p]'s answers, in server shapes (the same
  /// shape `OnboardingPersistence.payload` sends). Unanswered columns are
  /// left out; health values and `health_consent_at` go only while consent
  /// is on file.
  static Map<String, dynamic> answersPayload(UserProfile p) {
    List<dynamic>? decoded(String? json) {
      if (json == null) return null;
      try {
        final v = jsonDecode(json);
        return v is List ? v : null;
      } on FormatException {
        return null;
      }
    }

    final focus = decoded(p.focusAreas);
    final days = decoded(p.trainingDays);
    final injuries = decoded(p.injuries);
    final consent = p.healthConsentAt;
    return {
      if (p.gender != null) 'gender': p.gender,
      if (p.goal != null) 'goal': p.goal,
      if (p.experience != null) 'experience': p.experience,
      'weight_unit': p.weightUnit,
      'height_unit': p.heightUnit,
      if (p.birthDate != null)
        'birth_date': DateFormat('yyyy-MM-dd').format(p.birthDate!),
      if (focus != null) 'focus_areas': focus,
      if (days != null) 'training_days': days,
      if (consent != null) ...{
        if (p.bodyWeightKg != null) 'body_weight_kg': p.bodyWeightKg,
        if (p.heightCm != null) 'height_cm': p.heightCm,
        if (p.targetWeightKg != null) 'target_weight_kg': p.targetWeightKg,
        if (p.healthIssue != null) 'health_issue': p.healthIssue,
        if (injuries != null) 'injuries': injuries,
        if (p.injuryRestDays != null) 'injury_rest_days': p.injuryRestDays,
        'health_consent_at': healthConsentWire(consent),
      },
    };
  }
}
