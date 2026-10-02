import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/friendship_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/social/friend_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _me = 'me-uid';

/// `claimUsername` against a real Supabase client over a fake HTTP layer, so
/// the PostgREST request is exactly the one the app sends. The bug this pins:
/// the claim filtered on `id` (the table's own key) instead of `user_id` (the
/// auth uid), matched no row, got 200 + `[]` back and reported success.
void main() {
  late AppDatabase db;
  late List<http.Request> requests;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// [status] + JSON [body] for every request.
  Future<FriendRepository> repo(int status, Object body) async {
    requests = [];
    final client = SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    // Signed in as [_me] without a network call: a token with no `exp`
    // claim never counts as expired, so nothing tries to refresh it.
    await client.auth.recoverSession(jsonEncode({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {'id': _me, 'aud': 'authenticated', 'created_at': ''},
    }));
    return FriendRepository(
      friendshipDao: FriendshipDao(db),
      userProfileDao: UserProfileDao(db),
      syncService: SyncService(db, null),
      supabase: client,
    );
  }

  Future<void> seedProfile({String remoteId = _me}) =>
      UserProfileDao(db).upsert(UserProfilesCompanion(remoteId: Value(remoteId)));

  Future<String?> localUsername() async =>
      (await UserProfileDao(db).getFirst())!.username;

  test("claims through the caller's user_id and saves it locally", () async {
    await seedProfile();
    final r = await repo(200, [
      {'username': 'bro_one'},
    ]);

    expect(await r.claimUsername('  @Bro_One '), ClaimUsernameResult.claimed);

    final req = requests.single;
    expect(req.method, 'PATCH');
    expect(req.url.path, '/rest/v1/user_profiles');
    expect(req.url.queryParameters['user_id'], 'eq.$_me');
    expect(req.url.queryParameters.containsKey('id'), isFalse);
    expect(req.url.queryParameters['select'], 'username');
    expect(jsonDecode(req.body), {'username': 'bro_one'});
    expect(await localUsername(), 'bro_one');
  });

  test('an update that matched no row is not a claim', () async {
    await seedProfile();
    final r = await repo(200, <Object>[]);

    expect(await r.claimUsername('bro_one'), ClaimUsernameResult.offline);
    expect(await localUsername(), isNull);
  });

  test('a taken name maps to taken, a refused grant to offline', () async {
    await seedProfile();
    final taken = await repo(409, {
      'code': '23505',
      'message': 'duplicate key value violates unique constraint',
    });
    expect(await taken.claimUsername('bro_one'), ClaimUsernameResult.taken);

    // Before migration 023 lands, the column grant is missing.
    final refused = await repo(403, {
      'code': '42501',
      'message': 'permission denied for table user_profiles',
    });
    expect(await refused.claimUsername('bro_one'), ClaimUsernameResult.offline);
    expect(await localUsername(), isNull);
  });

  test("never claims through another account's local profile", () async {
    await seedProfile(remoteId: 'previous-account');
    final r = await repo(200, [
      {'username': 'bro_one'},
    ]);

    expect(await r.claimUsername('bro_one'), ClaimUsernameResult.offline);
    expect(requests, isEmpty);
  });
}
