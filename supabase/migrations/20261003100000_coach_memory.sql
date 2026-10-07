-- Levlofit AI remembers each user: the conversation itself, plus short notes the assistant keeps
-- about preferences and constraints ("trains early mornings", "dislikes paneer"). Own rows only.
create table public.coach_messages (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index coach_messages_user_id on public.coach_messages (user_id, id desc);

create table public.coach_notes (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  notes text not null default '' check (char_length(notes) <= 2000),
  updated_at timestamptz not null default now()
);

alter table public.coach_messages enable row level security;
alter table public.coach_notes enable row level security;

revoke all on public.coach_messages, public.coach_notes from anon, authenticated;
grant select, delete on public.coach_messages to authenticated;
grant insert (role, content) on public.coach_messages to authenticated;
grant select, delete on public.coach_notes to authenticated;
grant insert (notes, updated_at), update (notes, updated_at) on public.coach_notes to authenticated;

create policy "own messages" on public.coach_messages for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own notes" on public.coach_notes for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
