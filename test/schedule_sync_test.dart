import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/schedule_sync_service.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uid = 'auth-uid-1';

/// In-memory stand-in for the account's routines in Supabase.
class _FakeCloud implements ScheduleCloud {
  List<Map<String, dynamic>> server = [];
  final pushed = <Map<String, dynamic>>[];
  bool failFetch = false;
  Object? pushError;

  @override
  bool isSignedIn = true;

  @override
  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    if (failFetch) throw Exception('offline');
    return server;
  }

  @override
  Future<void> pushSchedule(Map<String, dynamic> payload) async {
    final error = pushError;
    if (error != null) throw error;
    // Round-trip through JSON like the real RPC call.
    pushed.add(jsonDecode(jsonEncode(payload)) as Map<String, dynamic>);
  }
}

/// A server routine as PostgREST returns it with nested children.
Map<String, dynamic> _serverRoutine(
  String id,
  String name, {
  bool active = false,
  List<String> exerciseIds = const ['ex1', 'ex2'],
}) =>
    {
      'id': id,
      'name': name,
      'is_active': active,
      'schedule_days': [
        {
          'day_index': 1,
          'label': 'Pull',
          'is_rest_day': false,
          'scheduled_exercises': [
            {
              'exercise_id': 'pull1',
              'order_index': 0,
              'target_sets': 4,
              'target_reps': 8,
              'target_duration_seconds': null,
              'target_distance': null,
            },
          ],
        },
        {
          'day_index': 0,
          'label': 'Push',
          'is_rest_day': false,
          'scheduled_exercises': [
            for (var i = exerciseIds.length - 1; i >= 0; i--)
              {
                'exercise_id': exerciseIds[i],
                'order_index': i,
                'target_sets': 3,
                'target_reps': 10,
                'target_duration_seconds': i == 0 ? 600 : null,
                'target_distance': i == 0 ? 2.5 : null,
              },
          ],
        },
      ],
    };

void main() {
  late AppDatabase db;
  late _FakeCloud cloud;
  late ScheduleSyncService service;

  setUp(() async {
    ScheduleSyncService.debounce = Duration.zero;
    db = AppDatabase(NativeDatabase.memory());
    cloud = _FakeCloud();
    service = ScheduleSyncService(db, cloud);
    await db
        .into(db.userProfiles)
        .insert(const UserProfilesCompanion(remoteId: Value(_uid)));
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });

  /// A local routine with one day of [exerciseIds].
  Future<int> localRoutine(
    String name, {
    bool active = false,
    String? remoteId,
    List<String> exerciseIds = const ['a', 'b'],
  }) async {
    final id = await db.into(db.schedules).insert(SchedulesCompanion.insert(
          name: name,
          isActive: Value(active),
          remoteId: Value(remoteId),
        ));
    final day = await db.into(db.scheduleDays).insert(
          ScheduleDaysCompanion.insert(scheduleId: id, dayIndex: 0),
        );
    for (var i = 0; i < exerciseIds.length; i++) {
      await db.into(db.scheduledExercises).insert(
            ScheduledExercisesCompanion.insert(
              scheduleDayId: day,
              exerciseId: exerciseIds[i],
              orderIndex: i,
            ),
          );
    }
    return id;
  }

  Future<List<Schedule>> schedules() => db.select(db.schedules).get();

  test('a fresh install gets the account routines back, without duplicates',
      () async {
    // What the seeder leaves on a fresh install.
    await localRoutine('Arnold Split', active: true);
    await localRoutine('Bro Split');
    cloud.server = [
      _serverRoutine('11111111-1111-4111-8111-111111111111', 'Arnold Split'),
      _serverRoutine('22222222-2222-4222-8222-222222222222', 'My Routine',
          active: true, exerciseIds: ['x', 'y', 'z']),
    ];

    await service.reconcile(_uid);

    final rows = await schedules();
    expect(rows.map((s) => s.name).toList()..sort(),
        ['Arnold Split', 'Bro Split', 'My Routine']);
    // The seeded Arnold copy was replaced by the account's own.
    final arnold = rows.singleWhere((s) => s.name == 'Arnold Split');
    expect(arnold.remoteId, '11111111-1111-4111-8111-111111111111');
    // The account's active routine wins on a device that never synced.
    expect(rows.where((s) => s.isActive).map((s) => s.name), ['My Routine']);

    // Days and exercises came back in order, cardio targets included.
    final mine = rows.singleWhere((s) => s.name == 'My Routine');
    final days = await (db.select(db.scheduleDays)
          ..where((t) => t.scheduleId.equals(mine.localId)))
        .get();
    expect(days.map((d) => d.label), ['Push', 'Pull']);
    final push = await (db.select(db.scheduledExercises)
          ..where((t) => t.scheduleDayId.equals(days.first.localId)))
        .get();
    push.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(push.map((e) => e.exerciseId), ['x', 'y', 'z']);
    expect(push.first.targetDurationSeconds, 600);
    expect(push.first.targetDistance, 2.5);

    // Only the never-uploaded local routine was pushed; the restored ones
    // match the server already.
    expect(cloud.pushed.map((p) => p['name']), ['Bro Split']);
    final bro = rows.singleWhere((s) => s.name == 'Bro Split');
    expect(bro.remoteId, isNotNull);
    expect(cloud.pushed.single['id'], bro.remoteId);
  });

  test('pushes a routine whole, then only again when it changes', () async {
    final id = await localRoutine('Legs', active: true, exerciseIds: ['sq']);
    await service.reconcile(_uid);

    expect(cloud.pushed, hasLength(1));
    final payload = cloud.pushed.single;
    expect(payload['name'], 'Legs');
    expect(payload['is_active'], true);
    final days = payload['days'] as List;
    expect(days, hasLength(1));
    expect((days.single as Map)['exercises'], [
      {
        'exercise_id': 'sq',
        'order_index': 0,
        'target_sets': 3,
        'target_reps': 10,
        'target_duration_seconds': null,
        'target_distance': null,
      },
    ]);

    // Nothing changed: nothing to push.
    await service.pushChanged();
    expect(cloud.pushed, hasLength(1));

    // An edit (rename) is picked up by the table watcher.
    await (db.update(db.schedules)..where((t) => t.localId.equals(id)))
        .write(const SchedulesCompanion(name: Value('Leg Day')));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await service.pushChanged();
    expect(cloud.pushed.map((p) => p['name']), ['Legs', 'Leg Day']);
    expect(cloud.pushed.last['id'], payload['id']); // same uuid
  });

  test('nothing is pushed until the account routines were fetched', () async {
    await localRoutine('Arnold Split', active: true);
    cloud.failFetch = true;

    await service.reconcile(_uid);
    await service.pushChanged();
    expect(cloud.pushed, isEmpty);
    expect((await schedules()).single.remoteId, isNull);

    // Back online: the next sign-in event reconciles and pushes.
    cloud.failFetch = false;
    await service.reconcile(_uid);
    expect(cloud.pushed, hasLength(1));
  });

  test('a failed push is retried on the next pass', () async {
    await localRoutine('Push Day');
    cloud.pushError = Exception('timeout');
    await service.reconcile(_uid);
    expect(cloud.pushed, isEmpty);

    cloud.pushError = null;
    await service.pushChanged();
    expect(cloud.pushed, hasLength(1));
  });

  test('a permanently rejected routine is not retried until it changes',
      () async {
    await localRoutine('Huge');
    cloud.pushError = const PostgrestException(
      message: 'push_schedule: too many days',
      code: 'P0001',
    );
    await service.reconcile(_uid);
    cloud.pushError = null;
    await service.pushChanged();
    expect(cloud.pushed, isEmpty);
  });

  test('a duplicate that logged sessions point at is kept', () async {
    final seeded = await localRoutine('Arnold Split', active: true);
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          startedAt: DateTime(2026, 11),
          scheduleId: Value(seeded),
        ));
    cloud.server = [
      _serverRoutine('11111111-1111-4111-8111-111111111111', 'Arnold Split'),
    ];

    await service.reconcile(_uid);
    expect((await schedules()).where((s) => s.name == 'Arnold Split'),
        hasLength(2));
  });

  test('routines are not restored into another account profile', () async {
    cloud.server = [
      _serverRoutine('11111111-1111-4111-8111-111111111111', 'Theirs'),
    ];
    await service.reconcile('someone-else');
    expect(await schedules(), isEmpty);
    expect(cloud.pushed, isEmpty);
  });

  test('a restored routine is known on the next reconcile (idempotent)',
      () async {
    cloud.server = [
      _serverRoutine('11111111-1111-4111-8111-111111111111', 'Mine'),
    ];
    expect(await service.restore(cloud.server), 1);
    expect(await service.restore(cloud.server), 0);
    expect(await schedules(), hasLength(1));
  });

  test('deleting an uploaded routine queues the server delete', () async {
    final sync = SyncService(db, null);
    final uploaded = await localRoutine('Old',
        remoteId: '33333333-3333-4333-8333-333333333333');
    final localOnly = await localRoutine('Draft');

    await ScheduleSyncService.enqueueDelete(db, sync, uploaded);
    await ScheduleSyncService.enqueueDelete(db, sync, localOnly);

    final queue = await db.select(db.syncQueue).get();
    expect(queue, hasLength(1));
    expect(queue.single.syncTableName, 'push_schedule');
    expect(queue.single.operation, 'rpc');
    expect(jsonDecode(queue.single.payload), {
      'id': '33333333-3333-4333-8333-333333333333',
      'deleted': true,
    });
  });
}
