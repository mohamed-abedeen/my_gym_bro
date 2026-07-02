import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/workout/calorie_service.dart';

void main() {
  group('CalorieService.metForExercise', () {
    test('cardio runs hottest', () {
      expect(CalorieService.metForExercise(muscleGroup: 'Cardio'),
          CalorieService.cardioMet);
    });

    test('big compound movers bill at the vigorous rate', () {
      expect(CalorieService.metForExercise(muscleGroup: 'Quads'),
          CalorieService.largeMuscleMet);
      expect(CalorieService.metForExercise(muscleGroup: 'Chest'),
          CalorieService.largeMuscleMet);
    });

    test('isolation and unknown groups bill light', () {
      expect(CalorieService.metForExercise(muscleGroup: 'Biceps'),
          CalorieService.smallMuscleMet);
      expect(
        CalorieService.metForExercise(),
        CalorieService.smallMuscleMet,
      );
    });
  });

  group('CalorieService.estimateSessionCalories', () {
    test('matches the legacy flat model with no efforts', () {
      // 5 MET × 80kg × 1h = 400.
      expect(
        CalorieService.estimateSessionCalories(
          bodyWeightKg: 80,
          durationSeconds: 3600,
        ),
        400,
      );
    });

    test('returns 0 for zero duration or weight', () {
      expect(
        CalorieService.estimateSessionCalories(
          bodyWeightKg: 80,
          durationSeconds: 0,
        ),
        0,
      );
      expect(
        CalorieService.estimateSessionCalories(
          bodyWeightKg: 0,
          durationSeconds: 3600,
        ),
        0,
      );
    });

    test('splits work and rest time at their own METs', () {
      // 80kg, 1h session: 600s squats @6 MET + 3000s rest @2 MET
      // = 6×80×(600/3600) + 2×80×(3000/3600) = 80 + 133.3 → 213.
      final kcal = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
        efforts: const [ExerciseEffort(met: 6, activeSeconds: 600)],
      );
      expect(kcal, 213);
    });

    test('a dense session out-burns a padded one of equal length', () {
      const dense = [ExerciseEffort(met: 6, activeSeconds: 1800)];
      const padded = [ExerciseEffort(met: 6, activeSeconds: 450)];
      final denseKcal = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
        efforts: dense,
      );
      final paddedKcal = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
        efforts: padded,
      );
      expect(denseKcal, greaterThan(paddedKcal));
    });

    test('scales down work time that exceeds the session duration', () {
      // 2h of claimed work inside a 1h session → work is halved, no rest.
      final kcal = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
        efforts: const [ExerciseEffort(met: 6, activeSeconds: 7200)],
      );
      // 6 × 80 × 1h = 480, nothing more.
      expect(kcal, 480);
    });

    test('applies the female adjustment', () {
      final male = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
      );
      final female = CalorieService.estimateSessionCalories(
        bodyWeightKg: 80,
        durationSeconds: 3600,
        gender: 'female',
      );
      expect(female, (male * CalorieService.femaleAdjustment).round());
    });
  });
}
