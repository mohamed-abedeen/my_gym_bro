import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_persistence.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';

const _answers = OnboardingData(
  gender: 'female',
  goal: OnboardingGoal.loseWeight,
  focus: {FocusArea.glutes, FocusArea.back},
  healthConsent: HealthConsent.granted,
  birthDay: 31,
  birthMonth: 2,
  birthYear: 1995,
  heightCm: 167.64,
  heightMetric: false,
  weightKg: 71.987,
  targetWeightKg: 64.02,
  weightMetric: false,
  issue: HealthIssue.sleep,
  injuries: {InjuryArea.knee, InjuryArea.shoulder},
  restDays: 5,
  experience: ExperienceLevel.active,
  trainingDays: {5, 1, 3},
  reminder: false,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedProfile({String? remoteId}) =>
      UserProfileDao(db).upsert(UserProfilesCompanion(
        remoteId: Value(remoteId),
        displayName: const Value('bro'),
        subscriptionStatus: const Value('trial'),
      ));

  test('payload uses the server shapes and wire values', () {
    final p = OnboardingPersistence.payload(
      _answers,
      now: DateTime.utc(2026, 9, 30, 12),
    );
    expect(p['health_consent_at'], '2026-09-30T12:00:00.000Z');
    expect(p['gender'], 'female');
    expect(p['goal'], 'lose_weight');
    expect(p['experience'], 'intermediate');
    expect(p['health_issue'], 'poor_sleep');
    expect(p['body_weight_kg'], 72.0);
    expect(p['target_weight_kg'], 64.0);
    expect(p['height_cm'], 167.6);
    expect(p['weight_unit'], 'lbs');
    expect(p['height_unit'], 'ft');
    // 31 Feb 1995 clamps to the month's last day.
    expect(p['birth_date'], '1995-02-28');
    // Enum order, not tap order.
    expect(p['focus_areas'], ['back', 'glutes']);
    expect(p['injuries'], ['shoulder', 'knee']);
    expect(p['injury_rest_days'], 5);
    expect(p['training_days'], [1, 3, 5]);
  });

  test('"None" sends an empty injury list and no rest days', () {
    final p = OnboardingPersistence.payload(
      const OnboardingData(
        healthConsent: HealthConsent.granted,
        noInjuries: true,
        restDays: 9,
      ),
    );
    expect(p['injuries'], isEmpty);
    expect(p.containsKey('injury_rest_days'), isTrue);
    expect(p['injury_rest_days'], isNull);
  });

  test('declined consent clears every health column instead', () {
    final p = OnboardingPersistence.payload(
      _answers.copyWith(healthConsent: HealthConsent.declined),
    );
    for (final column in [
      'body_weight_kg',
      'height_cm',
      'target_weight_kg',
      'health_issue',
      'injuries',
      'injury_rest_days',
      'health_consent_at',
    ]) {
      expect(p.containsKey(column), isTrue, reason: column);
      expect(p[column], isNull, reason: column);
    }
    // The non-health answers still go through.
    expect(p['goal'], 'lose_weight');
    expect(p['birth_date'], '1995-02-28');
    expect(p['training_days'], [1, 3, 5]);
  });

  test('unanswered choices are left out rather than blanked', () {
    final p = OnboardingPersistence.payload(const OnboardingData());
    expect(p.keys, isNot(contains('gender')));
    expect(p.keys, isNot(contains('goal')));
    expect(p.keys, isNot(contains('experience')));
    // Consent never asked (dev skip): health columns untouched either way.
    for (final column in [
      'body_weight_kg',
      'height_cm',
      'target_weight_kg',
      'health_issue',
      'injuries',
      'injury_rest_days',
      'health_consent_at',
    ]) {
      expect(p.keys, isNot(contains(column)), reason: column);
    }
  });

  test('save writes the profile locally and queues one sync update',
      () async {
    await seedProfile(remoteId: 'auth-uid-1');

    await OnboardingPersistence.save(
      db: db,
      sync: SyncService(db, null),
      data: _answers,
    );

    final profile = (await UserProfileDao(db).getFirst())!;
    expect(profile.displayName, 'bro', reason: 'merge keeps other columns');
    expect(profile.gender, 'female');
    expect(profile.goal, 'lose_weight');
    expect(profile.experience, 'intermediate');
    expect(profile.bodyWeightKg, 72.0);
    expect(profile.targetWeightKg, 64.0);
    expect(profile.weightUnit, 'lbs');
    expect(profile.heightUnit, 'ft');
    expect(profile.birthDate, DateTime(1995, 2, 28));
    expect(jsonDecode(profile.focusAreas!), ['back', 'glutes']);
    expect(jsonDecode(profile.injuries!), ['shoulder', 'knee']);
    expect(profile.injuryRestDays, 5);
    expect(jsonDecode(profile.trainingDays!), [1, 3, 5]);
    expect(profile.healthConsentAt, isNotNull);

    final queued = await db.select(db.syncQueue).get();
    expect(queued, hasLength(1));
    expect(queued.single.syncTableName, 'user_profiles');
    expect(queued.single.operation, 'update');
    final payload = jsonDecode(queued.single.payload) as Map<String, dynamic>;
    expect(payload['remote_id'], 'auth-uid-1');
    expect(payload['goal'], 'lose_weight');
    expect(payload['training_days'], [1, 3, 5]);
    expect(payload['health_consent_at'], isA<String>());
  });

  test('declining clears health values left by an earlier run', () async {
    await seedProfile(remoteId: 'auth-uid-1');
    final sync = SyncService(db, null);
    await OnboardingPersistence.save(db: db, sync: sync, data: _answers);

    await OnboardingPersistence.save(
      db: db,
      sync: sync,
      data: _answers.copyWith(healthConsent: HealthConsent.declined),
    );

    final p = (await UserProfileDao(db).getFirst())!;
    expect(p.bodyWeightKg, isNull);
    expect(p.heightCm, isNull);
    expect(p.targetWeightKg, isNull);
    expect(p.healthIssue, isNull);
    expect(p.injuries, isNull);
    expect(p.injuryRestDays, isNull);
    expect(p.healthConsentAt, isNull);
    // Not health data — kept.
    expect(p.goal, 'lose_weight');
    expect(p.birthDate, DateTime(1995, 2, 28));
  });

  test('signed out (no remote id) saves locally without queueing', () async {
    await seedProfile();

    await OnboardingPersistence.save(
      db: db,
      sync: SyncService(db, null),
      data: _answers,
    );

    expect((await UserProfileDao(db).getFirst())!.goal, 'lose_weight');
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test('a server row maps back onto the local columns', () async {
    await seedProfile(remoteId: 'auth-uid-1');
    await UserProfileDao(db).mergeIntoFirst(
      UserProfileDao.answersFromRemote({
        'gender': 'male',
        'body_weight_kg': 90.5,
        'height_cm': 182,
        'weight_unit': 'kg',
        'height_unit': 'cm',
        'birth_date': '1990-06-15',
        'target_weight_kg': 84,
        'focus_areas': ['full_body'],
        'health_issue': 'healthy',
        'injuries': <String>[],
        'injury_rest_days': null,
        'training_days': [2, 4, 6],
        'health_consent_at': '2026-09-01T08:30:00+00:00',
      }),
    );

    final p = (await UserProfileDao(db).getFirst())!;
    expect(p.healthConsentAt, DateTime.utc(2026, 9, 1, 8, 30).toLocal());
    expect(p.gender, 'male');
    expect(p.bodyWeightKg, 90.5);
    expect(p.heightCm, 182);
    expect(p.birthDate, DateTime(1990, 6, 15));
    expect(p.targetWeightKg, 84);
    expect(jsonDecode(p.focusAreas!), ['full_body']);
    expect(p.healthIssue, 'healthy');
    expect(jsonDecode(p.injuries!), isEmpty);
    expect(p.injuryRestDays, isNull);
    expect(jsonDecode(p.trainingDays!), [2, 4, 6]);
  });
}
