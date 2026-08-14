import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/exercise_mapping.dart';

void main() {
  // The dataset's secondaryMuscles field uses an anatomical vocabulary
  // ("latissimus dorsi", "rhomboids") that differs from targetMuscles —
  // these used to fall through to 'Other' and be silently dropped.
  group('ExerciseMapping.resolveSecondaryMuscleGroup', () {
    test('maps anatomical secondary names to canonical groups', () {
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('chest'), 'Chest');
      expect(
          ExerciseMapping.resolveSecondaryMuscleGroup('upper chest'), 'Chest');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('latissimus dorsi'),
          'Lats');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('rhomboids'),
          'Upper Back');
      expect(
          ExerciseMapping.resolveSecondaryMuscleGroup('trapezius'), 'Traps');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('lower back'),
          'Lower Back');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('core'), 'Core');
      expect(
          ExerciseMapping.resolveSecondaryMuscleGroup('quadriceps'), 'Quads');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('brachialis'),
          'Biceps');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('soleus'), 'Calves');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('rear deltoids'),
          'Rear Delt');
    });

    test('falls back to the targetMuscles vocabulary for overlapping terms',
        () {
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('triceps'),
          'Triceps');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('upper back'),
          'Upper Back');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('traps'), 'Traps');
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('hamstrings'),
          'Hamstrings');
    });

    test('refines generic shoulder terms via the exercise name', () {
      expect(
        ExerciseMapping.resolveSecondaryMuscleGroup(
          'shoulders',
          exerciseName: 'Barbell Overhead Press',
        ),
        'Front Delt',
      );
      expect(
        ExerciseMapping.resolveSecondaryMuscleGroup(
          'deltoids',
          exerciseName: 'Dumbbell Bench Press',
        ),
        'Shoulders', // unclassifiable name → generic bucket
      );
    });

    test('returns Other for untracked terms', () {
      expect(ExerciseMapping.resolveSecondaryMuscleGroup('feet'), 'Other');
    });

    test('is case- and whitespace-insensitive', () {
      expect(ExerciseMapping.resolveSecondaryMuscleGroup(' Rhomboids '),
          'Upper Back');
    });
  });
}
