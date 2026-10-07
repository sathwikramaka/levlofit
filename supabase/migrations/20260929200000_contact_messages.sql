-- The waitlist was dropped by request (it was empty); the website contact form replaces it.
drop table public.waitlist;

-- Website contact form. Visitors can send a message; nobody but the service role can read them.
create table public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  email text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  message text not null check (char_length(message) between 10 and 2000),
  utm jsonb not null default '{}' check (pg_column_size(utm) <= 2048),
  created_at timestamptz not null default now()
);
alter table public.contact_messages enable row level security;
revoke all on public.contact_messages from anon, authenticated;
grant insert (email, message, utm) on public.contact_messages to anon, authenticated;
create policy "anyone can write to us" on public.contact_messages for insert to anon, authenticated with check (true);
