import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/progression.dart';

Map<String, dynamic> r(String id, String day, int reps, num? kg) => {'exercise_id': id, 'performed_on': day, 'reps': reps, 'kg': kg};

void main() {
  test('best set per day, first versus latest, most improved first; single-day lifts left out', () {
    final p = liftProgress([
      r('squat', '2026-09-01', 8, 40), r('squat', '2026-09-01', 6, 40), r('squat', '2026-10-01', 8, 50), r('squat', '2026-10-01', 5, 30),
      r('push_up', '2026-09-02', 10, null), r('push_up', '2026-10-02', 12, null),
      r('row', '2026-10-03', 8, 20),
    ]);
    expect(p.map((x) => x.id), ['squat', 'push_up']);
    expect(setLabel(p.first.first), '40 kg x 8');
    expect(setLabel(p.first.latest), '50 kg x 8');
    expect(setLabel(p.last.latest), '12 reps');
    expect(setLabel((reps: 5, kg: 22.5)), '22.5 kg x 5');
  });
}
