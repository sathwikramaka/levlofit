import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/tools.dart';

void main() {
  test('BMI and WHO bands, as calculator.net shows them', () {
    expect(bmi(175, 70), closeTo(22.86, 0.01));
    for (final (v, band) in [
      (15.9, 'Severe thinness'), (16.0, 'Moderate thinness'), (17.0, 'Mild thinness'), (18.4, 'Mild thinness'),
      (18.5, 'Normal'), (24.9, 'Normal'), (25.0, 'Overweight'), (29.9, 'Overweight'),
      (30.0, 'Obese class I'), (35.0, 'Obese class II'), (40.0, 'Obese class III'),
    ]) {
      expect(bmiBandWho(v), band, reason: '$v');
    }
  });

  test("calculator.net's example: 180 cm, 65 kg, age 25", () {
    final r = bmiCheck(heightCm: 180, weightKg: 65, age: 25);
    expect(r.value, 20.1);
    expect(r.band, 'Normal');
    final w = healthyWeightKg(180);
    expect(w.min.toStringAsFixed(1), '59.9');
    expect(w.max.toStringAsFixed(1), '81.0');
    expect(bmiPrime(r.value!).toStringAsFixed(1), '0.8');
    expect(ponderalIndex(180, 65).toStringAsFixed(1), '11.1');
  });

  test('BMI is rounded to 1 dp before banding, as the plan engine does', () {
    for (final (h, w, shown, band) in [
      (170.0, 72.14, 25.0, 'Overweight'), // 24.962 rounds up
      (170.0, 72.0, 24.9, 'Normal'), // 24.913
      (170.0, 53.44, 18.5, 'Normal'), // 18.491 rounds up
    ]) {
      final r = bmiCheck(heightCm: h, weightKg: w);
      expect(r.value, shown, reason: '$h $w');
      expect(r.band, band, reason: '$h $w');
    }
  });

  test('BMI input checks match onboarding and the engine', () {
    expect(bmiCheck(heightCm: 119, weightKg: 60).errors.keys, ['height']);
    expect(bmiCheck(heightCm: 231, weightKg: 60).errors.keys, ['height']);
    expect(bmiCheck(heightCm: 170, weightKg: 29).errors.keys, ['weight']);
    expect(bmiCheck(heightCm: 170, weightKg: 251).errors.keys, ['weight']);
    expect(bmiCheck(heightCm: 120, weightKg: 30).errors, isEmpty);
    expect(bmiCheck(heightCm: 230, weightKg: 250).errors, isEmpty);
    // Not entered yet is not an error, and gives no value.
    final empty = bmiCheck(heightCm: null, weightKg: 60);
    expect(empty.errors, isEmpty);
    expect(empty.value, isNull);
    // An invalid field gives no value.
    expect(bmiCheck(heightCm: 50, weightKg: 60).value, isNull);
  });

  test('BMI under 20 gets no adult band', () {
    final teen = bmiCheck(heightCm: 160, weightKg: 50, age: 15);
    expect(teen.value, 19.5);
    expect(teen.band, isNull);
    expect(teen.note, contains('Under 20'));
    expect(bmiCheck(heightCm: 160, weightKg: 50, age: 19).band, isNull);
    expect(bmiCheck(heightCm: 160, weightKg: 50, age: 20).band, 'Normal');
    expect(bmiCheck(heightCm: 160, weightKg: 50, age: 150).errors.keys, ['age']);
  });

  test('imperial units convert exactly', () {
    expect(cmFromFeetInches(5, 7), closeTo(170.18, 1e-9));
    expect(kgFromPounds(150), closeTo(68.0389, 1e-4));
    expect(bmiCheck(heightCm: cmFromFeetInches(5, 7), weightKg: kgFromPounds(150)).value, 23.5);
    // Errors speak the units on screen, and every value they name is accepted.
    expect(bmiCheck(heightCm: cmFromFeetInches(3, 0), weightKg: 60, imperial: true).errors['height'], 'Enter a height between 4 ft 0 in and 7 ft 6 in');
    expect(bmiCheck(heightCm: 170, weightKg: kgFromPounds(60), imperial: true).errors['weight'], 'Enter a weight between 67 and 551 lb');
    expect(bmiCheck(heightCm: cmFromFeetInches(4, 0), weightKg: kgFromPounds(67), imperial: true).errors, isEmpty);
    expect(bmiCheck(heightCm: cmFromFeetInches(7, 6), weightKg: kgFromPounds(551), imperial: true).errors, isEmpty);
  });

  testWidgets('BMI screen explains a bad value instead of staying blank', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: BmiScreen(heightCm: 170, weightKg: 70, age: 30)));
    await tester.pumpAndSettle();
    expect(find.text('24.2'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '170'), '90');
    await tester.pumpAndSettle();
    expect(find.text('Enter a height between 120 and 230 cm'), findsOneWidget);
    expect(find.text('Enter your measurements'), findsOneWidget);
  });

  testWidgets('BMI unit switch carries the values across', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: BmiScreen(heightCm: 170, weightKg: 70)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ft in, lb'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    expect(find.widgetWithText(TextField, '7'), findsOneWidget);
    expect(find.widgetWithText(TextField, '154'), findsOneWidget);
    // 5 ft 7 in, 154 lb = 24.1 (rounding from the converted values, not the original 24.2).
    expect(find.text('24.1'), findsOneWidget);
  });
}
