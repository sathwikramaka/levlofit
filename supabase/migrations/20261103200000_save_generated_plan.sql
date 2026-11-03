-- Roadmap audit 2026-11-03, defect 2: generate-plan stored the plan, then opened the dashboard gate
-- (profiles.onboarding_complete) in a second call. A failure between the two answered 500 with the plan already saved,
-- and the app's retry stored a second, identical plan. save_generated_plan does both in one transaction and is
-- idempotent: the same input and engine version saved again within two minutes returns the plan already stored.
-- The profile row lock serialises two requests from the same person (double tap, retry after a timeout).
-- Called only by generate-plan with the service role (the gate column is not writable by users).
create or replace function public.save_generated_plan(p_user uuid, p_engine text, p_input jsonb, p_plan jsonb)
returns table (id uuid, reused boolean)
language plpgsql security invoker set search_path = ''
as $$
declare
  existing uuid;
begin
  perform 1 from public.profiles p where p.id = p_user for update;
  if not found then
    raise exception 'no profile' using errcode = 'P0002';
  end if;
  select g.id into existing from public.generated_plans g
    where g.user_id = p_user and g.engine_version = p_engine and g.input = p_input
      and g.created_at > now() - interval '2 minutes'
    order by g.created_at desc limit 1;
  if existing is null then
    insert into public.generated_plans (user_id, engine_version, input, plan)
      values (p_user, p_engine, p_input, p_plan) returning generated_plans.id into existing;
    reused := false;
  else
    reused := true;
  end if;
  update public.profiles set onboarding_complete = true where profiles.id = p_user;
  id := existing;
  return next;
end;
$$;
revoke execute on function public.save_generated_plan(uuid, text, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.save_generated_plan(uuid, text, jsonb, jsonb) to service_role;

-- Rollback: drop function public.save_generated_plan(uuid, text, jsonb, jsonb); and redeploy the previous generate-plan.
