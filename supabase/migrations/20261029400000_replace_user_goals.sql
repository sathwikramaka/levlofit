-- B7 (audit F3): replacing a person's goals was a delete then an insert from the app, so a failed insert left them with
-- no goals and generate-plan refused to plan. replace_user_goals does both in one transaction: either the new list is
-- stored or the old one stays. Security invoker, so row level security ("own goals") and the table's checks
-- (catalogue goal, experience, priority 1 to 6, no duplicates) still apply as the calling user.
-- p_goals: [{ "goal": <goal_catalog id>, "experience": none|beginner|intermediate|advanced }, ...], main goal first.
create or replace function public.replace_user_goals(p_goals jsonb) returns void
language plpgsql security invoker set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if jsonb_typeof(p_goals) is distinct from 'array' or jsonb_array_length(p_goals) not between 1 and 6 then
    raise exception 'goals must list 1 to 6 goals' using errcode = '22023';
  end if;
  delete from public.user_goals where user_id = uid;
  insert into public.user_goals (user_id, goal, experience, priority)
    select uid, g.value ->> 'goal', g.value ->> 'experience', g.ordinality::smallint
    from jsonb_array_elements(p_goals) with ordinality as g(value, ordinality);
end;
$$;
revoke execute on function public.replace_user_goals(jsonb) from public, anon;
grant execute on function public.replace_user_goals(jsonb) to authenticated;
