import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/rewards.dart';

void main() {
  final today = DateTime(2026, 10, 14);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  // train: done today and 4 days back; water: done 1 to 6 days back (not yet today).
  final tasks = <String, bool Function(DateTime)>{
    'train': (d) => !d.isBefore(ago(4)),
    'water': (d) => d.isBefore(today) && !d.isBefore(ago(6)),
    'sleep': (d) => true,
  };

  test('a day is complete only when every chosen task is done', () {
    expect(dayComplete(tasks, {'train', 'water'}, ago(1)), isTrue);
    expect(dayComplete(tasks, {'train', 'water'}, today), isFalse); // water not done yet
    expect(dayComplete(tasks, {'train'}, today), isTrue);
    expect(dayComplete(tasks, {}, today), isFalse); // nothing chosen never counts
    expect(dayComplete(tasks, {'gone'}, today), isFalse); // unknown task ids are ignored
    expect(dayComplete(tasks, {'train', 'gone'}, today), isTrue);
  });

  test('streak: an unfinished today does not break it, a missed day does', () {
    expect(dailyStreak(tasks, {'train', 'water'}, today), 4); // 1 to 4 days back; today pending
    expect(dailyStreak(tasks, {'train'}, today), 5); // today and 4 back
    expect(dailyStreak(tasks, {'water'}, today), 6);
    expect(dailyStreak(tasks, {'sleep'}, today), 30); // capped at the loaded window
    expect(dailyStreak(tasks, {'sleep'}, today, window: 7), 7);
  });

  test('streak walks calendar days across a month boundary', () {
    final first = DateTime(2026, 11, 1);
    final t = <String, bool Function(DateTime)>{'x': (d) => !d.isBefore(DateTime(2026, 10, 30))};
    expect(dailyStreak(t, {'x'}, first), 3); // Oct 30, Oct 31, Nov 1
  });

  test('celebration plays once per day', () {
    expect(shouldCelebrate(todayComplete: true, lastCelebrated: null, today: today), isTrue);
    expect(shouldCelebrate(todayComplete: true, lastCelebrated: '2026-10-14', today: today), isFalse);
    expect(shouldCelebrate(todayComplete: true, lastCelebrated: '2026-10-13', today: today), isTrue);
    expect(shouldCelebrate(todayComplete: false, lastCelebrated: null, today: today), isFalse);
    expect(dayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });

  test('milestone lines', () {
    expect(celebrationLine(7), contains('7 days in a row'));
    expect(celebrationLine(5), contains('Day 5'));
    expect(celebrationLine(1), contains('Day 1'));
  });
}
