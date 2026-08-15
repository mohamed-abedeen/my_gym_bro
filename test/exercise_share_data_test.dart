import 'package:flutter_test/flutter_test.dart';

import 'package:my_gym_bro/core/database/daos/session_dao.dart'
    show ExercisePersonalRecords;
import 'package:my_gym_bro/features/exercises/lift_rank/lift_rank_providers.dart'
    show LiftRank;
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/share/exercise_share_data.dart';

void main() {
  group('ExerciseShareData.fromStats', () {
    test('maps records, rank, and history; trend sorts oldest → newest', () {
      final data = ExerciseShareData.fromStats(
        exerciseName: 'Bench Press',
        muscleGroup: 'Chest',
        records: const ExercisePersonalRecords(
          maxWeight: 100,
          best1rm: 112.5,
          bestSetVolume: 800,
          bestSessionVolume: 5200,
        ),
        rank: LiftRank(rank: Rank.fromBand(7), score: 55, e1RmKg: 112.5),
        volumeHistory: [
          (date: DateTime(2026, 8, 10), volume: 5200),
          (date: DateTime(2026, 8, 2), volume: 4100),
          (date: DateTime(2026, 8, 5), volume: 4700),
        ],
        date: DateTime(2026, 8, 15),
      );

      expect(data.exerciseName, 'Bench Press');
      expect(data.muscleGroup, 'Chest');
      expect(data.maxWeightKg, 100);
      expect(data.best1RmKg, 112.5);
      expect(data.bestSetVolumeKg, 800);
      expect(data.bestSessionVolumeKg, 5200);
      expect(data.rankBand, 7);
      expect(data.sessionCount, 3);
      expect(
        [for (final p in data.trend) p.volumeKg],
        [4100, 4700, 5200],
      );
      expect(data.date, DateTime(2026, 8, 15));
    });

    test('trims the trend to the most recent maxTrendPoints sessions', () {
      final history = [
        for (var i = 0; i < 30; i++)
          (date: DateTime(2026, 1, 1 + i), volume: 1000.0 + i),
      ];
      final data = ExerciseShareData.fromStats(
        exerciseName: 'Squat',
        volumeHistory: history,
      );

      expect(data.sessionCount, 30);
      expect(data.trend.length, ExerciseShareData.maxTrendPoints);
      // Keeps the tail (most recent), still oldest → newest.
      expect(data.trend.first.volumeKg,
          1000.0 + 30 - ExerciseShareData.maxTrendPoints);
      expect(data.trend.last.volumeKg, 1029.0);
    });

    test('never-logged exercise: null PRs, no rank, empty trend', () {
      final data = ExerciseShareData.fromStats(exerciseName: 'Face Pull');

      expect(data.maxWeightKg, isNull);
      expect(data.best1RmKg, isNull);
      expect(data.bestSetVolumeKg, isNull);
      expect(data.bestSessionVolumeKg, isNull);
      expect(data.rankBand, isNull);
      expect(data.trend, isEmpty);
      expect(data.sessionCount, 0);
    });
  });
}
