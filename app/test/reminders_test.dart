import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/reminders.dart';

void main() {
  test('reminder slots follow the settings', () {
    const sessions = {1: 'Strength', 3: 'Strength', 5: 'Running'};
    final all = slotsFor((enabled: true, workout: const TimeOfDay(hour: 18, minute: 30), waterEveryH: 3, weighInWeekday: 7), sessions);
    // 3 training days, water at 9, 12, 15, 18, 21, one weigh-in.
    expect(all.where((s) => s.id >= 100 && s.id < 200).map((s) => s.weekday), [1, 3, 5]);
    expect(all.where((s) => s.id >= 200 && s.id < 300).map((s) => s.hour), [9, 12, 15, 18, 21]);
    expect(all.singleWhere((s) => s.id == 300).weekday, 7);
    expect(all.firstWhere((s) => s.weekday == 5).body, contains('Running'));
    expect(all.map((s) => s.id).toSet().length, all.length); // ids never collide
    expect(slotsFor((enabled: false, workout: const TimeOfDay(hour: 7, minute: 0), waterEveryH: 1, weighInWeekday: 1), sessions), isEmpty);
    expect(slotsFor((enabled: true, workout: null, waterEveryH: null, weighInWeekday: null), sessions), isEmpty);
  });
}
