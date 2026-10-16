-- Getting ready for Google Play: viewers can delete their account from the
-- app, and the privacy policy, terms and help contact are set in the admin
-- panel instead of being written into the app.
--
-- How to apply: Supabase dashboard > SQL Editor > New query, paste this file,
-- click Run. Safe to run more than once.

alter table public.app_settings
  add column if not exists privacy_url text,
  add column if not exists terms_url text,
  add column if not exists support_email text;

-- Deletes the signed-in viewer's account and everything tied to it (profile,
-- wallet, unlocks, passes, purchases, history, lists). Cannot be undone.
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sign in first' using errcode = '28000';
  end if;
  -- Admins are removed from the panel by hand, never by accident.
  if exists (select 1 from public.admins where user_id = v_user) then
    raise exception 'Admin accounts cannot be deleted from the app'
      using errcode = 'P0001';
  end if;
  delete from auth.users where id = v_user;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
