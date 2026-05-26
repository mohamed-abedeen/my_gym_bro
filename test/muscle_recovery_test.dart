import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';

class MockSessionDao extends Mock implements SessionDao {}
class MockExerciseDao extends Mock implements ExerciseDao {}

void main() {
  late MuscleRecoveryService service;

  setUp(() {
    service = MuscleRecoveryService(MockSessionDao(), MockExerciseDao());
  });

  // ── recoveryHoursFor ────────────────────────────────────────────────────────

  group('MuscleRecoveryService.recoveryHoursFor', () {
    test('large muscle (Chest) returns 60 hours', () {
      expect(MuscleRecoveryService.recoveryHoursFor('Chest'), 60.0);
    });

    test('large muscle (Quads) returns 60 hours', () {
      expect(MuscleRecoveryService.recoveryHoursFor('Quads'), 60.0);
    });

    test('medium muscle (Shoulders) returns 42 hours', () {
      expect(MuscleRecoveryService.recoveryHoursFor('Shoulders'), 42.0);
    });

    test('small muscle (Biceps) returns 30 hours', () {
      expect(MuscleRecoveryService.recoveryHoursFor('Biceps'), 30.0);
    });

    test('unknown muscle falls back to medium (42 hours)', () {
      expect(MuscleRecoveryService.recoveryHoursFor('Unknown'), 42.0);
    });
  });

  // ── getState ────────────────────────────────────────────────────────────────

  group('MuscleRecoveryService.getState', () {
    test('returns undertrained when lastTrainedAt is null', () {
      expect(service.getState('Chest', null), MuscleState.undertrained);
    });

    test('returns recovering within recovery window', () {
      // Chest recovery = 60h; trained 10 hours ago → still recovering
      final recentlyTrained = DateTime.now().subtract(const Duration(hours: 10));
      expect(service.getState('Chest', recentlyTrained), MuscleState.recovering);
    });

    test('returns recovered after recovery window but within retention (7 days)', () {
      // Chest recovery = 60h; trained 70 hours ago → past recovery, within 168h retention
      final trained = DateTime.now().subtract(const Duration(hours: 70));
      expect(service.getState('Chest', trained), MuscleState.recovered);
    });

    test('returns undertrained after retention window (> 7 days)', () {
      final longAgo = DateTime.now().subtract(const Duration(days: 8));
      expect(service.getState('Chest', longAgo), MuscleState.undertrained);
    });

    test('returns recovering for Biceps trained 20 hours ago (recovery=30h)', () {
      final trained = DateTime.now().subtract(const Duration(hours: 20));
      expect(service.getState('Biceps', trained), MuscleState.recovering);
    });

    test('returns recovered for Biceps trained 35 hours ago (recovery=30h)', () {
      final trained = DateTime.now().subtract(const Duration(hours: 35));
      expect(service.getState('Biceps', trained), MuscleState.recovered);
    });
  });

  // ── getRecoveryPercent ──────────────────────────────────────────────────────

  group('MuscleRecoveryService.getRecoveryPercent', () {
    test('returns null for never-trained muscle', () {
      expect(service.getRecoveryPercent('Chest', null), isNull);
    });

    test('returns null after retention window', () {
      final longAgo = DateTime.now().subtract(const Duration(days: 8));
      expect(service.getRecoveryPercent('Chest', longAgo), isNull);
    });

    test('returns 1.0 when fully recovered and within retention', () {
      // Chest: 60h recovery; trained 70h ago → past recovery, in retention
      final trained = DateTime.now().subtract(const Duration(hours: 70));
      expect(service.getRecoveryPercent('Chest', trained), 1.0);
    });

    test('returns ~0.5 at halfway through recovery window', () {
      // Biceps: 30h recovery; trained 15h ago → 50% recovered
      final trained = DateTime.now().subtract(const Duration(hours: 15));
      final percent = service.getRecoveryPercent('Biceps', trained);
      expect(percent, isNotNull);
      expect(percent!, closeTo(0.5, 0.05));
    });

    test('returns value close to 0 immediately after training', () {
      final justTrained = DateTime.now().subtract(const Duration(minutes: 1));
      final percent = service.getRecoveryPercent('Chest', justTrained);
      expect(percent, isNotNull);
      expect(percent!, lessThan(0.01));
    });

    test('recovery percent is clamped between 0 and 1', () {
      final trained = DateTime.now().subtract(const Duration(hours: 10));
      final percent = service.getRecoveryPercent('Chest', trained);
      expect(percent, isNotNull);
      expect(percent!, inInclusiveRange(0.0, 1.0));
    });
  });

  // ── MuscleStateInfo ─────────────────────────────────────────────────────────

  group('MuscleStateInfo.soreness', () {
    test('soreness is inverse of recoveryPercent', () {
      const info = MuscleStateInfo(
        muscleGroup: 'Chest',
        state: MuscleState.recovering,
        recoveryPercent: 0.3,
      );
      expect(info.soreness, closeTo(0.7, 0.001));
    });

    test('soreness is 0 when fully recovered (recoveryPercent = 1.0)', () {
      const info = MuscleStateInfo(
        muscleGroup: 'Chest',
        state: MuscleState.recovered,
        recoveryPercent: 1.0,
      );
      expect(info.soreness, 0.0);
    });

    test('soreness is null when recoveryPercent is null', () {
      const info = MuscleStateInfo(
        muscleGroup: 'Chest',
        state: MuscleState.undertrained,
      );
      expect(info.soreness, isNull);
    });
  });
}
