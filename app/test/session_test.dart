import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/session.dart';

void main() {
  test('double progression: same weight until every set hits 12, then add the smallest step', () {
    expect(nextStep(const []), startsWith('First time'));
    expect(nextStep(const [(reps: 10, kg: 20.0), (reps: 9, kg: 20.0)]), contains('Same weight today'));
    expect(nextStep(const [(reps: 12, kg: 20.0), (reps: 12, kg: 20.0)]), contains('add the smallest weight step'));
    expect(nextStep(const [(reps: 12, kg: null), (reps: 13, kg: null)]), contains('bodyweight'));
    expect(isLift('qXTaZnJ'), isTrue); // barbell squat
    expect(isLift('iny3m5y'), isFalse); // dead bug, a core hold
    expect(isLift('oLrKqDH'), isFalse); // run
  });
}
