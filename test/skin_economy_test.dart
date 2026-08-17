import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/skin_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/settings/skin_repository.dart';

/// Offline-first skins economy: ownership is a server-written mirror (no
/// outbox), selection is a synced profile field (outbox), and everything
/// degrades with a null Supabase client — a real network call would throw.
void main() {
  late AppDatabase db;
  late SkinDao dao;
  late SkinRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = SkinDao(db);
    repo = SkinRepository(
      db: db,
      sync: SyncService(db, null),
      supabase: null,
    );
  });

  tearDown(() => db.close());

  Future<List<SyncQueueData>> outbox() => db.select(db.syncQueue).get();

  SkinOwnershipsCompanion grant(String id, {String source = 'earned'}) =>
      SkinOwnershipsCompanion(
        skinId: Value(id),
        source: Value(source),
        fetchedAt: Value(DateTime.now()),
      );

  group('SkinDao', () {
    test('replaceAll swaps the whole mirror wholesale', () async {
      await dao.replaceAll([grant('gold', source: 'purchased')]);
      expect(await dao.getOwnedIds(), {'gold'});

      await dao.replaceAll([grant('volkano'), grant('atack')]);
      expect(await dao.getOwnedIds(), {'volkano', 'atack'});
    });

    test('upsertAll is idempotent on skinId', () async {
      await dao.upsertAll([grant('gold', source: 'purchased')]);
      await dao.upsertAll([grant('gold', source: 'purchased')]);
      final rows = await db.select(db.skinOwnerships).get();
      expect(rows.length, 1);
      expect(rows.single.skinId, 'gold');
    });
  });

  group('SkinRepository.persistActiveSkin', () {
    test('no profile → no-op, nothing enqueued', () async {
      await repo.persistActiveSkin('carbon');
      expect(await outbox(), isEmpty);
    });

    test('unsynced profile (no remoteId) → local write only', () async {
      await db.into(db.userProfiles).insert(
            const UserProfilesCompanion(displayName: Value('Bro')),
          );
      await repo.persistActiveSkin('carbon');

      final profile = await db.select(db.userProfiles).getSingle();
      expect(profile.activeSkinId, 'carbon');
      expect(await outbox(), isEmpty);
    });

    test('synced profile → local write + user_profiles update in outbox',
        () async {
      await db.into(db.userProfiles).insert(
            const UserProfilesCompanion(
              displayName: Value('Bro'),
              remoteId: Value('remote-1'),
            ),
          );
      await repo.persistActiveSkin('gold');

      final profile = await db.select(db.userProfiles).getSingle();
      expect(profile.activeSkinId, 'gold');

      final queued = await outbox();
      expect(queued.length, 1);
      expect(queued.single.syncTableName, 'user_profiles');
      expect(queued.single.operation, 'update');
      final payload = jsonDecode(queued.single.payload) as Map;
      expect(payload['remote_id'], 'remote-1');
      expect(payload['active_skin_id'], 'gold');
    });
  });

  group('SkinRepository offline degradation', () {
    test('refreshFromServer with a null client keeps the cache', () async {
      await dao.replaceAll([grant('metal')]);
      await repo.refreshFromServer();
      expect(await dao.getOwnedIds(), {'metal'});
    });
  });

  group('skinIdsForProducts', () {
    test('maps store product ids to skin ids', () {
      expect(
        skinIdsForProducts({'mgb_skin_gold', 'mgb_skin_galaxy'}),
        {'gold', 'galaxy'},
      );
    });

    test('ignores unknown products (e.g. the subscription)', () {
      expect(skinIdsForProducts({'mgb_premium_monthly'}), isEmpty);
    });
  });
}
