import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

void main() {
  test('several regions toggle in a fixed order; Mixed clears them; unknown values read as Mixed', () {
    var v = toggleRegion('any', 'south');
    expect(v, 'south');
    v = toggleRegion(v, 'north');
    expect(v, 'north,south'); // the database check expects this order
    expect(regionSelected(v, 'north') && regionSelected(v, 'south') && !regionSelected(v, 'any'), isTrue);
    expect(regionLabel(v), 'North Indian + South Indian');
    expect(toggleRegion(v, 'north'), 'south');
    expect(toggleRegion('south', 'south'), 'any');
    expect(toggleRegion(v, 'any'), 'any');
    expect(regionsOf('mars'), isEmpty);
    expect(regionLabel(null), 'Mixed');
  });
}
