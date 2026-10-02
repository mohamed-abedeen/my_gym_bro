import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/health_consent.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';

void main() {
  late AppDatabase db;
  late SyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sync = SyncService(db, null);
  });
  tearDown(() => db.close());

  Future<void> seed({String? remoteId}) =>
      UserProfileDao(db).upsert(UserProfilesCompanion(
        remoteId: Value(remoteId),
        goal: const Value('build_muscle'),
        bodyWeightKg: const Value(81.5),
        heightCm: const Value(180),
        targetWeightKg: const Value(86),
        healthIssue: const Value('poor_sleep'),
        injuries: const Value('["knee"]'),
        injuryRestDays: const Value(4),
        healthConsentAt: Value(DateTime(2026, 9, 2)),
      ));

  Future<List<Map<String, dynamic>>> queued() async => [
        for (final row in await db.select(db.syncQueue).get())
          jsonDecode(row.payload) as Map<String, dynamic>,
      ];

  test('withdrawing deletes the health data here and on the account',
      () async {
    await seed(remoteId: 'uid-1');

    await withdrawHealthConsent(db: db, sync: sync);

    final p = (await UserProfileDao(db).getFirst())!;
    expect(p.bodyWeightKg, isNull);
    expect(p.heightCm, isNull);
    expect(p.targetWeightKg, isNull);
    expect(p.healthIssue, isNull);
    expect(p.injuries, isNull);
    expect(p.injuryRestDays, isNull);
    expect(p.healthConsentAt, isNull);
    expect(p.goal, 'build_muscle', reason: 'not health data');

    final payload = (await queued()).single;
    expect(payload['remote_id'], 'uid-1');
    for (final column in [...healthDataColumns, 'health_consent_at']) {
      expect(payload.containsKey(column), isTrue, reason: column);
      expect(payload[column], isNull, reason: column);
    }
  });

  test('granting records when, locally and for the account', () async {
    await seed(remoteId: 'uid-1');
    await withdrawHealthConsent(db: db, sync: sync);

    final at = DateTime.utc(2026, 9, 30, 18);
    await grantHealthConsent(db: db, sync: sync, at: at);

    final p = (await UserProfileDao(db).getFirst())!;
    expect(p.healthConsentAt, at.toLocal());
    expect(
      (await queued()).last,
      {'remote_id': 'uid-1', 'health_consent_at': '2026-09-30T18:00:00.000Z'},
    );
  });

  test('signed out: local only, nothing queued', () async {
    await seed();
    await withdrawHealthConsent(db: db, sync: sync);
    expect((await UserProfileDao(db).getFirst())!.bodyWeightKg, isNull);
    expect(await queued(), isEmpty);
  });
}
