-- Account deletion coverage (remediation 2026-11-02). delete-account clears the progress-photos folder, then deletes
-- the auth user and relies on on-delete-cascade for every row. These checks fail when a new table keeps user data
-- without that cascade, or when the photo bucket stops being private. Run locally: supabase test db.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- Every foreign key from public to auth.users removes the row with the user.
select is(
  (select coalesce(string_agg(c.conrelid::regclass::text, ', '), '')
     from pg_constraint c
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
      and c.connamespace = 'public'::regnamespace and c.confdeltype <> 'c'),
  '', 'every public foreign key to auth.users cascades on delete');

-- Every public table with a user_id column links it to auth.users (or to profiles, which cascades in turn).
select is(
  (select coalesce(string_agg(t.table_name, ', '), '')
     from information_schema.columns t
    where t.table_schema = 'public' and t.column_name = 'user_id'
      and not exists (
        select 1 from pg_constraint c
         where c.contype = 'f' and c.conrelid = format('public.%I', t.table_name)::regclass
           and c.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass) and c.confdeltype = 'c')),
  '', 'every public user_id column cascades from the user');

-- The only bucket holding user files is private.
select is((select array_agg(id::text order by id) from storage.buckets where public), null, 'no storage bucket is public');

-- A deleted user leaves no rows behind in the tables the app writes most.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000de01', 'gone@test.local');
insert into public.profiles (id) values ('00000000-0000-0000-0000-00000000de01') on conflict do nothing;
insert into public.body_metrics (user_id, weight_kg) values ('00000000-0000-0000-0000-00000000de01', 70);
delete from auth.users where id = '00000000-0000-0000-0000-00000000de01';
select is(
  (select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-00000000de01')
  + (select count(*)::int from public.body_metrics where user_id = '00000000-0000-0000-0000-00000000de01'),
  0, 'profile and body metrics go with the user');

select * from finish();
rollback;
