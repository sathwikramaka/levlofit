-- One primary goal + up to five optional extras (plan engine 1.1.0, MAX_GOALS = 6).
alter table public.user_goals drop constraint user_goals_priority_check;
alter table public.user_goals add constraint user_goals_priority_check check (priority between 1 and 6);
