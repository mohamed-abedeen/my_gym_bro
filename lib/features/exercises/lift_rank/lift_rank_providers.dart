import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/exercises/lift_rank/strength_standards.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// A lift's position on the Bronze→Elite ladder, derived from the all-time
/// best estimated 1RM — the same figure the exercise detail screen displays.
class LiftRank {
  const LiftRank({required this.rank, required this.score, required this.e1RmKg});

  final Rank rank;

  /// 0–100 strength-standard score the rank derives from.
  final double score;

  /// All-time best estimated 1RM (kg) that produced the score.
  final double e1RmKg;

  /// 0–1 progress through the current band toward the next one.
  double get progressToNext => Rank.progressToNext(score);
}

/// Same fallback the calorie math uses when no bodyweight is set.
const double _fallbackBodyWeightKg = 70;

/// Rank for one exercise, or null when it isn't a rankable classic lift or
/// has no logged e1RM yet — callers hide the rank UI on null.
final liftRankProvider = FutureProvider.family<LiftRank?, String>((
  ref,
  exerciseId,
) async {
  if (!isRankableLift(exerciseId)) return null;
  final records = await ref.watch(
    exercisePersonalRecordsProvider(exerciseId).future,
  );
  final best = records.best1rm;
  if (best == null || best <= 0) return null;
  final profile = await ref.watch(userProfileProvider.future);
  final score = liftScore(
    exerciseId: exerciseId,
    e1RmKg: best,
    bodyWeightKg: profile?.bodyWeightKg ?? _fallbackBodyWeightKg,
    gender: profile?.gender,
  );
  if (score == null) return null;
  return LiftRank(rank: Rank.fromComposite(score), score: score, e1RmKg: best);
});
