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

    test('follows the exponential curve at halfway through the window', () {
      // Biceps: 30h recovery; trained 15h ago → recoveryCurve(0.5), which
      // is well past 50% (fast early repair, slow tail).
      final trained = DateTime.now().subtract(const Duration(hours: 15));
      final percent = service.getRecoveryPercent('Biceps', trained);
      expect(percent, isNotNull);
      expect(
        percent,
        closeTo(MuscleRecoveryService.recoveryCurve(0.5), 0.02),
      );
      expect(percent, greaterThan(0.5));
    });

    test('honours a dose-adjusted recovery window when provided', () {
      // 30h base, but this bout earned a 60h window → 20h in is still
      // one third of the way, not two thirds.
      final trained = DateTime.now().subtract(const Duration(hours: 40));
      final adjusted = service.getRecoveryPercent(
        'Biceps',
        trained,
        recoveryHours: 60,
      );
      expect(adjusted, isNotNull);
      expect(adjusted, lessThan(1));
      // Without the adjustment the muscle would already read recovered.
      expect(service.getRecoveryPercent('Biceps', trained), 1.0);
    });

    test('returns value close to 0 immediately after training', () {
      final justTrained = DateTime.now().subtract(const Duration(minutes: 1));
      final percent = service.getRecoveryPercent('Chest', justTrained);
      expect(percent, isNotNull);
      expect(percent, lessThan(0.01));
    });

    test('recovery percent is clamped between 0 and 1', () {
      final trained = DateTime.now().subtract(const Duration(hours: 10));
      final percent = service.getRecoveryPercent('Chest', trained);
      expect(percent, isNotNull);
      expect(percent, inInclusiveRange(0.0, 1.0));
    });
  });

  // ── recoveryCurve ───────────────────────────────────────────────────────────

  group('MuscleRecoveryService.recoveryCurve', () {
    test('is 0 at the start and 1 at the deadline', () {
      expect(MuscleRecoveryService.recoveryCurve(0), 0);
      expect(MuscleRecoveryService.recoveryCurve(1), 1);
      expect(MuscleRecoveryService.recoveryCurve(1.5), 1);
      expect(MuscleRecoveryService.recoveryCurve(-0.5), 0);
    });

    test('recovers fast early and slow late', () {
      final early = MuscleRecoveryService.recoveryCurve(0.25);
      final late = MuscleRecoveryService.recoveryCurve(0.75);
      // First quarter of the window repairs more than the third quarter.
      expect(early, greaterThan(0.25));
      expect(1 - late, lessThan(0.25));
      // Monotonic.
      expect(late, greaterThan(early));
    });
  });

  // ── doseFactor ──────────────────────────────────────────────────────────────

  group('MuscleRecoveryService.doseFactor', () {
    test('is 1 for the first bout (no reference)', () {
      expect(MuscleRecoveryService.doseFactor(12, 0), 1);
    });

    test('scales proportionally around the reference dose', () {
      expect(MuscleRecoveryService.doseFactor(12, 12), 1);
      expect(MuscleRecoveryService.doseFactor(15, 12), closeTo(1.25, 0.001));
      expect(MuscleRecoveryService.doseFactor(9, 12), closeTo(0.75, 0.001));
    });

    test('clamps extreme doses', () {
      // One token set after averaging 12 → floor at 0.6.
      expect(
        MuscleRecoveryService.doseFactor(1, 12),
        MuscleRecoveryService.minDoseFactor,
      );
      // A 3× blowout session → ceiling at 1.5.
      expect(
        MuscleRecoveryService.doseFactor(36, 12),
        MuscleRecoveryService.maxDoseFactor,
      );
    });
  });

  // ── resolveRecoveryWindow ───────────────────────────────────────────────────

  group('MuscleRecoveryService.resolveRecoveryWindow', () {
    test('returns null with no history', () {
      expect(
        MuscleRecoveryService.resolveRecoveryWindow('Chest', const []),
        isNull,
      );
    });

    test('first bout gets the base window', () {
      final t = DateTime(2026, 6, 1, 18);
      final window = MuscleRecoveryService.resolveRecoveryWindow('Chest', [
        MuscleDoseEvent(trainedAt: t, dose: 12),
      ]);
      expect(window, isNotNull);
      expect(window!.lastTrainedAt, t);
      expect(window.recoveryHours, 60);
    });

    test('bigger-than-usual dose stretches the window', () {
      final window = MuscleRecoveryService.resolveRecoveryWindow('Chest', [
        MuscleDoseEvent(trainedAt: DateTime(2026, 6), dose: 10),
        MuscleDoseEvent(trainedAt: DateTime(2026, 6, 8), dose: 10),
        // 15 sets against a 10-set average → factor 1.5.
        MuscleDoseEvent(trainedAt: DateTime(2026, 6, 16), dose: 15),
      ]);
      expect(window!.recoveryHours, closeTo(60 * 1.5, 0.01));
    });

    test('training a recovering muscle stacks the leftover fatigue', () {
      final first = DateTime(2026, 6, 1, 18);
      // Second chest session only 30h later — 30h of the 60h window left.
      final second = first.add(const Duration(hours: 30));
      final window = MuscleRecoveryService.resolveRecoveryWindow('Chest', [
        MuscleDoseEvent(trainedAt: first, dose: 12),
        MuscleDoseEvent(trainedAt: second, dose: 12),
      ]);
      // 60h (same dose as reference) + 0.5 × 30h leftover = 75h.
      expect(window!.recoveryHours, closeTo(75, 0.01));
      expect(window.lastTrainedAt, second);
    });

    test('stacked fatigue is capped at maxStackedFactor × base', () {
      final first = DateTime(2026, 6, 1, 18);
      final window = MuscleRecoveryService.resolveRecoveryWindow('Chest', [
        MuscleDoseEvent(trainedAt: first, dose: 10),
        // Blowout session one hour later: 1.5 factor + huge leftover.
        MuscleDoseEvent(
          trainedAt: first.add(const Duration(hours: 1)),
          dose: 30,
        ),
      ]);
      expect(
        window!.recoveryHours,
        lessThanOrEqualTo(60 * MuscleRecoveryService.maxStackedFactor),
      );
    });

    test('well-rested bouts do not stack', () {
      final first = DateTime(2026, 6, 1, 18);
      // 100h later — the 60h window fully elapsed.
      final second = first.add(const Duration(hours: 100));
      final window = MuscleRecoveryService.resolveRecoveryWindow('Chest', [
        MuscleDoseEvent(trainedAt: first, dose: 12),
        MuscleDoseEvent(trainedAt: second, dose: 12),
      ]);
      expect(window!.recoveryHours, closeTo(60, 0.01));
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
        recoveryPercent: 1,
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
