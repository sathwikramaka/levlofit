-- Plate builder settings (owner request 2026-10-27), both edited in Protocol:
-- diet_pace: how far a cut or bulk moves energy from maintenance (plan engine 3.1.0 ENERGY_FACTOR by pace);
-- cuisine_region: which regional staples the meal planner prefers (app/lib/diet_plan.dart regionStaples).
-- Defaults keep every existing plan and meal plan unchanged.
alter table public.dietary_profiles
  add column diet_pace text not null default 'balanced' check (diet_pace in ('easy', 'balanced', 'hard')),
  add column cuisine_region text not null default 'any' check (cuisine_region in ('any', 'north', 'south', 'east', 'west'));
