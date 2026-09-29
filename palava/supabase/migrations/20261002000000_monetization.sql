-- Milestone 6: buying coins and passes.
--
-- A purchase is created as "pending" and becomes "paid" in exactly one
-- place, complete_purchase(), which adds the coins or starts the pass. What
-- marks it paid depends on app_settings.payment_mode:
--   * 'test': nothing is charged. An admin confirms the purchase in the admin
--     panel (Purchases page). Used until a payment provider is connected.
--   * 'off':  the Pay button tells viewers payments are not open yet.
-- A later migration adds the payment provider (hosted checkout plus a
-- webhook that calls complete_purchase). The app never sees card or mobile
-- money details.
--
-- How to apply: Supabase dashboard > SQL Editor > New query, paste this file,
-- click Run. Safe to run more than once.

-- ---------------------------------------------------------------------------
-- Settings and tables
-- ---------------------------------------------------------------------------
alter table public.app_settings
  add column if not exists payment_mode text not null default 'test';
alter table public.app_settings
  drop constraint if exists app_settings_payment_mode_check;
alter table public.app_settings
  add constraint app_settings_payment_mode_check
  check (payment_mode in ('off', 'test'));

alter table public.purchases drop constraint if exists purchases_provider_check;
alter table public.purchases add constraint purchases_provider_check
  check (provider in ('test', 'flutterwave', 'paystack', 'revenuecat', 'manual'));

-- What was bought is copied onto the purchase, so later changes to a pack or
-- pass (or deleting it) never change a purchase already made.
alter table public.purchases
  add column if not exists reference text,
  add column if not exists coins int check (coins > 0),
  add column if not exists pass_hours int check (pass_hours > 0),
  add column if not exists product_name text,
  add column if not exists price_label text,
  add column if not exists payment_method text,
  add column if not exists paid_at timestamptz;
alter table public.purchases drop constraint if exists purchases_reference_key;
alter table public.purchases add constraint purchases_reference_key
  unique (reference);
alter table public.purchases
  drop constraint if exists purchases_payment_method_check;
alter table public.purchases add constraint purchases_payment_method_check
  check (payment_method in ('mtn_momo', 'orange_money', 'card', 'app_store'));

alter table public.purchases drop constraint if exists purchases_coin_pack_id_fkey;
alter table public.purchases add constraint purchases_coin_pack_id_fkey
  foreign key (coin_pack_id) references public.coin_packs (id) on delete set null;
alter table public.purchases drop constraint if exists purchases_pass_id_fkey;
alter table public.purchases add constraint purchases_pass_id_fkey
  foreign key (pass_id) references public.passes (id) on delete set null;

-- A bought pass keeps running even if the pass is later removed from sale.
alter table public.user_passes alter column pass_id drop not null;
alter table public.user_passes drop constraint if exists user_passes_pass_id_fkey;
alter table public.user_passes add constraint user_passes_pass_id_fkey
  foreign key (pass_id) references public.passes (id) on delete set null;

create index if not exists purchases_user_idx
  on public.purchases (user_id, created_at desc);
create index if not exists purchases_status_idx
  on public.purchases (status, created_at desc);

-- ---------------------------------------------------------------------------
-- The one place a purchase is paid out. Not callable from the app.
-- ---------------------------------------------------------------------------
create or replace function public.complete_purchase(p_purchase_id bigint)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v public.purchases;
  v_start timestamptz;
begin
  select * into v from public.purchases where id = p_purchase_id for update;
  if v.id is null then
    raise exception 'Purchase not found' using errcode = 'P0002';
  end if;
  -- Paying twice (e.g. a repeated webhook) changes nothing.
  if v.status <> 'pending' then
    return;
  end if;

  update public.purchases
  set status = 'paid', paid_at = now(), updated_at = now()
  where id = v.id;

  if v.product_type = 'coins' then
    update public.wallets
    set balance = balance + v.coins, updated_at = now()
    where user_id = v.user_id;
    insert into public.wallet_transactions (user_id, amount, reason, purchase_id)
    values (v.user_id, v.coins, 'purchase', v.id);
  else
    -- A new pass starts when the viewer's current one ends.
    select greatest(now(), coalesce(max(ends_at), now())) into v_start
    from public.user_passes where user_id = v.user_id;
    insert into public.user_passes (user_id, pass_id, starts_at, ends_at, purchase_id)
    values (
      v.user_id, v.pass_id, v_start,
      v_start + make_interval(hours => v.pass_hours), v.id
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Viewers: start a purchase
-- ---------------------------------------------------------------------------
-- Creates a pending purchase of one coin pack or one pass and returns
-- {"id": ..., "reference": "PAL-XXXXXXXX"}.
create or replace function public.start_purchase(
  p_coin_pack_id bigint default null,
  p_pass_id text default null,
  p_payment_method text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_mode text;
  v_label text;
  v_pack public.coin_packs;
  v_pass public.passes;
  v_id bigint;
  v_reference text;
begin
  if v_user is null then
    raise exception 'Sign in to buy coins' using errcode = '28000';
  end if;
  if (p_coin_pack_id is null) = (p_pass_id is null) then
    raise exception 'Choose one coin pack or one pass' using errcode = '22023';
  end if;

  select payment_mode, price_label into v_mode, v_label from public.app_settings;
  if v_mode <> 'test' then
    raise exception 'Payments are not open yet' using errcode = 'P0001',
      hint = 'payments_off';
  end if;

  -- Stops one viewer filling the list with unpaid purchases.
  if (
    select count(*) from public.purchases
    where user_id = v_user and status = 'pending'
      and created_at > now() - interval '1 day'
  ) >= 5 then
    raise exception 'Too many unfinished payments' using errcode = 'P0001',
      hint = 'too_many_pending';
  end if;

  v_reference := 'PAL-' || upper(substr(md5(gen_random_uuid()::text), 1, 8));

  if p_coin_pack_id is not null then
    select * into v_pack from public.coin_packs
    where id = p_coin_pack_id and active;
    if v_pack.id is null then
      raise exception 'That coin pack is no longer on sale' using errcode = 'P0002';
    end if;
    insert into public.purchases (
      user_id, product_type, coin_pack_id, coins, product_name, price_label,
      provider, reference, payment_method
    ) values (
      v_user, 'coins', v_pack.id, v_pack.coins + v_pack.bonus_coins,
      (v_pack.coins + v_pack.bonus_coins)::text || ' coins',
      coalesce(v_pack.price_label, v_label),
      'test', v_reference, p_payment_method
    ) returning id into v_id;
  else
    select * into v_pass from public.passes where id = p_pass_id and active;
    if v_pass.id is null then
      raise exception 'That pass is no longer on sale' using errcode = 'P0002';
    end if;
    insert into public.purchases (
      user_id, product_type, pass_id, pass_hours, product_name, price_label,
      provider, reference, payment_method
    ) values (
      v_user, 'pass', v_pass.id, v_pass.duration_hours, v_pass.name,
      coalesce(v_pass.price_label, v_label),
      'test', v_reference, p_payment_method
    ) returning id into v_id;
  end if;

  return jsonb_build_object('id', v_id, 'reference', v_reference);
end;
$$;

-- ---------------------------------------------------------------------------
-- Admins: see and settle purchases
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_purchases(p_limit int default 100)
returns table (
  id bigint,
  reference text,
  created_at timestamptz,
  status text,
  provider text,
  payment_method text,
  product_name text,
  price_label text,
  viewer text
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can see purchases' using errcode = '42501';
  end if;
  return query
  select p.id, p.reference, p.created_at, p.status, p.provider,
    p.payment_method, p.product_name, p.price_label,
    coalesce(
      nullif(u.phone, ''), nullif(u.email, ''), p.user_id::text
    ) as viewer
  from public.purchases p
  join auth.users u on u.id = p.user_id
  order by (p.status = 'pending') desc, p.created_at desc
  limit least(greatest(p_limit, 1), 500);
end;
$$;

-- Marks a test purchase paid (adds the coins or starts the pass).
create or replace function public.admin_confirm_purchase(p_purchase_id bigint)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can confirm purchases' using errcode = '42501';
  end if;
  -- Real payments are confirmed by the payment provider, never by hand.
  if not exists (
    select 1 from public.purchases
    where id = p_purchase_id and provider in ('test', 'manual')
  ) then
    raise exception 'Only test purchases can be confirmed here'
      using errcode = 'P0001';
  end if;
  perform public.complete_purchase(p_purchase_id);
end;
$$;

-- Marks a pending purchase as failed (nothing is added).
create or replace function public.admin_cancel_purchase(p_purchase_id bigint)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can cancel purchases' using errcode = '42501';
  end if;
  update public.purchases
  set status = 'failed', updated_at = now()
  where id = p_purchase_id and status = 'pending';
end;
$$;

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------
revoke execute on function public.complete_purchase(bigint)
  from public, anon, authenticated;
revoke execute on function public.start_purchase(bigint, text, text)
  from public, anon;
grant execute on function public.start_purchase(bigint, text, text)
  to authenticated;
revoke execute on function public.admin_list_purchases(int) from public, anon;
revoke execute on function public.admin_confirm_purchase(bigint) from public, anon;
revoke execute on function public.admin_cancel_purchase(bigint) from public, anon;
grant execute on function
  public.admin_list_purchases(int),
  public.admin_confirm_purchase(bigint),
  public.admin_cancel_purchase(bigint)
to authenticated;
