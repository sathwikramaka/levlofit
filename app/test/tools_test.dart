import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/tools.dart';

void main() {
  test('BMI and Indian bands', () {
    expect(bmi(175, 70), closeTo(22.86, 0.01));
    expect(bmiBandIndia(17.9), 'Underweight');
    expect(bmiBandIndia(22.9), 'Normal');
    expect(bmiBandIndia(23), 'Overweight');
    expect(bmiBandIndia(25), 'Obese');
  });

  test('US Navy body fat', () {
    // Male 178 cm, neck 38, waist 86: about 17.2 % (worked by hand).
    expect(navyBodyFat(male: true, heightCm: 178, neckCm: 38, waistCm: 86), closeTo(17.2, 0.05));
    // Female 165 cm, neck 33, waist 72, hips 98: about 26.9 %.
    expect(navyBodyFat(male: false, heightCm: 165, neckCm: 33, waistCm: 72, hipCm: 98), closeTo(26.9, 0.05));
    expect(navyBodyFat(male: true, heightCm: 178, neckCm: 90, waistCm: 80), isNull);
    expect(navyBodyFat(male: false, heightCm: 165, neckCm: 33, waistCm: 72), isNull);
    expect(bodyFatBand(17.2, male: true), 'Fitness');
    expect(bodyFatBand(26.9, male: false), 'Average');
  });
}
