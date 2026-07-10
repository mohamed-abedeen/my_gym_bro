import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';

class MockExerciseDao extends Mock implements ExerciseDao {}

/// Six-exercise fake catalogue, served as three cursor-paged pages of two.
const _catalogue = [
  ['aaa', 'arnold press'],
  ['bbb', 'bench press'],
  ['ccc', 'cable curl'],
  ['ddd', 'cable fly'],
  ['eee', 'deadlift'],
  ['fff', 'front raise'],
];

String _pageJson(int start) {
  final items = _catalogue.skip(start).take(2).map((e) => '''
    {"exerciseId":"${e[0]}","name":"${e[1]}",
     "gifUrl":"https://static.exercisedb.dev/media/${e[0]}.gif",
     "bodyParts":["chest"],"equipments":["barbell"],
     "targetMuscles":["pectorals"],"secondaryMuscles":[],
     "instructions":["Step:1 lift"]}''').join(',');
  final hasNext = start + 2 < _catalogue.length;
  final cursor = hasNext ? '"${_catalogue[start + 1][0]}"' : 'null';
  return '{"success":true,"meta":{"total":${_catalogue.length},'
      '"hasNextPage":$hasNext,"nextCursor":$cursor},"data":[$items]}';
}

Exercise _row(ExercisesCompanion c) => Exercise(
      localId: 0,
      syncStatus: 'synced',
      exerciseId: c.exerciseId.value,
      name: c.name.value,
      isCustom: false,
      usageCount: 0,
      isFavorite: false,
    );

void main() {
  late Map<String, ExercisesCompanion> store;
  late MockExerciseDao dao;
  late List<Uri> requests;
  late bool rateLimited;
  late http.Client client;

  setUpAll(() => registerFallbackValue(<ExercisesCompanion>[]));

  ExerciseRepository buildRepo() {
    store = {};
    requests = [];
    rateLimited = false;

    dao = MockExerciseDao();
    List<Exercise> sorted() => (store.values.map(_row).toList()
      ..sort((a, b) => a.name.compareTo(b.name)));
    when(() => dao.countCatalogue()).thenAnswer((_) async => store.length);
    when(() => dao.count()).thenAnswer((_) async => store.length);
    when(() => dao.cacheAll(any())).thenAnswer((inv) async {
      for (final c
          in inv.positionalArguments[0] as List<ExercisesCompanion>) {
        store[c.exerciseId.value] = c;
      }
    });
    when(() => dao.getPaged(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'))).thenAnswer((inv) async {
      final limit = inv.namedArguments[#limit] as int;
      final offset = inv.namedArguments[#offset] as int;
      return sorted().skip(offset).take(limit).toList();
    });
    when(() => dao.searchByName(any())).thenAnswer((inv) async {
      final q = (inv.positionalArguments[0] as String).toLowerCase();
      return sorted().where((e) => e.name.contains(q)).toList();
    });

    client = MockClient((req) async {
      requests.add(req.url);
      if (rateLimited && requests.length > 1) {
        return http.Response('', 429);
      }
      final after = req.url.queryParameters['after'];
      final start = after == null
          ? 0
          : _catalogue.indexWhere((e) => e[0] == after) + 1;
      return http.Response(_pageJson(start), 200);
    });
    return ExerciseRepository(ExerciseApiService(client: client), dao);
  }

  test('browse syncs only as many pages as the request needs', () async {
    final repo = buildRepo();
    final page = await repo.browse(offset: 0, limit: 2);
    expect(requests, hasLength(1));
    expect(page.items.map((e) => e.exerciseId), ['aaa', 'bbb']);
    expect(page.fromCache, isFalse);
  });

  test('search pulls the full catalogue then filters locally', () async {
    final repo = buildRepo();
    final page = await repo.searchByName('cable');
    expect(requests, hasLength(3)); // 3 pages of 2 = whole catalogue
    expect(store, hasLength(6));
    expect(page.items.map((e) => e.name), ['cable curl', 'cable fly']);
    expect(page.fromCache, isFalse);
  });

  test('rate limit degrades to cache; a later call resumes the cursor',
      () async {
    final repo = buildRepo();
    rateLimited = true; // every request after the first 429s

    final degraded = await repo.browse(offset: 0, limit: 4);
    expect(degraded.fromCache, isTrue);
    expect(degraded.items, hasLength(2)); // only page 1 made it in

    rateLimited = false;
    final resumed = await repo.browse(offset: 0, limit: 4);
    expect(resumed.fromCache, isFalse);
    expect(resumed.items, hasLength(4));
    // The retry resumed from the saved cursor instead of restarting.
    expect(requests.last.queryParameters['after'], 'bbb');
  });

  test('concurrent browse + search share one sync (no duplicate pages)',
      () async {
    final repo = buildRepo();
    // Fire both without awaiting — pre-fix the two sync loops interleaved
    // on the shared cursor and re-fetched the same pages.
    final results = await Future.wait([
      repo.browse(offset: 0, limit: 4),
      repo.searchByName('cable'),
    ]);
    expect(requests, hasLength(3)); // whole catalogue fetched exactly once
    expect(requests.map((u) => u.queryParameters['after']).toSet(),
        hasLength(3)); // no cursor fetched twice
    expect(results[1].items.map((e) => e.name), ['cable curl', 'cable fly']);
  });

  test('browse is served from the DB without waiting on a running warm-up',
      () async {
    final repo = buildRepo();
    await repo.searchByName('cable'); // fills the whole catalogue (3 pages)
    final before = requests.length;

    // "Next app launch": fresh repo (session sync state reset), same DB.
    final relaunch =
        ExerciseRepository(ExerciseApiService(client: client), dao);
    final page = await relaunch.browse(offset: 0, limit: 4);
    expect(page.items, hasLength(4));
    expect(page.fromCache, isFalse);
    expect(requests.length, before); // no network at all

    // Warm-up needs a single request to learn the catalogue is complete,
    // after which search is fully local too.
    await relaunch.warmUp();
    expect(requests.length, before + 1);
    final search = await relaunch.searchByName('cable');
    expect(search.fromCache, isFalse);
    expect(requests.length, before + 1);
  });
}
