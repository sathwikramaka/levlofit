-- Several regional cuisines at once (audit 12.14): cuisine_region holds 'any' or one or more of north, south, east,
-- west joined by commas in that order ("north,south"); app/lib/diet_plan.dart regionsOf reads it. Existing values
-- are all single regions or 'any', so they pass the new check unchanged.
alter table public.dietary_profiles drop constraint dietary_profiles_cuisine_region_check;
alter table public.dietary_profiles add constraint dietary_profiles_cuisine_region_check
  check (cuisine_region = 'any' or cuisine_region ~ '^(north|south|east|west)(,(north|south|east|west)){0,3}$');
