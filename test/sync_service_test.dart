import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';

void main() {
  group('SyncService.isSafeTableName', () {
    test('accepts lowercase snake_case table names', () {
      expect(SyncService.isSafeTableName('sessions'), isTrue);
      expect(SyncService.isSafeTableName('user_profiles'), isTrue);
      expect(SyncService.isSafeTableName('post_likes'), isTrue);
    });

    test('rejects anything that could carry SQL or is malformed', () {
      expect(SyncService.isSafeTableName('Sessions'), isFalse); // uppercase
      expect(SyncService.isSafeTableName('sets; drop table'), isFalse);
      expect(SyncService.isSafeTableName('sets-1'), isFalse); // hyphen
      expect(SyncService.isSafeTableName('sets1'), isFalse); // digit
      expect(SyncService.isSafeTableName(''), isFalse); // empty
    });
  });

  group('SyncService.remoteKeyColumn', () {
    test('user_profiles is keyed by the auth uid, not the server PK', () {
      // The profile row's remote_id holds auth.users.id (auth_notifier
      // bootstraps it that way); the server row's `id` is an unrelated
      // generated uuid. PATCHing by `id` matched zero rows and silently
      // dropped tone/username/skin updates.
      expect(SyncService.remoteKeyColumn('user_profiles'), 'user_id');
    });

    test('every other synced table is keyed by the server PK', () {
      expect(SyncService.remoteKeyColumn('sessions'), 'id');
      expect(SyncService.remoteKeyColumn('friendships'), 'id');
      expect(SyncService.remoteKeyColumn('challenge_participants'), 'id');
    });
  });

  group('SyncService.extractRemoteId', () {
    test('returns remote_id and removes it from the payload', () {
      final payload = <String, dynamic>{'remote_id': 'abc', 'a': 1};
      expect(SyncService.extractRemoteId(payload), 'abc');
      expect(payload, {'a': 1});
    });

    test('returns null and leaves the payload untouched when absent', () {
      final payload = <String, dynamic>{'a': 1};
      expect(SyncService.extractRemoteId(payload), isNull);
      expect(payload, {'a': 1});
    });
  });
}
