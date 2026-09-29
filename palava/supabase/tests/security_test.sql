-- Checks the security rules and coin functions. Run with psql against a
-- database that has supabase_shim.sql, the migration and seed.sql applied
-- (see run_tests.sh). Any failed check stops the script with an error.
\set ON_ERROR_STOP on
\set QUIET on
\o /dev/null

create function pg_temp.check(ok boolean, what text) returns void
language plpgsql as $$
begin
  if not coalesce(ok, false) then
    raise exception 'FAILED: %', what;
  end if;
  raise notice 'ok: %', what;
end;
$$;

-- Two viewers sign up.
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-00000000000a', '231770000001'),
  ('00000000-0000-0000-0000-00000000000b', '231770000002');

-- --- Guests -----------------------------------------------------------------
begin;
set local role anon;

select pg_temp.check(
  (select count(*) from public.series_catalog) = 8,
  'guests see the 8 published series');
select pg_temp.check(
  (select episode_count from public.series_catalog where id = 'bride-price') = 40,
  'episode count comes from the episodes table');
select pg_temp.check(
  (select free_episodes from public.series_catalog where id = 'bride-price') = 8,
  'free episode count comes from settings');
select pg_temp.check(
  (select count(*) from public.episode_media m
   join public.episodes e on e.id = m.episode_id
   where e.series_id = 'bride-price') = 8,
  'guests get video links for the 8 free episodes only');
select pg_temp.check(
  (select count(*) from public.coin_packs) = 4 and
  (select count(*) from public.passes) = 2 and
  (select count(*) from public.home_rows) = 3,
  'guests see coin packs, passes and home rows');
rollback;

begin;
set local role anon;
do $$
begin
  if (select count(*) from public.wallets) > 0 then
    raise exception 'FAILED: guests can see wallets';
  end if;
  raise notice 'ok: guests see no wallets';
exception when insufficient_privilege then
  raise notice 'ok: guests see no wallets';
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  perform public.unlock_episode_with_coins('bride-price', 9);
  raise exception 'FAILED: guests must not call unlock';
exception when insufficient_privilege then
  raise notice 'ok: guests cannot call the unlock function';
end $$;
rollback;

-- --- A new viewer -----------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';

select pg_temp.check(
  (select balance from public.wallets) = 45,
  'new viewers get 45 welcome coins');
select pg_temp.check(
  (select count(*) from public.wallets) = 1,
  'viewers see only their own wallet');
select pg_temp.check(
  (select phone from public.profiles) = '231770000001',
  'a profile is created with the phone number');
select pg_temp.check(
  (select amount from public.wallet_transactions where reason = 'welcome') = 45,
  'the welcome coins are recorded');

do $$
begin
  update public.wallets set balance = 99999;
exception when insufficient_privilege then
  null; -- refused outright: also fine
end $$;
select pg_temp.check(
  (select balance from public.wallets) = 45,
  'viewers cannot change their own balance');
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$
begin
  insert into public.episode_unlocks (user_id, episode_id, method)
  select '00000000-0000-0000-0000-00000000000a', id, 'coins'
  from public.episodes where series_id = 'bride-price' and number = 20;
  raise exception 'FAILED: direct unlock insert was allowed';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot unlock episodes without paying';
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$
begin
  update public.profiles set phone = '231779999999';
  raise exception 'FAILED: phone number could be changed';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot change their phone number directly';
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'Hawa', language = 'fr';
select pg_temp.check(
  (select display_name from public.profiles) = 'Hawa',
  'viewers can change their name and language');
commit;

-- --- Unlocking with coins ---------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';

select pg_temp.check(
  public.unlock_episode_with_coins('bride-price', 9) = 15,
  'unlocking episode 9 costs 30 coins');
select pg_temp.check(
  exists (select 1 from public.episode_media m join public.episodes e
          on e.id = m.episode_id
          where e.series_id = 'bride-price' and e.number = 9),
  'the video link for episode 9 is now readable');
select pg_temp.check(
  public.unlock_episode_with_coins('bride-price', 9) = 15,
  'unlocking the same episode again is free');
select pg_temp.check(
  public.unlock_episode_with_coins('bride-price', 3) = 15,
  'free episodes cost nothing');
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$
begin
  perform public.unlock_episode_with_coins('bride-price', 10);
  raise exception 'FAILED: unlocked without enough coins';
exception when raise_exception then
  if sqlerrm <> 'Not enough coins' then raise; end if;
  raise notice 'ok: unlocking with too few coins is refused';
end $$;
select pg_temp.check(
  (select balance from public.wallets) = 15,
  'a refused unlock takes no coins');
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$
begin
  perform public.unlock_episode_with_coins('bride-price', 999);
  raise exception 'FAILED: unlocked a missing episode';
exception when no_data_found then
  raise notice 'ok: missing episodes cannot be unlocked';
end $$;
rollback;

-- --- Unlocking with ads -----------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select pg_temp.check(public.ads_left_today() = 3, 'three free ads a day');
select pg_temp.check(
  public.unlock_episode_with_ad('waterside', 9) = 2, 'first ad unlock');
select pg_temp.check(
  public.unlock_episode_with_ad('waterside', 9) = 2,
  'an already unlocked episode uses no ad');
select pg_temp.check(
  public.unlock_episode_with_ad('waterside', 10) = 1, 'second ad unlock');
select pg_temp.check(
  public.unlock_episode_with_ad('waterside', 11) = 0, 'third ad unlock');
do $$
begin
  perform public.unlock_episode_with_ad('waterside', 12);
  raise exception 'FAILED: a fourth ad unlock was allowed';
exception when raise_exception then
  raise notice 'ok: the daily ad limit holds';
end $$;
commit;

-- --- Watch history, My List and privacy between viewers ---------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
insert into public.watch_history
  (user_id, series_id, episode_number, position_ms, duration_ms)
values ('00000000-0000-0000-0000-00000000000a', 'waterside', 5, 30000, 75000)
on conflict (user_id, series_id) do update
  set episode_number = excluded.episode_number,
      position_ms = excluded.position_ms;
insert into public.my_list (user_id, series_id)
values ('00000000-0000-0000-0000-00000000000a', 'waterside');
select pg_temp.check(
  (select episode_number from public.watch_history) = 5,
  'viewers save their own watch history');
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select pg_temp.check(
  (select count(*) from public.watch_history) = 0 and
  (select count(*) from public.my_list) = 0 and
  (select count(*) from public.episode_unlocks) = 0 and
  (select balance from public.wallets) = 45,
  'another viewer sees none of the first viewer''s data');
select pg_temp.check(
  (select count(*) from public.episode_media m join public.episodes e
   on e.id = m.episode_id where e.series_id = 'bride-price') = 8,
  'another viewer does not get the first viewer''s unlocked episodes');
do $$
begin
  insert into public.watch_history (user_id, series_id, episode_number)
  values ('00000000-0000-0000-0000-00000000000a', 'bride-price', 1);
  raise exception 'FAILED: wrote another viewer''s history';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot write someone else''s history';
end $$;
rollback;

-- --- Passes -----------------------------------------------------------------
-- Passes are granted by the payment system (Milestone 6); simulate one here.
insert into public.user_passes (user_id, pass_id, ends_at)
values ('00000000-0000-0000-0000-00000000000b', 'day', now() + interval '1 day');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select pg_temp.check(
  (select count(*) from public.episode_media m join public.episodes e
   on e.id = m.episode_id where e.series_id = 'bride-price') = 40,
  'an active pass opens every episode');
rollback;

-- --- Unpublished series stay hidden -----------------------------------------
insert into public.series (id, title) values ('draft-show', 'Draft');
insert into public.episodes (series_id, number) values ('draft-show', 1);
begin;
set local role anon;
select pg_temp.check(
  not exists (select 1 from public.series_catalog where id = 'draft-show') and
  not exists (select 1 from public.episodes where series_id = 'draft-show'),
  'unpublished series and their episodes are hidden');
rollback;

-- --- Admins ------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-0000000000ad', '231770000099');
insert into public.admins (user_id)
values ('00000000-0000-0000-0000-0000000000ad');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select pg_temp.check(not public.is_admin(), 'viewers are not admins');
do $$
begin
  insert into public.series (id, title) values ('sneaky', 'Sneaky');
  raise exception 'FAILED: a viewer created a series';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot create series';
end $$;
do $$
begin
  insert into public.admins (user_id)
  values ('00000000-0000-0000-0000-00000000000a');
  raise exception 'FAILED: a viewer made themselves an admin';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot make themselves admins';
end $$;
update public.app_settings set unlock_cost_coins = 1;
update public.series set title = 'Hacked' where id = 'waterside';
rollback;

select pg_temp.check(
  (select unlock_cost_coins from public.app_settings) = 30 and
  (select title from public.series where id = 'waterside') = 'Waterside Boys',
  'viewers cannot change settings or series');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000ad';
select pg_temp.check(public.is_admin(), 'admins are recognised');
insert into public.series (id, title, genres)
values ('new-show', 'New Show', array['Drama']);
insert into public.episodes (series_id, number, duration_seconds)
values ('new-show', 1, 90);
insert into public.episode_media (episode_id, video_url)
select id, 'https://example.com/new.m3u8' from public.episodes
where series_id = 'new-show' and number = 1;
update public.app_settings set unlock_cost_coins = 25;
insert into public.coin_packs (coins, position) values (50, 9);
insert into public.home_rows (title, series_ids) values ('Test', '{new-show}');
select pg_temp.check(
  exists (select 1 from public.series where id = 'new-show'),
  'admins see unpublished series');
select pg_temp.check(
  (select count(*) from public.episode_media m join public.episodes e
   on e.id = m.episode_id where e.series_id = 'new-show') = 1,
  'admins add episodes with video links');
select pg_temp.check(
  (select count(*) from public.series_catalog where id = 'new-show') = 0,
  'the catalog still hides unpublished series');
commit;

begin;
set local role anon;
select pg_temp.check(
  not exists (select 1 from public.series where id = 'new-show') and
  (select unlock_cost_coins from public.app_settings) = 25,
  'guests do not see the draft, but do get the new settings');
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000ad';
update public.series set published = true where id = 'new-show';
delete from public.coin_packs where coins = 50;
commit;

begin;
set local role anon;
select pg_temp.check(
  (select episode_count from public.series_catalog where id = 'new-show') = 1
  and (select count(*) from public.coin_packs) = 4,
  'publishing shows the series; deleted packs disappear');
rollback;

-- --- Buying coins and passes (test payments) --------------------------------
begin;
set local role anon;
do $$
begin
  perform public.start_purchase(p_coin_pack_id => 1);
  raise exception 'FAILED: guests must not start purchases';
exception when insufficient_privilege then
  raise notice 'ok: guests cannot start purchases';
end $$;
rollback;

create temp table t_ids (name text primary key, id bigint);
grant all on t_ids to authenticated;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
create temp table t_balance as select balance from public.wallets;
insert into t_ids
select 'coins', (public.start_purchase(
  p_coin_pack_id => (select id from public.coin_packs where coins = 300),
  p_payment_method => 'mtn_momo') ->> 'id')::bigint;
select pg_temp.check(
  (select status = 'pending' and coins = 320 and reference like 'PAL-%'
     and product_name = '320 coins' and price_label = '[PRICE]'
   from public.purchases where id = (select id from t_ids where name = 'coins'))
  and (select balance from public.wallets) = (select balance from t_balance),
  'a purchase starts as pending and adds nothing yet');
do $$
begin
  perform public.complete_purchase((select id from t_ids where name = 'coins'));
  raise exception 'FAILED: a viewer paid out their own purchase';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot pay out purchases';
end $$;
do $$
begin
  perform public.admin_confirm_purchase((select id from t_ids where name = 'coins'));
  raise exception 'FAILED: a viewer confirmed their own purchase';
exception when insufficient_privilege then
  raise notice 'ok: viewers cannot confirm purchases';
end $$;
do $$
begin
  perform public.start_purchase(p_coin_pack_id => 1, p_pass_id => 'day');
  raise exception 'FAILED: bought a pack and a pass at once';
exception when invalid_parameter_value then
  raise notice 'ok: one product per purchase';
end $$;
insert into t_ids
select 'pass1', (public.start_purchase(p_pass_id => 'day') ->> 'id')::bigint;
insert into t_ids
select 'pass2', (public.start_purchase(p_pass_id => 'day') ->> 'id')::bigint;
insert into t_ids
select 'cancel', (public.start_purchase(p_pass_id => 'week') ->> 'id')::bigint;
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select pg_temp.check(
  (select count(*) from public.purchases) = 0,
  'viewers do not see other viewers'' purchases');
do $$
begin
  perform public.admin_list_purchases();
  raise exception 'FAILED: a viewer listed all purchases';
exception when insufficient_privilege then
  raise notice 'ok: only admins list purchases';
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000ad';
select pg_temp.check(
  (select count(*) from public.admin_list_purchases() where status = 'pending') = 4
  and (select viewer from public.admin_list_purchases() limit 1) = '231770000001',
  'admins list pending purchases with the viewer''s phone');
select public.admin_confirm_purchase((select id from t_ids where name = 'coins'));
select public.admin_confirm_purchase((select id from t_ids where name = 'coins'));
select public.admin_confirm_purchase((select id from t_ids where name = 'pass1'));
select public.admin_confirm_purchase((select id from t_ids where name = 'pass2'));
select public.admin_cancel_purchase((select id from t_ids where name = 'cancel'));
select public.admin_confirm_purchase((select id from t_ids where name = 'cancel'));
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select pg_temp.check(
  (select balance from public.wallets) = (select balance from t_balance) + 320,
  'confirming adds the coins exactly once');
select pg_temp.check(
  (select count(*) from public.wallet_transactions where reason = 'purchase') = 1,
  'the coins show in the viewer''s history');
select pg_temp.check(public.has_active_pass(), 'a confirmed pass is active');
select pg_temp.check(
  (select max(ends_at) - min(starts_at) from public.user_passes)
    = interval '48 hours',
  'a second pass starts when the first one ends');
select pg_temp.check(
  (select status from public.purchases
   where id = (select id from t_ids where name = 'cancel')) = 'failed'
  and (select count(*) from public.user_passes) = 2,
  'a cancelled purchase adds nothing, even if confirmed later');
select pg_temp.check(
  public.can_watch((select id from public.episodes
                    where series_id = 'bride-price' and number = 40)),
  'a pass opens every episode');
rollback;

-- Payments switched off.
update public.app_settings set payment_mode = 'off';
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$
begin
  perform public.start_purchase(p_pass_id => 'day');
  raise exception 'FAILED: bought while payments are off';
exception when raise_exception then
  raise notice 'ok: no purchases while payments are off';
end $$;
rollback;
update public.app_settings set payment_mode = 'test';

-- At most 5 unfinished purchases a day.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select public.start_purchase(p_pass_id => 'day') from generate_series(1, 5);
do $$
begin
  perform public.start_purchase(p_pass_id => 'day');
  raise exception 'FAILED: a sixth unfinished purchase was allowed';
exception when raise_exception then
  raise notice 'ok: unfinished purchases are limited';
end $$;
rollback;

-- Packs and passes that were bought can still be removed from sale.
begin;
delete from public.passes where id = 'day';
select pg_temp.check(
  (select count(*) from public.user_passes where pass_id is null) = 3,
  'removing a pass keeps the passes viewers bought');
rollback;

-- Put the sample settings back for any later checks.
update public.app_settings set unlock_cost_coins = 30;

\o
\echo 'All database checks passed.'
