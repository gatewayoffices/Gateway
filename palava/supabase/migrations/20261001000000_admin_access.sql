-- Lets admins manage the catalog, settings and store from the admin panel.
--
-- Admins are listed in public.admins. Nobody can add themselves: rows are
-- added from the SQL Editor (see README, "Admin panel"). Every change the
-- panel makes is checked here by the database, not only by the panel.
--
-- How to apply: Supabase dashboard > SQL Editor > New query, paste this file,
-- click Run. Safe to run more than once.

create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table public.admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.is_admin() to anon, authenticated;

drop policy if exists "Admins see the admin list" on public.admins;
create policy "Admins see the admin list" on public.admins
  for select to authenticated using (public.is_admin());
grant select on public.admins to authenticated;

-- Admins can read and change everything in the catalog, including series
-- that are not published yet.
do $$
declare
  t text;
begin
  foreach t in array array[
    'series', 'episodes', 'episode_media', 'home_rows', 'coin_packs', 'passes'
  ] loop
    execute format(
      'drop policy if exists "Admins manage %1$s" on public.%1$I', t);
    execute format(
      'create policy "Admins manage %1$s" on public.%1$I for all '
      'to authenticated using (public.is_admin()) '
      'with check (public.is_admin())', t);
    execute format(
      'grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

drop policy if exists "Admins update settings" on public.app_settings;
create policy "Admins update settings" on public.app_settings
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
grant update on public.app_settings to authenticated;

-- Keep "last changed" times accurate without relying on the panel.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists series_touch on public.series;
create trigger series_touch before update on public.series
  for each row execute function public.touch_updated_at();
drop trigger if exists app_settings_touch on public.app_settings;
create trigger app_settings_touch before update on public.app_settings
  for each row execute function public.touch_updated_at();
