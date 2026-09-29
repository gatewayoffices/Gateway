-- Gives the app access to exactly the tables and functions it uses.
--
-- Newer Supabase projects do not always expose new tables to the app
-- automatically, so access is granted here explicitly. The row level
-- security rules in the first migration still decide which rows each viewer
-- can see or change. Safe to run more than once.
--
-- How to apply: Supabase dashboard > SQL Editor > New query, paste this file,
-- click Run.

grant usage on schema public to anon, authenticated;

-- Catalog: readable by everyone, including guests.
grant select on
  public.app_settings,
  public.series,
  public.series_catalog,
  public.episodes,
  public.episode_media,
  public.home_rows,
  public.coin_packs,
  public.passes
to anon, authenticated;

-- A viewer's own records: read only (coins change through functions).
grant select on
  public.profiles,
  public.wallets,
  public.wallet_transactions,
  public.episode_unlocks,
  public.user_passes,
  public.purchases
to authenticated;
grant update (display_name, language, favourite_genres)
  on public.profiles to authenticated;

-- A viewer's own lists and history.
grant select, insert, update, delete on
  public.watch_history,
  public.my_list,
  public.series_likes
to authenticated;

-- Functions the app calls.
grant execute on function
  public.free_episodes_for(text),
  public.has_active_pass(),
  public.can_watch(bigint),
  public.ads_left_today()
to anon, authenticated;
grant execute on function
  public.unlock_episode_with_coins(text, int),
  public.unlock_episode_with_ad(text, int)
to authenticated;
