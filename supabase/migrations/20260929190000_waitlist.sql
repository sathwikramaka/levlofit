-- Website waitlist. Visitors can add their email; nobody but the service role can read the list.
create table public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  utm jsonb not null default '{}' check (pg_column_size(utm) <= 2048),
  created_at timestamptz not null default now()
);
alter table public.waitlist enable row level security;
revoke all on public.waitlist from anon, authenticated;
grant insert (email, utm) on public.waitlist to anon, authenticated;
create policy "anyone can join" on public.waitlist for insert to anon, authenticated with check (true);
