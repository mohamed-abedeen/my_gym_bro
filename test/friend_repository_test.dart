import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/friendship_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/social/friend_repository.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

const _me = 'me-uid';
const _other = 'other-uid';

/// Offline-first friend graph flows: every mutation must land in the local
/// Drift cache AND the sync outbox without touching the network. The mocked
/// Supabase client only serves `auth.currentUser.id`; SyncService gets a null
/// client, so a test would throw if any flow tried a real network call.
void main() {
  late AppDatabase db;
  late FriendshipDao dao;
  late FriendRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = FriendshipDao(db);
    final supabase = _MockSupabaseClient();
    final auth = _MockGoTrueClient();
    final user = _MockUser();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn(_me);
    repo = FriendRepository(
      friendshipDao: dao,
      userProfileDao: UserProfileDao(db),
      syncService: SyncService(db, null),
      supabase: supabase,
    );
  });

  tearDown(() => db.close());

  Future<List<SyncQueueData>> outbox() => db.select(db.syncQueue).get();

  group('sendRequest', () {
    test('writes a pending edge locally and queues the insert', () async {
      final result = await repo.sendRequest(_other);
      expect(result, SendRequestResult.sent);

      final edge = await dao.findPair(_me, _other);
      expect(edge, isNotNull);
      expect(edge!.status, 'pending');
      expect(edge.requesterId, _me);
      expect(edge.remoteId, isNotNull);

      final items = await outbox();
      expect(items, hasLength(1));
      expect(items.single.syncTableName, 'friendships');
      expect(items.single.operation, 'insert');
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(payload['requester_id'], _me);
      expect(payload['addressee_id'], _other);
      expect(payload['status'], 'pending');
      expect(payload['id'], edge.remoteId);
    });

    test('to self is refused', () async {
      expect(await repo.sendRequest(_me), SendRequestResult.unavailable);
      expect(await outbox(), isEmpty);
    });

    test('accepts instead when the other side already asked', () async {
      await dao.upsertEdge(
        requesterId: _other,
        addresseeId: _me,
        remoteId: 'r1',
      );

      final result = await repo.sendRequest(_other);
      expect(result, SendRequestResult.accepted);

      final edge = await dao.findPair(_me, _other);
      expect(edge!.status, 'accepted');
      expect(edge.respondedAt, isNotNull);

      final items = await outbox();
      expect(items, hasLength(1));
      expect(items.single.operation, 'update');
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(payload['status'], 'accepted');
      expect(payload['remote_id'], 'r1');
    });

    test('is unavailable when a blocked edge exists, and queues nothing',
        () async {
      await dao.upsertEdge(
        requesterId: _other,
        addresseeId: _me,
        remoteId: 'r1',
        status: 'blocked',
        blockedBy: _other,
      );

      expect(await repo.sendRequest(_other), SendRequestResult.unavailable);
      expect(await outbox(), isEmpty);
    });
  });

  group('accept', () {
    test('ignores an edge where I am the requester (self-accept)', () async {
      await dao.upsertEdge(
        requesterId: _me,
        addresseeId: _other,
        remoteId: 'r1',
      );
      final edge = (await dao.findPair(_me, _other))!;

      await repo.accept(edge);

      expect((await dao.findPair(_me, _other))!.status, 'pending');
      expect(await outbox(), isEmpty);
    });
  });

  group('removeEdge', () {
    test('deletes locally and queues the remote delete', () async {
      await dao.upsertEdge(
        requesterId: _me,
        addresseeId: _other,
        remoteId: 'r1',
      );
      final edge = (await dao.findPair(_me, _other))!;

      await repo.removeEdge(edge);

      expect(await dao.findPair(_me, _other), isNull);
      final items = await outbox();
      expect(items.single.operation, 'delete');
      expect(
        (jsonDecode(items.single.payload) as Map)['remote_id'],
        'r1',
      );
    });

    test('refuses to remove a block owned by the other side', () async {
      await dao.upsertEdge(
        requesterId: _other,
        addresseeId: _me,
        remoteId: 'r1',
        status: 'blocked',
        blockedBy: _other,
      );
      final edge = (await dao.findPair(_me, _other))!;

      await repo.removeEdge(edge);

      expect(await dao.findPair(_me, _other), isNotNull,
          reason: 'block evasion: the blocked side must not delete the edge');
      expect(await outbox(), isEmpty);
    });
  });

  group('block', () {
    test('converts an existing accepted edge and queues the update', () async {
      await dao.upsertEdge(
        requesterId: _other,
        addresseeId: _me,
        remoteId: 'r1',
        status: 'accepted',
      );

      await repo.block(_other);

      final edge = (await dao.findPair(_me, _other))!;
      expect(edge.status, 'blocked');
      expect(edge.blockedBy, _me);

      final items = await outbox();
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(items.single.operation, 'update');
      expect(payload['status'], 'blocked');
      expect(payload['blocked_by'], _me);
    });

    test('creates a pre-emptive blocked edge for a stranger', () async {
      await repo.block(_other);

      final edge = (await dao.findPair(_me, _other))!;
      expect(edge.status, 'blocked');
      expect(edge.blockedBy, _me);
      expect(edge.requesterId, _me);

      final items = await outbox();
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(items.single.operation, 'insert');
      expect(payload['status'], 'blocked');
      expect(payload['blocked_by'], _me);
    });
  });

  group('report', () {
    test('queues an insert into user_reports with the sanitized reason',
        () async {
      await repo.report(reportedUserId: _other, reason: '  harassment  ');

      final items = await outbox();
      expect(items.single.syncTableName, 'user_reports');
      expect(items.single.operation, 'insert');
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(payload['reporter_id'], _me);
      expect(payload['reported_id'], _other);
      expect(payload['reason'], 'harassment');
    });
  });

  group('relationshipFromRow', () {
    Friendship edge({
      required String requester,
      required String addressee,
      required String status,
      String? blockedBy,
    }) {
      return Friendship(
        localId: 1,
        syncStatus: 'synced',
        requesterId: requester,
        addresseeId: addressee,
        status: status,
        blockedBy: blockedBy,
      );
    }

    test('derives every state from the cached edge', () {
      expect(relationshipFromRow(null, _me), Relationship.none);
      expect(
        relationshipFromRow(
          edge(requester: _me, addressee: _other, status: 'pending'),
          _me,
        ),
        Relationship.pendingOut,
      );
      expect(
        relationshipFromRow(
          edge(requester: _other, addressee: _me, status: 'pending'),
          _me,
        ),
        Relationship.pendingIn,
      );
      expect(
        relationshipFromRow(
          edge(requester: _other, addressee: _me, status: 'accepted'),
          _me,
        ),
        Relationship.friends,
      );
      expect(
        relationshipFromRow(
          edge(
            requester: _me,
            addressee: _other,
            status: 'blocked',
            blockedBy: _me,
          ),
          _me,
        ),
        Relationship.blocked,
      );
      // Blocked by the other side → reported as none (discreet, PRD §5.6).
      expect(
        relationshipFromRow(
          edge(
            requester: _other,
            addressee: _me,
            status: 'blocked',
            blockedBy: _other,
          ),
          _me,
        ),
        Relationship.none,
      );
    });
  });
}
