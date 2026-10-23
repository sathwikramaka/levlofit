package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.assertEquals;

import com.dexterous.flutterlocalnotifications.models.DateTimeComponents;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import org.junit.Test;

/** Levlofit patch: a reminder delivered early must not be re-armed for the same occurrence. */
public class NextFireDateTest {
  private static final ZoneId IST = ZoneId.of("Asia/Kolkata");
  private static final ZonedDateTime DUE = ZonedDateTime.of(2026, 10, 18, 1, 56, 0, 0, IST);

  @Test
  public void earlyDeliveryOfADailyReminderMovesToTheNextDay() {
    // Seen on a OnePlus 13 in Doze: the 01:56 alarm was delivered at 01:55:14, re-armed for 01:56 the same day,
    // and shown a second time at 02:00:14.
    ZonedDateTime early = ZonedDateTime.of(2026, 10, 18, 1, 55, 14, 0, IST);
    assertEquals("2026-10-19T01:56:00",
        FlutterLocalNotificationsPlugin.nextMatchingFireDate(DUE, early, DateTimeComponents.Time, true));
  }

  @Test
  public void onTimeAndLateDeliveriesMoveToTheNextDay() {
    assertEquals("2026-10-19T01:56:00",
        FlutterLocalNotificationsPlugin.nextMatchingFireDate(DUE, DUE, DateTimeComponents.Time, true));
    assertEquals("2026-10-19T01:56:00",
        FlutterLocalNotificationsPlugin.nextMatchingFireDate(DUE, DUE.plusMinutes(4), DateTimeComponents.Time, true));
  }

  @Test
  public void earlyDeliveryOfAWeeklyReminderMovesToTheNextWeek() {
    ZonedDateTime early = DUE.minusSeconds(46);
    assertEquals("2026-10-25T01:56:00",
        FlutterLocalNotificationsPlugin.nextMatchingFireDate(DUE, early, DateTimeComponents.DayOfWeekAndTime, true));
  }

  @Test
  public void firstSchedulingStillCountsFromNow() {
    // zonedSchedule from Dart (not a delivery): a time later today is still today.
    ZonedDateTime before = DUE.minusHours(2);
    assertEquals("2026-10-18T01:56:00",
        FlutterLocalNotificationsPlugin.nextMatchingFireDate(DUE, before, DateTimeComponents.Time, false));
  }
}
