-- =====================================================================
--  Studio Operations Hub — Supabase schema
--  Run this once in:  Supabase Dashboard → SQL Editor → New query → Run
-- =====================================================================

-- 1) Shared key/value store. All team data (tasks, daily logs, weekly
--    notes, resources, op name) lives here as JSON, keyed by name.
create table if not exists public.kv (
  key        text primary key,
  value      jsonb,
  updated_at timestamptz default now()
);

-- 2) Row Level Security on.
alter table public.kv enable row level security;

-- 3) Access policies.
--    This is an INTERNAL team tool reached with the public anon key, so
--    these allow full read/write to anyone holding the key + project URL.
--    See the SECURITY note at the bottom before putting client-sensitive
--    data in here. To lock it down later, replace these with auth-based
--    policies (using auth.uid()).
drop policy if exists kv_read   on public.kv;
drop policy if exists kv_insert on public.kv;
drop policy if exists kv_update on public.kv;
drop policy if exists kv_delete on public.kv;
create policy kv_read   on public.kv for select using (true);
create policy kv_insert on public.kv for insert with check (true);
create policy kv_update on public.kv for update using (true) with check (true);
create policy kv_delete on public.kv for delete using (true);

-- 4) Explicit grants.
--    Projects created after 2026-05-30 require explicit grants for the
--    auto-generated REST API (PostgREST) to see the table. Without this
--    the app reads back empty.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.kv to anon, authenticated;

-- 5) Realtime — pushes live changes to every open browser.
alter publication supabase_realtime add table public.kv;

-- 6) Storage bucket for progress screenshots (public read URLs).
insert into storage.buckets (id, name, public)
values ('screenshots', 'screenshots', true)
on conflict (id) do nothing;

-- 7) Storage policies — allow anon upload / read / delete in that bucket.
drop policy if exists shots_read   on storage.objects;
drop policy if exists shots_insert on storage.objects;
drop policy if exists shots_delete on storage.objects;
create policy shots_read   on storage.objects for select to anon using (bucket_id = 'screenshots');
create policy shots_insert on storage.objects for insert to anon with check (bucket_id = 'screenshots');
create policy shots_delete on storage.objects for delete to anon using (bucket_id = 'screenshots');

-- =====================================================================
--  SECURITY (read this, blunt):
--  The anon key is shipped in a static page, so it is effectively public.
--  Anyone with your Pages URL + the key can read/write this table. For a
--  2-3 person internal ops board that is the same trust model as a shared
--  link. If the data is client-confidential, add Supabase Auth (email
--  magic links) and rewrite the policies above to check auth.uid().
--
--  BACKUPS: the free plan has none. Set up the GitHub Actions backup
--  (free since Apr 2026) once you care about the data.
-- =====================================================================
