import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/exercises/lift_rank/strength_standards.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';

void main() {
  // Barbell bench press; male anchors 0.50 / 0.75 / 1.10 / 1.50 / 1.90 / 2.25.
  const bench = 'EIeI8Vf';

  double scoreAt(double e1Rm, {double bw = 100, String? gender}) => liftScore(
        exerciseId: bench,
        e1RmKg: e1Rm,
        bodyWeightKg: bw,
        gender: gender,
      )!;

  test('isRankableLift covers exactly the five classics', () {
    for (final id in ['EIeI8Vf', 'qXTaZnJ', 'ila4NZS', 'kTbSH9h', 'eZyBC3j']) {
      expect(isRankableLift(id), isTrue, reason: id);
    }
    expect(isRankableLift('0V2YQjW'), isFalse); // pull up
    expect(isRankableLift('custom-123'), isFalse);
  });

  test('anchor ratios land exactly on 0/20/40/60/80/100', () {
    expect(scoreAt(50), 0);
    expect(scoreAt(75), 20);
    expect(scoreAt(110), 40);
    expect(scoreAt(150), 60);
    expect(scoreAt(190), 80);
    expect(scoreAt(225), 100);
  });

  test('interpolates linearly between anchors', () {
    // Midway between 0.50 and 0.75 → score 10.
    expect(scoreAt(62.5), closeTo(10, 1e-9));
    // Midway between 1.50 and 1.90 → score 70.
    expect(scoreAt(170), closeTo(70, 1e-9));
  });

  test('clamps below the floor and above the ceiling', () {
    expect(scoreAt(10), 0);
    expect(Rank.fromComposite(scoreAt(10)).band, 0); // Bronze III floor
    expect(scoreAt(400), 100);
    final top = Rank.fromComposite(scoreAt(400));
    expect(top.tier, RankTier.elite);
    expect(top.level, 1); // Elite I ceiling
  });

  test('female table is used only for gender == female', () {
    // Female anchor 0.70 → score 40; the same ratio is below 40 on the male
    // scale (1.10 anchor).
    expect(scoreAt(70, gender: 'female'), 40);
    expect(scoreAt(70), lessThan(40));
    // Null / unknown gender falls back to the male table.
    expect(scoreAt(70), scoreAt(70, gender: 'male'));
    expect(scoreAt(70, gender: 'other'), scoreAt(70, gender: 'male'));
  });

  test('returns null for unknown lifts and unusable inputs', () {
    expect(
      liftScore(exerciseId: 'nope', e1RmKg: 100, bodyWeightKg: 80),
      isNull,
    );
    expect(liftScore(exerciseId: bench, e1RmKg: 0, bodyWeightKg: 80), isNull);
    expect(liftScore(exerciseId: bench, e1RmKg: 100, bodyWeightKg: 0), isNull);
  });

  test('fromActiveSession derives session lift ranks, highest band first', () {
    final state = ActiveSessionState(
      sessionId: 1,
      exercises: [
        ActiveExercise(
          sessionExerciseId: 1,
          exerciseId: bench, // 100 kg @ 80 kg BW → ratio 1.25 → Gold-range
          name: 'Barbell Bench Press',
          sets: const [
            ActiveSet(localId: 1, setIndex: 0, weight: 100, reps: 1, isCompleted: true),
          ],
        ),
        ActiveExercise(
          sessionExerciseId: 2,
          exerciseId: 'qXTaZnJ', // squat 100 kg → ratio 1.25 → lower band
          name: 'Barbell Full Squat',
          sets: const [
            ActiveSet(localId: 2, setIndex: 0, weight: 100, reps: 1, isCompleted: true),
          ],
        ),
        ActiveExercise(
          sessionExerciseId: 3,
          exerciseId: '0V2YQjW', // pull up — not rankable, no rank row
          name: 'Pull Up',
          sets: const [
            ActiveSet(localId: 3, setIndex: 0, weight: 20, reps: 5, isCompleted: true),
          ],
        ),
      ],
    );

    final data = ShareCardData.fromActiveSession(
      state,
      workoutName: 'Push Day',
      workoutNumber: 1,
      bodyWeightKg: 80,
      gender: 'male',
    );

    expect(data.liftRanks, hasLength(2));
    expect(data.liftRanks.first.name, 'Barbell Bench Press');
    expect(
      data.liftRanks.first.band,
      greaterThan(data.liftRanks.last.band),
    );

    // No bodyweight → no ranks (and no crash).
    final noBw = ShareCardData.fromActiveSession(
      state,
      workoutName: 'Push Day',
      workoutNumber: 1,
    );
    expect(noBw.liftRanks, isEmpty);
  });
}
