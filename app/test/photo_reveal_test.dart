import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';

void main() {
  test('photo milestones: 4, 8 and 12 weeks apart, the highest reached; none before 4 weeks', () {
    final first = DateTime(2026, 1, 1);
    expect(photoMilestone(first, first.add(const Duration(days: 27))), isNull);
    expect(photoMilestone(first, first.add(const Duration(days: 28))), 4);
    expect(photoMilestone(first, first.add(const Duration(days: 60))), 8);
    expect(photoMilestone(first, first.add(const Duration(days: 84))), 12);
    expect(photoMilestone(first, first.add(const Duration(days: 400))), 12);
  });
}
