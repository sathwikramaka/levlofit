# Levlofit patch to flutter_local_notifications 22.3.1

Upstream: https://pub.dev/packages/flutter_local_notifications (BSD-3-Clause, LICENSE in this folder; copyright
Michael Bui). Copied unchanged on 2026-10-22 except for the files listed here; examples and tests not copied.

## The defect

After a repeating (`matchDateTimeComponents`) notification is shown, `ScheduledNotificationReceiver` re-arms it via
`getNextFireDateMatchingDateTimeComponents`, which took today's date at the reminder's time and added days only
`while (nextFireDate.isBefore(now))`. When Android delivers the alarm early, "today at that time" is still ahead,
so the same occurrence was scheduled again and shown a second time.

Evidence (OnePlus 13, Android 16, release build, forced Doze, 2026-10-18): a daily 01:56:00 reminder (id 1000) was
delivered at 01:55:14 (`AlarmManager: sending alarm ... origWhen 1792268760000`), re-armed for 01:56:00 the same day,
deferred by Doze and delivered again at 02:00:14 (same notification id updated), and only then moved to the next day.
No upstream changelog entry up to 22.3.2 addresses this.

## The change

`FlutterLocalNotificationsPlugin.java`: the after-delivery path counts from just after the occurrence it delivered
(`afterDelivery = true`); first scheduling from Dart still counts from now. The computation is the package-private
static `nextMatchingFireDate(...)`, tested in `android/src/test/.../NextFireDateTest.java`.

## Upgrading

Before moving to a newer upstream version, check whether it fixes this; if not, re-apply the change and the test.
