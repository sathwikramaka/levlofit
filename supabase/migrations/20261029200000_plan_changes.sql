-- B5 (audit 2026-10-28): plan changes Levlofit AI may propose: body goal (profiles.weight_goal), diet pace
-- (dietary_profiles.diet_pace) or training days a week (profiles.days_per_week). As with session_changes, the coach
-- only proposes: coach-chat checks each option with the plan engine before offering it, stores the proposal, and
-- only a confirm request that passes the checks again writes the setting and turns the row 'confirmed'. The app then
-- rebuilds the plan with generate-plan. The model never writes calorie, protein or any other target.
-- The app can read and delete (dismiss) its own rows but never write them.
create table public.plan_changes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  field text not null check (field in ('weight_goal', 'diet_pace', 'days_per_week')),
  value text not null,
  from_value text, -- the setting when proposed; a confirm is refused if it changed since
  status text not null default 'proposed' check (status in ('proposed', 'confirmed')),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  check ((status = 'confirmed') = (confirmed_at is not null)),
  check (field <> 'weight_goal' or value in ('cut', 'bulk', 'recomp', 'maintain', 'general')),
  check (field <> 'diet_pace' or value in ('easy', 'balanced', 'hard')),
  check (field <> 'days_per_week' or value in ('1', '2', '3', '4', '5', '6', '7'))
);
create index plan_changes_user on public.plan_changes (user_id, status);

alter table public.plan_changes enable row level security;
revoke all on public.plan_changes from anon, authenticated;
grant select, delete on public.plan_changes to authenticated;
create policy "own plan changes" on public.plan_changes for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
