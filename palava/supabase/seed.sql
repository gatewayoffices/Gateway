-- Sample content for testing: the same series the app shows in sample mode.
-- Videos are Google's public HLS test streams, not real episodes.
-- How to apply: after the schema, paste this file into the SQL Editor and Run.
-- Safe to run again: it replaces the sample content.

begin;

delete from public.home_rows;
delete from public.coin_packs;
delete from public.passes where id in ('day','week');
delete from public.series where id in ('bride-price', 'waterside', 'diaspora-daughter', 'sinkor-nights', 'palm-wine', 'lagos-contract', 'second-wife', 'mama-kitchen');

insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('bride-price', 'The Bride Price', 'Two families. One wedding. Too many secrets.', 'Weeks before her wedding in Monrovia, Hawa discovers that the bride price her fiance''s family paid came from a debt her own father never told her about. Now both families want something from her, and the wedding clock is ticking.', array['Romance', 'Family'], 'English', '13+', array['#8C2F1B', '#2B1209'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('waterside', 'Waterside Boys', 'The market runs on favours. Favours run out.', 'Three friends who grew up hustling in Waterside Market get one chance at a big deal. When the money goes missing, trust is the first thing to disappear.', array['Crime', 'Thriller'], 'English', '16+', array['#1F4E5A', '#0E1A1F'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('diaspora-daughter', 'Diaspora Daughter', 'She came home for a funeral. She stayed for the truth.', 'Raised in Minnesota, Ada returns to Liberia to bury the grandmother she barely knew, and finds a will that names her the owner of land the whole town is fighting over.', array['Drama', 'Mystery'], 'English', '13+', array['#6B4A1E', '#1E140A'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('sinkor-nights', 'Sinkor Nights', 'Love after midnight has rules.', 'A nightclub singer and a young doctor keep meeting by accident on Tubman Boulevard. Neither of them is who the other thinks.', array['Romance'], 'English', '16+', array['#4A1F4E', '#160B18'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('palm-wine', 'Palm Wine and Secrets', 'Every village keeps one. This one keeps many.', 'When a stranger opens a palm wine bar in a quiet Bong County town, old secrets start pouring out with every cup.', array['Mystery', 'Drama'], 'English', '13+', array['#3E5A1F', '#12190A'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('lagos-contract', 'The Lagos Contract', 'Sign here. Lose everything.', 'A young Liberian lawyer lands a dream job in Lagos, until she realises the contract she drafted is being used to take over her own family''s business.', array['Thriller', 'Drama'], 'English', '13+', array['#5A3A1F', '#1A0F07'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('second-wife', 'The Chief''s Second Wife', 'She married into power. Now she wants it.', 'Musu marries an ageing town chief for security. When he falls ill, she has to outplay his first wife, his sons and the elders to protect her daughter.', array['Drama', 'Family'], 'English', '16+', array['#7A5A12', '#221806'], true);
insert into public.series (id, title, tagline, synopsis, genres, language, age_rating, poster_colors, published) values ('mama-kitchen', 'Mama Sia''s Kitchen', 'The best cookshop in Paynesville. The loudest family too.', 'Mama Sia runs the most popular cookshop in Paynesville with her four grown children, who all want to run it differently.', array['Comedy', 'Family'], 'English', 'All ages', array['#9A4A16', '#2A1405'], true);

insert into public.episodes (series_id, number, duration_seconds)
select s.id, n, 75 from public.series s
cross join lateral generate_series(1, case s.id when 'bride-price' then 40 when 'waterside' then 32 when 'diaspora-daughter' then 36 when 'sinkor-nights' then 28 when 'palm-wine' then 30 when 'lagos-contract' then 34 when 'second-wife' then 45 when 'mama-kitchen' then 24 end) as n
where s.id in ('bride-price', 'waterside', 'diaspora-daughter', 'sinkor-nights', 'palm-wine', 'lagos-contract', 'second-wife', 'mama-kitchen');

insert into public.episode_media (episode_id, video_url, subtitles_vtt)
select e.id, (array['https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8', 'https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8', 'https://storage.googleapis.com/shaka-demo-assets/apple-advanced-stream-ts/master.m3u8'])[((e.number - 1) % 3) + 1], 'WEBVTT

00:00:01.000 --> 00:00:05.000
Where were you last night?

00:00:07.000 --> 00:00:11.000
You don''t want to know.

00:00:13.000 --> 00:00:17.000
Everybody in this town has a secret.

00:00:19.000 --> 00:00:23.000
Then tell me yours.

00:00:25.000 --> 00:00:29.000
Not here. Not now.

00:00:31.000 --> 00:00:35.000
If Mama finds out...

00:00:37.000 --> 00:00:41.000
She won''t. Unless you tell her.

00:00:43.000 --> 00:00:47.000
I''m tired of lying for you.

00:00:49.000 --> 00:00:53.000
Then stop.

00:00:55.000 --> 00:00:59.000
It''s too late for that.

00:01:01.000 --> 00:01:05.000
Someone is at the door.

00:01:07.000 --> 00:01:11.000
Don''t open it.

'
from public.episodes e where e.series_id in ('bride-price', 'waterside', 'diaspora-daughter', 'sinkor-nights', 'palm-wine', 'lagos-contract', 'second-wife', 'mama-kitchen');

insert into public.home_rows (title, position, series_ids) values ('Trending in Monrovia', 0, array['waterside', 'bride-price', 'sinkor-nights', 'palm-wine']);
insert into public.home_rows (title, position, series_ids) values ('New this week', 1, array['diaspora-daughter', 'lagos-contract', 'second-wife']);
insert into public.home_rows (title, position, series_ids) values ('Family and romance', 2, array['mama-kitchen', 'bride-price', 'diaspora-daughter']);

insert into public.coin_packs (coins, bonus_coins, position) values (100, 0, 0);
insert into public.coin_packs (coins, bonus_coins, position) values (300, 20, 1);
insert into public.coin_packs (coins, bonus_coins, position) values (600, 60, 2);
insert into public.coin_packs (coins, bonus_coins, position) values (1200, 150, 3);
insert into public.passes (id, name, description, duration_hours, position) values ('day', 'Day pass', 'Every episode, 24 hours', 24, 0), ('week', 'Week pass', 'Every episode, 7 days', 168, 1);

update public.app_settings set featured_series_id = 'bride-price', for_you_series_ids = array['sinkor-nights', 'waterside', 'bride-price', 'palm-wine', 'second-wife', 'lagos-contract'], updated_at = now();

commit;
