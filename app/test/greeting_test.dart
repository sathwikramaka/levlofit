import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';

void main() {
  test('greeting follows the local hour, never "morning" after midnight', () {
    for (final (hour, allowed) in [
      (1, ['Up late', 'Burning the midnight oil', 'Still up']),
      (4, ['Up late', 'Burning the midnight oil', 'Still up']),
      (5, ['Good morning', 'Morning', 'Rise and shine']),
      (11, ['Good morning', 'Morning', 'Rise and shine']),
      (12, ['Good afternoon', 'Afternoon', 'Hope the day is going well']),
      (17, ['Good evening', 'Evening', 'Welcome back']),
      (22, ['Winding down', 'Late evening', 'Almost bedtime']),
    ]) {
      for (var day = 1; day <= 3; day++) {
        expect(allowed, contains(greetingFor(DateTime(2026, 10, day, hour))), reason: 'hour $hour');
      }
    }
  });

  test('same greeting all day long within one time band', () {
    expect(greetingFor(DateTime(2026, 10, 27, 13, 0)), greetingFor(DateTime(2026, 10, 27, 16, 59)));
  });
}
