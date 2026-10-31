import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/auth/local_profile_claim.dart';
import 'package:my_gym_bro/core/database/app_database.dart' hide Session;
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

const _uid = 'auth-uid-1';

/// Gap 1 — adoption. A user who used the dev/beta Skip has a local profile
/// with no `remoteId`; `WorkoutPushService` treats that as "no account" and
/// never uploads their history. Signing in must link the profile to the
/// account (without losing local answers or inventing a second identity) so
/// the backfill can run.
void main() {
  // The AuthNotifier sign-in listener asks `Purchases.isConfigured` over the
  // purchases_flutter channel; answer "not configured" so RevenueCat stays out.
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('purchases_flutter'),
    (call) async => call.method == 'isConfigured' ? false : null,
  );

  late AppDatabase db;
  late UserProfileDao dao;
  late SyncService sync;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    dao = UserProfileDao(db);
    sync = SyncService(db, null);
  });
  tearDown(() => db.close());

  Future<List<SyncQueueData>> outbox() => db.select(db.syncQueue).get();

  Map<String, dynamic> payloadOf(SyncQueueData i) =>
      jsonDecode(i.payload) as Map<String, dynamic>;

  Future<void> seedSkipProfile({
    String? goal,
    DateTime? consent,
    double? weight,
  }) =>
      db.into(db.userProfiles).insert(UserProfilesCompanion(
            displayName: const Value('Local Bro'),
            goal: Value(goal),
            gender: const Value('male'),
            bodyWeightKg: Value(weight),
            healthConsentAt: Value(consent),
            focusAreas: const Value('["chest","back"]'),
            trainingDays: const Value('[1,3,5]'),
            weightUnit: const Value('kg'),
          ));

  Future<void> seedFinishedSession() async {
    final started = DateTime.utc(2026, 9, 29, 10);
    final sid = await db.into(db.sessions).insert(SessionsCompanion.insert(
          startedAt: started,
          finishedAt: Value(started.add(const Duration(hours: 1))),
        ));
    final ex = await db.into(db.sessionExercises).insert(
        SessionExercisesCompanion.insert(
            sessionId: sid, exerciseId: 'bench_press', orderIndex: 0));
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          sessionExerciseId: ex,
          setIndex: 0,
          weight: const Value(100),
          reps: const Value(5),
          isCompleted: const Value(true),
        ));
  }

  group('LocalProfileClaim.claim', () {
    test('links the skipped profile to the account, offline', () async {
      await seedSkipProfile(goal: 'build_muscle');

      final claimed = await LocalProfileClaim.claim(
        db: db,
        sync: sync,
        userId: _uid,
        fallbackDisplayName: 'Google Name',
      );

      expect(claimed, isTrue);
      final p = (await dao.getFirst())!;
      expect(p.remoteId, _uid);
      // Local answers survive; the fallback name never overwrites them.
      expect(p.displayName, 'Local Bro');
      expect(p.goal, 'build_muscle');
      expect(p.gender, 'male');
      expect(p.focusAreas, '["chest","back"]');
      // Offline: standard 7-day trial from now.
      expect(p.trialStartedAt, isNotNull);
      expect(p.subscriptionStatus, 'trial');
      expect(p.subscriptionExpiresAt!.isAfter(DateTime.now()), isTrue);
      expect(await db.select(db.userProfiles).get(), hasLength(1));
    });

    test('server trial/subscription replace local defaults; gaps fill from '
        'the server, local answers win', () async {
      await seedSkipProfile(goal: 'build_muscle');

      await LocalProfileClaim.claim(
        db: db,
        sync: sync,
        userId: _uid,
        remote: {
          'display_name': 'Server Name',
          'trial_started_at': '2026-10-01T08:00:00Z',
          'subscription_status': 'active',
          'subscription_expires_at': '2027-10-01T08:00:00Z',
          'goal': 'lose_fat', // local has one → local wins
          'experience': 'advanced', // local empty → filled
          'username': 'iron_bro',
          'weight_unit': 'lbs', // units: server wins
          'height_unit': 'ft',
          'birth_date': '1995-04-02',
        },
      );

      final p = (await dao.getFirst())!;
      expect(p.subscriptionStatus, 'active');
      expect(p.trialStartedAt!.toUtc(), DateTime.utc(2026, 10, 1, 8));
      expect(p.subscriptionExpiresAt!.toUtc(), DateTime.utc(2027, 10, 1, 8));
      expect(p.displayName, 'Local Bro');
      expect(p.goal, 'build_muscle');
      expect(p.experience, 'advanced');
      expect(p.username, 'iron_bro');
      expect(p.weightUnit, 'lbs');
      expect(p.heightUnit, 'ft');
      expect(p.birthDate, DateTime.parse('1995-04-02'));
    });

    test('queues ONE user_profiles update with the merged answers', () async {
      await seedSkipProfile(goal: 'build_muscle');

      await LocalProfileClaim.claim(db: db, sync: sync, userId: _uid);

      final items = await outbox();
      expect(items, hasLength(1));
      expect(items.single.syncTableName, 'user_profiles');
      expect(items.single.operation, 'update');
      final payload = payloadOf(items.single);
      expect(payload['remote_id'], _uid);
      expect(payload['goal'], 'build_muscle');
      expect(payload['gender'], 'male');
      expect(payload['focus_areas'], ['chest', 'back']);
      expect(payload['training_days'], [1, 3, 5]);
    });

    test('health values upload only with consent on file', () async {
      await seedSkipProfile(weight: 82); // Settings body weight, no consent

      await LocalProfileClaim.claim(db: db, sync: sync, userId: _uid);

      final payload = payloadOf((await outbox()).single);
      expect(payload.containsKey('body_weight_kg'), isFalse);
      expect(payload.containsKey('health_consent_at'), isFalse);
      // Still kept on the device.
      expect((await dao.getFirst())!.bodyWeightKg, 82);
    });

    test('consented health values are included with the consent time',
        () async {
      await seedSkipProfile(weight: 82, consent: DateTime.utc(2026, 9, 30));

      await LocalProfileClaim.claim(db: db, sync: sync, userId: _uid);

      final payload = payloadOf((await outbox()).single);
      expect(payload['body_weight_kg'], 82);
      expect(payload['health_consent_at'], '2026-09-30T00:00:00.000Z');
    });

    test('server health values are not adopted without server consent',
        () async {
      await seedSkipProfile();

      await LocalProfileClaim.claim(
        db: db,
        sync: sync,
        userId: _uid,
        remote: {'body_weight_kg': 90.5, 'health_consent_at': null},
      );

      expect((await dao.getFirst())!.bodyWeightKg, isNull);
    });

    test('server health values come back with server consent', () async {
      await seedSkipProfile();

      await LocalProfileClaim.claim(
        db: db,
        sync: sync,
        userId: _uid,
        remote: {
          'body_weight_kg': 90.5,
          'health_consent_at': '2026-09-01T00:00:00Z',
        },
      );

      final p = (await dao.getFirst())!;
      expect(p.bodyWeightKg, 90.5);
      expect(p.healthConsentAt!.toUtc(), DateTime.utc(2026, 9, 1));
    });

    test('is idempotent: a linked profile is never re-claimed', () async {
      await seedSkipProfile();
      expect(
        await LocalProfileClaim.claim(db: db, sync: sync, userId: _uid),
        isTrue,
      );
      final before = await outbox();

      expect(
        await LocalProfileClaim.claim(db: db, sync: sync, userId: _uid),
        isFalse,
      );
      expect(
        await LocalProfileClaim.claim(db: db, sync: sync, userId: 'other'),
        isFalse,
        reason: 'a linked profile is never re-pointed at another account',
      );
      expect((await dao.getFirst())!.remoteId, _uid);
      expect(await outbox(), hasLength(before.length));
    });

    test('nothing to claim on an empty device', () async {
      expect(
        await LocalProfileClaim.claim(db: db, sync: sync, userId: _uid),
        isFalse,
      );
      expect(await dao.getFirst(), isNull);
      expect(await outbox(), isEmpty);
    });
  });

  group('sign-in through AuthNotifier', () {
    late _MockSupabaseClient supabase;
    late _MockGoTrueClient goTrue;
    late StreamController<AuthState> authEvents;
    late AuthNotifier notifier;

    const user = User(
      id: _uid,
      appMetadata: {},
      userMetadata: {'full_name': 'Google Name'},
      aud: 'authenticated',
      createdAt: '2026-10-01T00:00:00Z',
    );

    setUp(() {
      supabase = _MockSupabaseClient();
      goTrue = _MockGoTrueClient();
      authEvents = StreamController<AuthState>.broadcast();
      when(() => supabase.auth).thenReturn(goTrue);
      when(() => goTrue.onAuthStateChange)
          .thenAnswer((_) => authEvents.stream);
      // Offline: the profile pull fails and the claim runs on local data.
      when(() => supabase.from(any())).thenThrow(Exception('offline'));
      notifier = AuthNotifier(db, supabase, sync);
    });

    tearDown(() async {
      notifier.dispose();
      await authEvents.close();
    });

    Future<void> signIn() async {
      authEvents.add(AuthState(
        AuthChangeEvent.signedIn,
        Session(accessToken: 't', tokenType: 'bearer', user: user),
      ));
      await pumpEventQueue(times: 200);
    }

    test('a Skip user keeps their data and it is queued for upload',
        () async {
      await seedSkipProfile(goal: 'build_muscle');
      await seedFinishedSession();

      await signIn();

      expect(notifier.state.status, AuthStatus.authenticated);
      final p = (await dao.getFirst())!;
      expect(p.remoteId, _uid, reason: 'profile claimed for the account');
      expect(p.goal, 'build_muscle');
      expect(await db.select(db.userProfiles).get(), hasLength(1));
      expect(await db.select(db.sessions).get(), hasLength(1),
          reason: 'local history is not wiped');

      final tables = [for (final i in await outbox()) i.syncTableName];
      expect(tables, containsAll(['user_profiles', 'push_workout']));
      final session = (await db.select(db.sessions).get()).single;
      expect(session.remoteId, isNotNull, reason: 'backfill claimed a uuid');
    });

    test('a profile owned by another account is still wiped', () async {
      await db.into(db.userProfiles).insert(const UserProfilesCompanion(
            remoteId: Value('someone-else'),
            displayName: Value('First Bro'),
          ));
      await seedFinishedSession();

      await signIn();

      final p = (await dao.getFirst())!;
      expect(p.remoteId, _uid);
      expect(p.displayName, isNot('First Bro'));
      expect(await db.select(db.sessions).get(), isEmpty);
      final tables = [for (final i in await outbox()) i.syncTableName];
      expect(tables, isNot(contains('push_workout')));
    });
  });
}
