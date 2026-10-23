// Daily goal and streak. Everything is derived from what is already logged (sessions, water, habit ticks), so
// a reward cannot be earned twice or farmed by ticking and unticking: there is no points ledger to inflate. The
// only stored state is the user's chosen tasks and the last day the celebration played on this device.
//
// Rest days count: the "train" task is done on a planned rest day (see _habitList), so resting as planned
// never breaks a streak, and nothing rewards training more than the plan asks or eating less.

/// Tasks counted by default: train or rest as planned, and drink the water target.
const defaultDailyTasks = {'train', 'water'};

/// Streak milestones that get a bigger message.
const streakMilestones = [3, 7, 14, 30, 60, 100];

/// Whether every chosen task was done on [day]. Unknown task ids (an older app's habit) are ignored; an empty
/// choice never counts as complete.
bool dayComplete(Map<String, bool Function(DateTime)> tasks, Set<String> chosen, DateTime day) {
  final known = chosen.where(tasks.containsKey).toList();
  return known.isNotEmpty && known.every((id) => tasks[id]!(day));
}

/// Complete days in a row up to today. An unfinished today does not break it (the day is not over), it just
/// does not count yet. Capped at [window] days, the history the dashboard loads.
int dailyStreak(Map<String, bool Function(DateTime)> tasks, Set<String> chosen, DateTime today, {int window = 30}) {
  final day = DateTime(today.year, today.month, today.day);
  var n = dayComplete(tasks, chosen, day) ? 1 : 0;
  for (var i = 1; i < window; i++) {
    // Calendar days, not 24-hour steps, so a clock change cannot skip or repeat a day.
    if (!dayComplete(tasks, chosen, DateTime(day.year, day.month, day.day - i))) break;
    n++;
  }
  return n;
}

/// The celebration plays once per day: today complete and not already celebrated today.
bool shouldCelebrate({required bool todayComplete, required String? lastCelebrated, required DateTime today}) =>
    todayComplete && lastCelebrated != dayKey(today);

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The headline for a finished day.
String celebrationLine(int streak) {
  if (streakMilestones.contains(streak)) return '$streak days in a row. That is a habit now.';
  if (streak > 1) return 'Day $streak in a row. Keep it going tomorrow.';
  return 'Day 1 of a new streak. Come back tomorrow to make it two.';
}
