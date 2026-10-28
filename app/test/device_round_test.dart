import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/session.dart';

// Found on the phone (local test app, 2026-10-28).
void main() {
  test('a single set reads "1 set", not "1 sets"', () {
    expect(doseFor('qXTaZnJ', 0, lighter: true), '1 set × 8–12 reps, 3 or more left in the tank');
    expect(doseFor('qXTaZnJ', 1), '2 sets × 8–12 reps, 1–3 left in the tank');
  });

  test('the preview strip shows the lighter dose the session will ask for under a medical hold', () {
    // MoveStrip passes its lighter flag to doseFor; the dashboard sets it for a lighter day or plan.medicalHold.
    expect(const MoveStrip(ids: ['qXTaZnJ'], level: 1, lighter: true).lighter, isTrue);
    expect(doseFor('qXTaZnJ', 1, lighter: true), contains('3 or more left in the tank'));
    expect(const MoveStrip(ids: ['qXTaZnJ'], level: 1).lighter, isFalse);
  });
}
