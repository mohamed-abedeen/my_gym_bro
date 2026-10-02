import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/health_consent.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';

/// Writes the onboarding answers onto the signed-in user's profile: the
/// local Drift row first, then one queued `user_profiles` update so they
/// reach Supabase when online (offline-first; migration 021).
///
/// Health answers follow the consent step: granted → stored with the
/// consent time; declined → cleared (a re-run can't leave old ones behind);
/// never asked (dev skip) → left untouched.
class OnboardingPersistence {
  OnboardingPersistence._();

  static double _one(double v) => (v * 10).round() / 10;

  static List<String> _focus(OnboardingData d) =>
      [for (final a in FocusArea.values) if (d.focus.contains(a)) a.wire];

  static List<String> _injuries(OnboardingData d) =>
      [for (final a in InjuryArea.values) if (d.injuries.contains(a)) a.wire];

  static List<int> _days(OnboardingData d) => d.trainingDays.toList()..sort();

  static bool _injuriesAnswered(OnboardingData d) =>
      d.noInjuries || d.hasRealInjuries;

  /// The local profile columns. Unanswered choices stay absent so a partial
  /// flow (dev skip) never blanks existing values.
  static UserProfilesCompanion companion(OnboardingData d, {DateTime? now}) {
    final base = UserProfilesCompanion(
      gender: Value.absentIfNull(d.gender),
      goal: Value.absentIfNull(d.goal?.wire),
      experience: Value.absentIfNull(d.experience?.wire),
      weightUnit: Value(d.weightMetric ? 'kg' : 'lbs'),
      heightUnit: Value(d.heightMetric ? 'cm' : 'ft'),
      birthDate: Value(d.birthDate),
      focusAreas: Value(jsonEncode(_focus(d))),
      trainingDays: Value(jsonEncode(_days(d))),
    );
    return switch (d.healthConsent) {
      HealthConsent.granted => base.copyWith(
          bodyWeightKg: Value(_one(d.weightKg)),
          heightCm: Value(_one(d.heightCm)),
          targetWeightKg: Value(_one(d.effectiveTargetKg)),
          healthIssue: Value.absentIfNull(d.issue?.wire),
          injuries: _injuriesAnswered(d)
              ? Value(jsonEncode(_injuries(d)))
              : const Value.absent(),
          injuryRestDays: Value(d.hasRealInjuries ? d.restDays : null),
          healthConsentAt: Value(now ?? DateTime.now()),
        ),
      HealthConsent.declined => base.copyWith(
          bodyWeightKg: clearedHealthData.bodyWeightKg,
          heightCm: clearedHealthData.heightCm,
          targetWeightKg: clearedHealthData.targetWeightKg,
          healthIssue: clearedHealthData.healthIssue,
          injuries: clearedHealthData.injuries,
          injuryRestDays: clearedHealthData.injuryRestDays,
          healthConsentAt: clearedHealthData.healthConsentAt,
        ),
      HealthConsent.unanswered => base,
    };
  }

  /// The Supabase `user_profiles` patch — same fields, server shapes
  /// (`date`, `text[]`, `smallint[]`, `timestamptz`).
  static Map<String, dynamic> payload(OnboardingData d, {DateTime? now}) => {
        if (d.gender != null) 'gender': d.gender,
        if (d.goal != null) 'goal': d.goal!.wire,
        if (d.experience != null) 'experience': d.experience!.wire,
        'weight_unit': d.weightMetric ? 'kg' : 'lbs',
        'height_unit': d.heightMetric ? 'cm' : 'ft',
        'birth_date': DateFormat('yyyy-MM-dd').format(d.birthDate),
        'focus_areas': _focus(d),
        'training_days': _days(d),
        ...switch (d.healthConsent) {
          HealthConsent.granted => {
              'body_weight_kg': _one(d.weightKg),
              'height_cm': _one(d.heightCm),
              'target_weight_kg': _one(d.effectiveTargetKg),
              if (d.issue != null) 'health_issue': d.issue!.wire,
              if (_injuriesAnswered(d)) 'injuries': _injuries(d),
              'injury_rest_days': d.hasRealInjuries ? d.restDays : null,
              'health_consent_at': healthConsentWire(now ?? DateTime.now()),
            },
          HealthConsent.declined => clearedHealthPayload(),
          HealthConsent.unanswered => const <String, dynamic>{},
        },
      };

  /// Saves [data] onto the profile row the auth listener bootstrapped.
  /// Signed-out (no remote id) → local only.
  static Future<void> save({
    required AppDatabase db,
    required SyncService sync,
    required OnboardingData data,
  }) async {
    final now = DateTime.now();
    final dao = UserProfileDao(db);
    await dao.mergeIntoFirst(companion(data, now: now));
    final profile = await dao.getFirst();
    final remoteId = profile?.remoteId;
    if (profile == null || remoteId == null) return;
    await sync.enqueue(
      table: 'user_profiles',
      rowId: profile.localId,
      operation: 'update',
      payload: {'remote_id': remoteId, ...payload(data, now: now)},
    );
  }
}
