-- Rolling summary of a Levlofit AI chat (batch 2W). coach-chat writes it, as the signed-in person, once a thread holds
-- more than the 12 recent messages it sends back to the model; it goes to the model as "EARLIER IN THIS CHAT".
-- summary_upto: the newest message id the summary covers. Both go with the thread (delete, account deletion cascade).
alter table public.coach_threads
  add column summary text check (char_length(summary) between 1 and 800),
  add column summary_upto bigint check (summary_upto > 0);
grant update (summary, summary_upto) on public.coach_threads to authenticated;
