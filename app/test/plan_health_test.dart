import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';

void main() {
  final plan = {'medicalHold': false, 'review': [{'level': 'info', 'title': 'x'}]};

  test('same health answers keep the plan as built', () {
    expect(planForHealth(plan, {'healthFlags': ['dizziness']}, ['dizziness']), same(plan));
    expect(planForHealth(plan, {}, []), same(plan)); // older plans store no flags
    expect(planForHealth(plan, {}, null), same(plan));
  });

  test('a new medical flag after the plan was built puts it on hold with a stop note', () {
    final p = planForHealth(plan, {'healthFlags': <String>[]}, ['chest_pain']);
    expect(p['medicalHold'], isTrue);
    expect((p['review'] as List).first['level'], 'stop');
    expect((p['review'] as List).length, 2);
  });

  test('pregnancy alone asks for a rebuild without the medical hold', () {
    final p = planForHealth(plan, {}, ['pregnancy']);
    expect(p['medicalHold'], isFalse);
    expect((p['review'] as List).first['title'], 'Your health answers changed');
  });
}
