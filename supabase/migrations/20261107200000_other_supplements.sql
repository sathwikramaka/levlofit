-- Owner request 2026-11-07: supplements other than protein powder and creatine, in the person's own words. Listed on
-- their plate only: the plan engine does not read them, they are not counted in any target and not sent to the AI provider.
-- Own-row access through dietary_profiles' existing policies and grants; deleted with the account (cascade). Additive.
alter table public.dietary_profiles
  add column other_supplements text[] not null default '{}'
    check (cardinality(other_supplements) <= 10 and char_length(array_to_string(other_supplements, ',')) <= 500);

-- Rollback: alter table public.dietary_profiles drop column other_supplements;
