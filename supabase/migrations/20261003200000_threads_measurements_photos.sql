-- 1. Levlofit AI conversations, like chats in ChatGPT: many threads per user, one memory (coach_notes) across them.
create table public.coach_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null default 'New chat' check (char_length(title) between 1 and 80),
  updated_at timestamptz not null default now()
);
create index coach_threads_user_time on public.coach_threads (user_id, updated_at desc);
alter table public.coach_threads enable row level security;
revoke all on public.coach_threads from anon, authenticated;
grant select, delete on public.coach_threads to authenticated;
grant insert (title, updated_at), update (title, updated_at) on public.coach_threads to authenticated;
create policy "own threads" on public.coach_threads for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter table public.coach_messages add column thread_id uuid references public.coach_threads (id) on delete cascade;
-- Existing history becomes each user's first thread.
insert into public.coach_threads (user_id, title, updated_at)
  select user_id, 'Earlier chat', max(created_at) from public.coach_messages group by user_id;
update public.coach_messages m set thread_id = t.id from public.coach_threads t where t.user_id = m.user_id;
alter table public.coach_messages alter column thread_id set not null;
create index coach_messages_thread on public.coach_messages (thread_id, id);
grant insert (thread_id) on public.coach_messages to authenticated;
-- A message may only go into one of the caller's own threads.
drop policy "own messages" on public.coach_messages;
create policy "own messages" on public.coach_messages for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.coach_threads t where t.id = thread_id and t.user_id = (select auth.uid()))
  );

-- 2. Tape measurements and body fat next to weight (one row per day).
alter table public.body_metrics
  add column body_fat_pct numeric(4, 1) check (body_fat_pct between 3 and 70),
  add column neck_cm numeric(5, 1) check (neck_cm between 20 and 80),
  add column chest_cm numeric(5, 1) check (chest_cm between 50 and 200),
  add column hips_cm numeric(5, 1) check (hips_cm between 50 and 200),
  add column arm_cm numeric(5, 1) check (arm_cm between 15 and 70),
  add column thigh_cm numeric(5, 1) check (thigh_cm between 25 and 110);

-- 3. Progress photos: private bucket, files under <user id>/..., rows point at them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('progress-photos', 'progress-photos', false, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "own progress photos" on storage.objects for all to authenticated
  using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create table public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  taken_on date not null default current_date,
  path text not null check (path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]+$'),
  created_at timestamptz not null default now()
);
create index progress_photos_user_day on public.progress_photos (user_id, taken_on desc);
alter table public.progress_photos enable row level security;
revoke all on public.progress_photos from anon, authenticated;
grant select, delete on public.progress_photos to authenticated;
grant insert (taken_on, path) on public.progress_photos to authenticated;
create policy "own photo rows" on public.progress_photos for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and split_part(path, '/', 1) = (select auth.uid())::text);
