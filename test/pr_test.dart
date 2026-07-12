import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';

void main() {
  test('evaluatePr scores weight PRs first, then estimated-1RM PRs', () {
    // Heavier than ever lifted → weight PR (even if 1RM also beaten).
    expect(
      evaluatePr(weight: 105, reps: 1, baselineWeight: 100, baselineOneRm: 120),
      PrKind.weight,
    );
    // Same weight, more reps → Epley 1RM PR: 100 × (1 + 8/30) ≈ 126.7 > 120.
    expect(
      evaluatePr(weight: 100, reps: 8, baselineWeight: 100, baselineOneRm: 120),
      PrKind.oneRm,
    );
    // Below both records → nothing.
    expect(
      evaluatePr(weight: 80, reps: 3, baselineWeight: 100, baselineOneRm: 120),
      isNull,
    );
    // Matching a record is not a new one (strictly greater).
    expect(
      evaluatePr(
        weight: 100,
        reps: 6,
        baselineWeight: 100,
        baselineOneRm: 120,
      ),
      isNull,
    );
  });
}
