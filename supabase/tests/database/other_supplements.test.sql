-- pgTAP tests for 20261107200000_other_supplements.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a7', 's1@test.local'),
  ('00000000-0000-0000-0000-0000000000a8', 's2@test.local');
insert into public.dietary_profiles (user_id, diet_type) values
  ('00000000-0000-0000-0000-0000000000a7', 'vegetarian'), ('00000000-0000-0000-0000-0000000000a8', 'vegetarian');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}', true);
select lives_ok($$ update public.dietary_profiles set other_supplements = array['Vitamin D', 'Fish oil'] $$, 'the owner saves their own supplements');
select is((select other_supplements from public.dietary_profiles where user_id = '00000000-0000-0000-0000-0000000000a7'), array['Vitamin D', 'Fish oil'], 'saved as typed');
select throws_ok($$ update public.dietary_profiles set other_supplements = array['a','b','c','d','e','f','g','h','i','j','k'] $$, '23514', null, 'more than 10 is refused');
select throws_ok($$ update public.dietary_profiles set other_supplements = array[repeat('x', 501)] $$, '23514', null, 'a very long text is refused');
reset role;
select is((select other_supplements from public.dietary_profiles where user_id = '00000000-0000-0000-0000-0000000000a8'), '{}'::text[], 'another person is untouched');

select * from finish();
rollback;
