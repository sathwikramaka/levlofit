import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';

// B2: Build my plate's conditions and shake scoops come from the account; a phone's pre-B2 copy is used (and moved)
// only while the account has none.
// Records compare their List field by identity, so compare field by field.
void _is(PlateChoices p, List<String> conditions, int scoops, bool fromPhone, {String? reason}) {
  expect(p.conditions, conditions, reason: reason);
  expect(p.scoops, scoops, reason: reason);
  expect(p.fromPhone, fromPhone, reason: reason);
}

void main() {
  test('the account wins when it has any choice', () {
    final p = plateChoices({'health_conditions': ['kidney'], 'whey_scoops': 1}, localConditions: ['diabetes'], localScoops: 3);
    _is(p, ['kidney'], 1, false);
    expect(plateChoices({'health_conditions': <String>[], 'whey_scoops': 2}, localConditions: ['ibs']).fromPhone, isFalse);
  });

  test('pre-B2 phone choices are used and flagged for moving while the account is empty', () {
    final p = plateChoices({'health_conditions': <String>[], 'whey_scoops': 0}, localConditions: ['pregnancy', 'mystery'], localScoops: 5);
    _is(p, ['pregnancy'], 3, true, reason: 'unknown keys dropped, scoops kept to 0-3');
  });

  test('nothing anywhere, or a row from before the migration: no conditions, no shakes, nothing to move', () {
    _is(plateChoices(const {}), [], 0, false);
    expect(plateChoices({'diet_type': 'vegan'}, localConditions: const [], localScoops: 0).fromPhone, isFalse);
  });

  test('only kidney disease and pregnancy change the plan itself', () {
    expect(planConditions, {'kidney', 'pregnancy'});
  });
}
