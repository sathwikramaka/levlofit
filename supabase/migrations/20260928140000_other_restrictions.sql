-- Free-text allergies/intolerances the fixed list does not cover (e.g. sesame, mustard, kiwi).
alter table public.dietary_profiles
  add column other_restrictions text[] not null default '{}'
    check (cardinality(other_restrictions) <= 10);
