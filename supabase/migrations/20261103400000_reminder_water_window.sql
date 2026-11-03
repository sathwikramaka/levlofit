-- Roadmap Stage 5 (brief 5.5 quiet hours): the hours water reminders run, chosen by the person. Null keeps the old
-- fixed window (09:00 to 21:00). Water is the only reminder the app repeats on its own; workout, weigh-in and custom
-- reminders are at times the person picked. Additive; older app builds ignore the columns.
alter table public.reminder_prefs
  add column water_from smallint check (water_from between 5 and 12),
  add column water_to smallint check (water_to between 15 and 23),
  add constraint reminder_prefs_water_window check ((water_from is null) = (water_to is null));
grant insert (water_from, water_to), update (water_from, water_to) on public.reminder_prefs to authenticated;

-- Rollback: alter table public.reminder_prefs drop constraint reminder_prefs_water_window, drop column water_from, drop column water_to;
