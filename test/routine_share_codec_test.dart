import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_codec.dart';

/// Wire-format codec for shared routines: sanitisation on both directions,
/// numeric clamps, `custom_*` id stripping, version gating, and the
/// day/exercise caps.
void main() {
  RoutineSharePayload decodeOk(Object? json) {
    final result = RoutineSharePayload.decode(json);
    expect(result, isA<RoutineShareDecoded>());
    return (result as RoutineShareDecoded).payload;
  }

  group('round trip', () {
    test('program with rest day, cardio fields and order survives', () {
      final payload = RoutineSharePayload(
        kind: RoutineShareKind.program,
        title: 'My Split',
        days: [
          const SharedDay(
            label: 'Push',
            isRest: false,
            exercises: [
              SharedExercise(
                exerciseId: 'abc123',
                name: 'Bench Press',
                muscleGroup: 'Chest',
                sets: 5,
                reps: 8,
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

      final decoded = decodeOk(payload.toJson());
      expect(decoded.kind, RoutineShareKind.program);
      expect(decoded.title, 'My Split');
      expect(decoded.days, hasLength(2));
      final push = decoded.days.first;
      expect(push.label, 'Push');
      expect(push.exercises.map((e) => e.name).toList(),
          ['Bench Press', 'Treadmill Run']);
      expect(push.exercises.first.exerciseId, 'abc123');
      expect(push.exercises.first.muscleGroup, 'Chest');
      expect(push.exercises.first.sets, 5);
      expect(push.exercises.first.reps, 8);
      expect(push.exercises.last.durationSeconds, 600);
      expect(push.exercises.last.distance, 2.5);
      expect(decoded.days.last.isRest, isTrue);
      expect(decoded.days.last.exercises, isEmpty);
    });

    test('day kind with exactly one day round-trips', () {
      final payload = RoutineSharePayload(
        kind: RoutineShareKind.day,
        title: 'Leg Day',
        days: [
          const SharedDay(
            label: 'Legs',
            isRest: false,
            exercises: [SharedExercise(name: 'Squat', sets: 3, reps: 10)],
          ),
        ],
      );
      final decoded = decodeOk(payload.toJson());
      expect(decoded.kind, RoutineShareKind.day);
      expect(decoded.days, hasLength(1));
    });
  });

  group('sanitisation', () {
    test('script blocks are stripped from title on encode', () {
      final payload = RoutineSharePayload(
        kind: RoutineShareKind.program,
        title: '<script>alert(1)</script>Push Pull',
        days: [
          const SharedDay(
            label: '<b>Day</b>',
            isRest: false,
            exercises: [SharedExercise(name: 'Row', sets: 3, reps: 10)],
          ),
        ],
      );
      final json = payload.toJson();
      expect(json['title'], 'Push Pull');
      expect(
        ((json['days'] as List).first as Map)['label'],
        'Day',
      );
    });

    test('tags are stripped again on decode', () {
      final decoded = decodeOk({
        'v': 1,
        'kind': 'program',
        'title': 'Plan<img src=x>',
        'days': [
          {
            'label': 'A',
            'rest': false,
            'exercises': [
              {'name': 'Curl<script>x</script>s', 'sets': 3, 'reps': 10},
            ],
          },
        ],
      });
      expect(decoded.title, 'Plan');
      expect(decoded.days.first.exercises.single.name, 'Curls');
    });

    test('numeric clamps apply on encode and decode', () {
      const exercise = SharedExercise(name: 'X', sets: 0, reps: 5000);
      final json = exercise.toJson();
      expect(json['sets'], 1);
      expect(json['reps'], 999);

      final decoded = decodeOk({
        'v': 1,
        'kind': 'day',
        'title': 'T',
        'days': [
          {
            'label': '',
            'rest': false,
            'exercises': [
              {
                'name': 'X',
                'sets': 99,
                'reps': 5000,
                'durationSeconds': 999999,
                'distance': 5000,
              },
            ],
          },
        ],
      });
      final e = decoded.days.single.exercises.single;
      expect(e.sets, 30);
      expect(e.reps, 999);
      expect(e.durationSeconds, 86400);
      expect(e.distance, 1000);
    });

    test('custom_* ids are stripped on encode, name carries the meaning', () {
      const exercise = SharedExercise(
        exerciseId: 'custom_my_move',
        name: 'My Move',
        sets: 3,
        reps: 10,
      );
      final json = exercise.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json['name'], 'My Move');
    });

    test('exercise with no name and no id is dropped on decode', () {
      final decoded = decodeOk({
        'v': 1,
        'kind': 'program',
        'title': 'T',
        'days': [
          {
            'label': 'A',
            'rest': false,
            'exercises': [
              {'name': '', 'sets': 3, 'reps': 10},
              {'name': 'Kept', 'sets': 3, 'reps': 10},
            ],
          },
        ],
      });
      expect(decoded.days.single.exercises.map((e) => e.name), ['Kept']);
    });
  });

  group('caps', () {
    test('40 days are truncated to 31', () {
      final payload = RoutineSharePayload(
        kind: RoutineShareKind.program,
        title: 'Mega',
        days: [
          for (var i = 0; i < 40; i++)
            const SharedDay(
              label: 'D',
              isRest: false,
              exercises: [SharedExercise(name: 'X', sets: 3, reps: 10)],
            ),
        ],
      );
      final decoded = decodeOk(payload.toJson());
      expect(decoded.days, hasLength(RoutineSharePayload.maxDays));
    });

    test('80 exercises in a day are truncated to 50', () {
      final payload = RoutineSharePayload(
        kind: RoutineShareKind.day,
        title: 'Big Day',
        days: [
          SharedDay(
            label: 'D',
            isRest: false,
            exercises: [
              for (var i = 0; i < 80; i++)
                SharedExercise(name: 'X$i', sets: 3, reps: 10),
            ],
          ),
        ],
      );
      final decoded = decodeOk(payload.toJson());
      expect(
        decoded.days.single.exercises,
        hasLength(RoutineSharePayload.maxExercisesPerDay),
      );
    });
  });

  group('rejection', () {
    test('newer version → UnsupportedVersion (update-the-app path)', () {
      expect(
        RoutineSharePayload.decode(
            {'v': 2, 'kind': 'program', 'title': 'T', 'days': <Object>[]}),
        isA<RoutineShareUnsupportedVersion>(),
      );
    });

    test('garbage shapes → Malformed', () {
      expect(RoutineSharePayload.decode(null), isA<RoutineShareMalformed>());
      expect(
          RoutineSharePayload.decode('nope'), isA<RoutineShareMalformed>());
      expect(
        RoutineSharePayload.decode({'v': 'x', 'kind': 'program'}),
        isA<RoutineShareMalformed>(),
      );
      expect(
        RoutineSharePayload.decode(
            {'v': 1, 'kind': 'week', 'title': 'T', 'days': <Object>[]}),
        isA<RoutineShareMalformed>(),
      );
      expect(
        RoutineSharePayload.decode(
            {'v': 1, 'kind': 'program', 'title': 'T', 'days': 'no'}),
        isA<RoutineShareMalformed>(),
      );
    });

    test('day kind must carry exactly one day', () {
      Map<String, dynamic> day(String label) => {
            'label': label,
            'rest': false,
            'exercises': [
              {'name': 'X', 'sets': 3, 'reps': 10},
            ],
          };
      expect(
        RoutineSharePayload.decode({
          'v': 1,
          'kind': 'day',
          'title': 'T',
          'days': [day('a'), day('b')],
        }),
        isA<RoutineShareMalformed>(),
      );
    });

    test('nothing importable (rest days only) → Malformed', () {
      expect(
        RoutineSharePayload.decode({
          'v': 1,
          'kind': 'program',
          'title': 'T',
          'days': [
            {'label': 'Rest', 'rest': true, 'exercises': <Object>[]},
          ],
        }),
        isA<RoutineShareMalformed>(),
      );
    });
  });
}
