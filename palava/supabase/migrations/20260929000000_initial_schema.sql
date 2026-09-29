-- Palava database: catalog, viewers, wallet, unlocks and watch history.
--
-- How to apply: Supabase dashboard > SQL Editor > New query, paste this whole
-- file, click Run. Run it once, on a new project.
--
-- Security model
--   * Everyone (including guests) can read published series, episodes,
--     settings, coin packs and passes.
--   * Video links (episode_media) are only readable for episodes the viewer
--     may watch: free episodes, unlocked episodes, or with an active pass.
--   * Viewers can read their own wallet, unlocks, passes and purchases but
--     never change them directly. Coins only move through the functions at
--     the bottom of this file, which check the balance on the server.
--   * Viewers manage their own watch history, My List and likes.

-- ---------------------------------------------------------------------------
-- Settings the business changes without an app update (one row).
-- ---------------------------------------------------------------------------
create table public.app_settings (
  id boolean primary key default true check (id),
  free_episode_count int not null default 8 check (free_episode_count >= 0),
  unlock_cost_coins int not null default 30 check (unlock_cost_coins > 0),
  free_ads_per_day int not null default 3 check (free_ads_per_day >= 0),
  welcome_coins int not null default 45 check (welcome_coins >= 0),
  data_saver_max_bitrate int not null default 800000
    check (data_saver_max_bitrate > 0),
  price_label text not null default '[PRICE]',
  featured_series_id text,
  for_you_series_ids text[] not null default '{}',
  updated_at timestamptz not null default now()
);

insert into public.app_settings default values;

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
create table public.series (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9-]*$'),
  title text not null,
  tagline text not null default '',
  synopsis text not null default '',
  genres text[] not null default '{}',
  language text not null default 'English',
  age_rating text not null default '13+',
  poster_url text,
  -- Two hex colours for the placeholder poster when there is no artwork.
  poster_colors text[] not null default '{"#5A3A1F","#1A0F07"}',
  -- Optional per-series overrides of app_settings.
  free_episode_count int check (free_episode_count >= 0),
  unlock_cost_coins int check (unlock_cost_coins > 0),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.app_settings
  add constraint app_settings_featured_series_fk
  foreign key (featured_series_id) references public.series (id)
  on delete set null;

create table public.episodes (
  id bigint generated always as identity primary key,
  series_id text not null references public.series (id) on delete cascade,
  number int not null check (number > 0),
  title text,
  duration_seconds int check (duration_seconds > 0),
  published boolean not null default true,
  created_at timestamptz not null default now(),
  unique (series_id, number)
);

-- Kept apart from episodes so locked episodes' video links stay private.
create table public.episode_media (
  episode_id bigint primary key references public.episodes (id)
    on delete cascade,
  -- HLS playlist (.m3u8) from the video host.
  video_url text not null,
  -- WebVTT subtitles stored inline: a few KB, and no extra download.
  subtitles_vtt text
);

create table public.home_rows (
  id bigint generated always as identity primary key,
  title text not null,
  position int not null default 0,
  series_ids text[] not null default '{}',
  active boolean not null default true
);

create table public.coin_packs (
  id bigint generated always as identity primary key,
  coins int not null check (coins > 0),
  bonus_coins int not null default 0 check (bonus_coins >= 0),
  -- Shown to viewers; null uses app_settings.price_label.
  price_label text,
  position int not null default 0,
  active boolean not null default true
);

create table public.passes (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9-]*$'),
  name text not null,
  description text not null default '',
  duration_hours int not null check (duration_hours > 0),
  price_label text,
  position int not null default 0,
  active boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Viewers
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  phone text,
  language text not null default 'en' check (language in ('en', 'fr')),
  favourite_genres text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.wallets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.purchases (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  product_type text not null check (product_type in ('coins', 'pass')),
  coin_pack_id bigint references public.coin_packs (id),
  pass_id text references public.passes (id),
  provider text not null
    check (provider in ('flutterwave', 'paystack', 'revenuecat', 'manual')),
  provider_reference text unique,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'failed', 'refunded')),
  amount_minor bigint,
  currency text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null,
  reason text not null
    check (reason in ('welcome', 'unlock', 'purchase', 'refund', 'admin')),
  episode_id bigint references public.episodes (id) on delete set null,
  purchase_id bigint references public.purchases (id) on delete set null,
  created_at timestamptz not null default now()
);

create index wallet_transactions_user_idx
  on public.wallet_transactions (user_id, created_at desc);

create table public.episode_unlocks (
  user_id uuid not null references auth.users (id) on delete cascade,
  episode_id bigint not null references public.episodes (id) on delete cascade,
  method text not null check (method in ('coins', 'ad')),
  created_at timestamptz not null default now(),
  primary key (user_id, episode_id)
);

create index episode_unlocks_ads_idx
  on public.episode_unlocks (user_id, created_at) where method = 'ad';

create table public.user_passes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  pass_id text not null references public.passes (id),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  purchase_id bigint references public.purchases (id) on delete set null,
  check (ends_at > starts_at)
);

create index user_passes_active_idx on public.user_passes (user_id, ends_at);

create table public.watch_history (
  user_id uuid not null references auth.users (id) on delete cascade,
  series_id text not null references public.series (id) on delete cascade,
  episode_number int not null check (episode_number > 0),
  position_ms bigint not null default 0 check (position_ms >= 0),
  duration_ms bigint not null default 0 check (duration_ms >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, series_id)
);

create table public.my_list (
  user_id uuid not null references auth.users (id) on delete cascade,
  series_id text not null references public.series (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (user_id, series_id)
);

create table public.series_likes (
  user_id uuid not null references auth.users (id) on delete cascade,
  series_id text not null references public.series (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, series_id)
);

-- ---------------------------------------------------------------------------
-- Helper functions used by the security rules
-- ---------------------------------------------------------------------------
create function public.free_episodes_for(p_series_id text)
returns int
language sql stable security definer set search_path = ''
as $$
  select coalesce(s.free_episode_count, a.free_episode_count)
  from public.series s cross join public.app_settings a
  where s.id = p_series_id;
$$;

create function public.has_active_pass()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.user_passes p
    where p.user_id = auth.uid() and now() >= p.starts_at and now() < p.ends_at
  );
$$;

-- True when the signed-in viewer (or a guest) may play this episode.
create function public.can_watch(p_episode_id bigint)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.episodes e
    join public.series s on s.id = e.series_id
    where e.id = p_episode_id
      and e.published
      and s.published
      and (
        e.number <= public.free_episodes_for(e.series_id)
        or exists (
          select 1 from public.episode_unlocks u
          where u.user_id = auth.uid() and u.episode_id = e.id
        )
        or public.has_active_pass()
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Security rules (row level security)
-- ---------------------------------------------------------------------------
alter table public.app_settings enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;
alter table public.episode_media enable row level security;
alter table public.home_rows enable row level security;
alter table public.coin_packs enable row level security;
alter table public.passes enable row level security;
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.purchases enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.episode_unlocks enable row level security;
alter table public.user_passes enable row level security;
alter table public.watch_history enable row level security;
alter table public.my_list enable row level security;
alter table public.series_likes enable row level security;

create policy "Anyone can read settings" on public.app_settings
  for select to anon, authenticated using (true);

create policy "Anyone can read published series" on public.series
  for select to anon, authenticated using (published);

create policy "Anyone can read published episodes" on public.episodes
  for select to anon, authenticated
  using (
    published
    and exists (
      select 1 from public.series s where s.id = series_id and s.published
    )
  );

create policy "Video links only for watchable episodes" on public.episode_media
  for select to anon, authenticated using (public.can_watch(episode_id));

create policy "Anyone can read active home rows" on public.home_rows
  for select to anon, authenticated using (active);

create policy "Anyone can read active coin packs" on public.coin_packs
  for select to anon, authenticated using (active);

create policy "Anyone can read active passes" on public.passes
  for select to anon, authenticated using (active);

create policy "Viewers read their own profile" on public.profiles
  for select to authenticated using (id = auth.uid());
create policy "Viewers update their own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "Viewers read their own wallet" on public.wallets
  for select to authenticated using (user_id = auth.uid());
create policy "Viewers read their own purchases" on public.purchases
  for select to authenticated using (user_id = auth.uid());
create policy "Viewers read their own transactions" on public.wallet_transactions
  for select to authenticated using (user_id = auth.uid());
create policy "Viewers read their own unlocks" on public.episode_unlocks
  for select to authenticated using (user_id = auth.uid());
create policy "Viewers read their own passes" on public.user_passes
  for select to authenticated using (user_id = auth.uid());

create policy "Viewers manage their own history" on public.watch_history
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Viewers manage their own list" on public.my_list
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Viewers manage their own likes" on public.series_likes
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Viewers may only change these profile fields (not phone or id).
revoke update on public.profiles from anon, authenticated;
grant update (display_name, language, favourite_genres)
  on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- What the app reads for the catalog
-- ---------------------------------------------------------------------------
create view public.series_catalog with (security_invoker = true) as
select
  s.id,
  s.title,
  s.tagline,
  s.synopsis,
  s.genres,
  s.language,
  s.age_rating,
  s.poster_url,
  s.poster_colors,
  coalesce(s.free_episode_count, a.free_episode_count) as free_episodes,
  coalesce(s.unlock_cost_coins, a.unlock_cost_coins) as unlock_cost_coins,
  (
    select count(*)::int from public.episodes e
    where e.series_id = s.id and e.published
  ) as episode_count
from public.series s
cross join public.app_settings a
where s.published;

-- ---------------------------------------------------------------------------
-- New viewer: create profile and wallet with welcome coins.
-- ---------------------------------------------------------------------------
create function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_welcome int;
begin
  select welcome_coins into v_welcome from public.app_settings;
  insert into public.profiles (id, phone, display_name)
  values (
    new.id,
    new.phone,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  );
  insert into public.wallets (user_id, balance) values (new.id, v_welcome);
  if v_welcome > 0 then
    insert into public.wallet_transactions (user_id, amount, reason)
    values (new.id, v_welcome, 'welcome');
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Unlocking episodes (the only way coins leave a wallet)
-- ---------------------------------------------------------------------------

-- Returns the episode id, or raises if it does not exist.
create function public.find_episode(p_series_id text, p_episode_number int)
returns bigint
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_id bigint;
begin
  select e.id into v_id
  from public.episodes e join public.series s on s.id = e.series_id
  where e.series_id = p_series_id and e.number = p_episode_number
    and e.published and s.published;
  if v_id is null then
    raise exception 'Episode not found' using errcode = 'P0002';
  end if;
  return v_id;
end;
$$;

-- Spends coins to unlock an episode. Returns the new balance. Safe to call
-- twice: an episode that can already be watched costs nothing.
create function public.unlock_episode_with_coins(
  p_series_id text,
  p_episode_number int
)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_episode bigint;
  v_cost int;
  v_balance int;
begin
  if v_user is null then
    raise exception 'Sign in to unlock episodes' using errcode = '28000';
  end if;
  v_episode := public.find_episode(p_series_id, p_episode_number);

  -- Lock the wallet row so two taps cannot both spend the same coins.
  select balance into v_balance from public.wallets
  where user_id = v_user for update;
  if v_balance is null then
    raise exception 'Wallet not found' using errcode = 'P0002';
  end if;

  if public.can_watch(v_episode) then
    return v_balance;
  end if;

  select coalesce(s.unlock_cost_coins, a.unlock_cost_coins) into v_cost
  from public.series s cross join public.app_settings a
  where s.id = p_series_id;

  if v_balance < v_cost then
    raise exception 'Not enough coins' using errcode = 'P0001',
      hint = 'insufficient_coins';
  end if;

  update public.wallets
  set balance = balance - v_cost, updated_at = now()
  where user_id = v_user
  returning balance into v_balance;

  insert into public.episode_unlocks (user_id, episode_id, method)
  values (v_user, v_episode, 'coins');
  insert into public.wallet_transactions (user_id, amount, reason, episode_id)
  values (v_user, -v_cost, 'unlock', v_episode);

  return v_balance;
end;
$$;

-- How many free ad unlocks the viewer has left today (UTC day).
create function public.ads_left_today()
returns int
language sql stable security definer set search_path = ''
as $$
  select greatest(
    0,
    (select free_ads_per_day from public.app_settings) - (
      select count(*)::int from public.episode_unlocks u
      where u.user_id = auth.uid()
        and u.method = 'ad'
        and u.created_at >= date_trunc('day', now() at time zone 'utc')
          at time zone 'utc'
    )
  );
$$;

-- Unlocks an episode after a rewarded ad. Returns ads left today.
-- Milestone 6 adds verification of the ad with Google AdMob before this runs.
create function public.unlock_episode_with_ad(
  p_series_id text,
  p_episode_number int
)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_episode bigint;
begin
  if v_user is null then
    raise exception 'Sign in to unlock episodes' using errcode = '28000';
  end if;
  v_episode := public.find_episode(p_series_id, p_episode_number);

  -- Serialise this viewer's ad unlocks so the daily limit holds.
  perform 1 from public.wallets where user_id = v_user for update;

  if public.can_watch(v_episode) then
    return public.ads_left_today();
  end if;
  if public.ads_left_today() <= 0 then
    raise exception 'No free ads left today' using errcode = 'P0001',
      hint = 'no_ads_left';
  end if;

  insert into public.episode_unlocks (user_id, episode_id, method)
  values (v_user, v_episode, 'ad');
  return public.ads_left_today();
end;
$$;

-- Only signed-in viewers may call the unlock functions.
revoke execute on function public.unlock_episode_with_coins(text, int) from public, anon;
revoke execute on function public.unlock_episode_with_ad(text, int) from public, anon;
grant execute on function public.unlock_episode_with_coins(text, int) to authenticated;
grant execute on function public.unlock_episode_with_ad(text, int) to authenticated;

-- Internal helpers: not callable from the app.
revoke execute on function public.find_episode(text, int) from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
