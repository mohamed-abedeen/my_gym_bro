import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_codec.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_importer.dart';

/// Every request fails like a dead network — the importer must still land
/// everything on cached or custom rows (import never requires network).
class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(http.ClientException('offline'));
}

void main() {
  late AppDatabase db;
  late ExerciseDao exerciseDao;
  late ScheduleDao scheduleDao;
  late RoutineShareImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    exerciseDao = ExerciseDao(db);
    scheduleDao = ScheduleDao(db);
    final repo = ExerciseRepository(
      ExerciseApiService(client: _OfflineClient()),
      exerciseDao,
    );
    importer = RoutineShareImporter(db, repo, ProgramSeeder(db, repo));
  });

  tearDown(() => db.close());

  Future<void> seedCatalogue() => exerciseDao.upsert(
        const ExercisesCompanion(
          exerciseId: Value('bench123'),
          name: Value('Barbell Bench Press'),
          muscleGroup: Value('Chest'),
        ),
      );

  RoutineSharePayload program({List<SharedDay>? days}) => RoutineSharePayload(
        kind: RoutineShareKind.program,
        title: 'Shared Split',
        days: days ??
            [
              const SharedDay(
                label: 'Push',
                isRest: false,
                exercises: [
                  SharedExercise(
                    exerciseId: 'bench123',
                    name: 'Barbell Bench Press',
                    muscleGroup: 'Chest',
                    sets: 5,
                    reps: 8,
                  ),
                ],
              ),
            ],
      );

  test('catalogue id hit is used verbatim', () async {
    await seedCatalogue();
    final scheduleId = await importer.importAsNewSchedule(program());

    final schedule = await scheduleDao.getScheduleById(scheduleId);
    expect(schedule!.name, 'Shared Split');
    expect(schedule.isActive, isFalse);

    final days = await scheduleDao.getDays(scheduleId);
    final exercises = await scheduleDao.getExercises(days.single.localId);
    expect(exercises.single.exerciseId, 'bench123');
    expect(exercises.single.targetSets, 5);
    expect(exercises.single.targetReps, 8);
  });

  test('id miss falls back to exact name match in the local cache', () async {
    await seedCatalogue();
    final payload = program(
      days: [
        const SharedDay(
          label: 'Push',
          isRest: false,
          exercises: [
            SharedExercise(
              // Sender's custom exercise → id stripped, name matches a row
              // the recipient already has.
              name: 'Barbell Bench Press',
              sets: 3,
              reps: 10,
            ),
          ],
        ),
      ],
    );
    final scheduleId = await importer.importAsNewSchedule(payload);
    final days = await scheduleDao.getDays(scheduleId);
    final exercises = await scheduleDao.getExercises(days.single.localId);
    expect(exercises.single.exerciseId, 'bench123');
  });

  test('fully offline unknown exercise becomes a loggable custom row',
      () async {
    final payload = program(
      days: [
        const SharedDay(
          label: 'Mystery',
          isRest: false,
          exercises: [
            SharedExercise(
              exerciseId: 'gone404',
              name: 'Bulgarian Ring Press',
              muscleGroup: 'Chest',
              sets: 3,
              reps: 10,
            ),
          ],
        ),
      ],
    );
    final scheduleId = await importer.importAsNewSchedule(payload);
    final days = await scheduleDao.getDays(scheduleId);
    final exercises = await scheduleDao.getExercises(days.single.localId);
    expect(exercises.single.exerciseId, startsWith('custom_'));

    final row = await exerciseDao.findByExerciseId(exercises.single.exerciseId);
    expect(row!.name, 'Bulgarian Ring Press');
    expect(row.muscleGroup, 'Chest');
    expect(row.isCustom, isTrue);
  });

  test('rest days, cardio targets and ordering are preserved', () async {
    await seedCatalogue();
    final payload = program(
      days: [
        const SharedDay(
          label: 'Cardio',
          isRest: false,
          exercises: [
            SharedExercise(
              exerciseId: 'bench123',
              name: 'Barbell Bench Press',
              sets: 3,
              reps: 10,
            ),
            SharedExercise(
              name: 'Treadmill Run',
              sets: 1,
              reps: 1,
              durationSeconds: 600,
              distance: 2.5,
            ),
          ],
        ),
        const SharedDay(label: 'Rest', isRest: true, exercises: []),
      ],
    );
    final scheduleId = await importer.importAsNewSchedule(payload);
    final days = await scheduleDao.getDays(scheduleId);
    expect(days, hasLength(2));
    expect(days.first.dayIndex, 0);
    expect(days.last.isRestDay, isTrue);

    final exercises = await scheduleDao.getExercises(days.first.localId);
    expect(exercises.map((e) => e.orderIndex).toList(), [0, 1]);
    expect(exercises.last.targetDurationSeconds, 600);
    expect(exercises.last.targetDistance, 2.5);
    expect(
      await scheduleDao.getExercises(days.last.localId),
      isEmpty,
    );
  });

  test('append puts the shared day at the end of the cycle', () async {
    await seedCatalogue();
    final existing = await scheduleDao.createSchedule(
      SchedulesCompanion(
        name: const Value('Mine'),
        isActive: const Value(true),
        createdAt: Value(DateTime.now()),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await scheduleDao.addDay(
        ScheduleDaysCompanion(
          scheduleId: Value(existing),
          dayIndex: Value(i),
          label: Value('Day ${i + 1}'),
          isRestDay: const Value(false),
        ),
      );
    }

    final payload = RoutineSharePayload(
      kind: RoutineShareKind.day,
      title: 'Leg Day',
      days: [
        const SharedDay(
          label: 'Legs',
          isRest: false,
          exercises: [
            SharedExercise(
              exerciseId: 'bench123',
              name: 'Barbell Bench Press',
              sets: 3,
              reps: 10,
            ),
          ],
        ),
      ],
    );
    final scheduleId =
        await importer.appendDayToSchedule(payload, existing);
    expect(scheduleId, existing);

    final days = await scheduleDao.getDays(existing);
    expect(days, hasLength(3));
    expect(days.last.dayIndex, 2);
    expect(days.last.label, 'Legs');
  });
}
