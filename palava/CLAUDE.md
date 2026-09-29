# Palava — project brief for Claude Code

Palava is a mobile app for original African micro-dramas: vertical series of 1–2 minute episodes that end on cliffhangers, made for viewers in Liberia (and West Africa) and the African diaspora in the US and UK. It should feel like StoryReel, ReelShort or DramaBox, but every story is original and African. "Palava" is a working name.

The owner is not a developer. Explain what you are doing in plain language, keep steps small, and tell her exactly what to run or click when something needs her.

## What we are building first (the MVP)

Build in this order, one milestone at a time, and get each working on a phone before moving on:

1. **Project setup** — Flutter app (Android first, iOS second), Git repository, folder structure, theme.
2. **Screens with sample data** — Welcome/sign-up, Home, For You feed, Series page, Unlock sheet, Wallet, Profile. Use hard-coded sample series until the backend exists.
3. **Video player** — full-screen vertical player, swipe to next episode, autoplay, resume, subtitles on/off. Use public test video streams (HLS) until real episodes exist.
4. **Backend** — Supabase: auth (phone number with SMS code, plus Google/Apple), series, episodes, watch history, wallet, purchases.
5. **Admin panel** — simple web app to create series, upload episodes, set prices and free-episode counts.
6. **Monetization** — free first episodes, coin unlocks, passes, rewarded ads. Payments (mobile money and app stores) come last and need real accounts; build them against test/sandbox modes.
7. **Offline downloads, data-saver mode, push notifications.**

## Screens (match the clickable prototype)

- **Welcome** — logo, tagline, language (English/Français), genre chips, phone number with +231 prefix, "Send me a code", "Browse as a guest".
- **Home** — header with search, featured series hero, "Continue watching" row with progress bars, "Trending in Monrovia" row, bottom nav (Home, For You, My List, Profile).
- **For You feed** — full-screen vertical video, right-side actions (Like, My List, Episodes, Share), series title and episode line at bottom, "Watch all episodes" button, progress bar.
- **Series page** — poster header, title, genre/episode count/language/age rating, synopsis, Play episode 1, My List, Download, episode grid (episodes 1–8 free, 9+ locked with a lock icon).
- **Unlock sheet** — over the player at a locked episode: coin balance, "Unlock with 30 coins", "Day pass", "Watch a short ad (free, N left today)", auto-unlock switch.
- **Wallet** — balance, coin packs (100/300/600/1,200), day and week passes, pay with MTN Mobile Money / Orange Money / card or app store, Pay button.
- **Profile** — name and masked phone, wallet shortcut, downloads, data saver switch, WiFi-only downloads switch, language, notifications, help, log out.

## Look and feel

- Dark, warm "fireside" theme.
- Colors: background `#1A120D`, cards `#2A1D15`, card borders `#3D2C21`, main text `#F6EEE2`, secondary text `#CDBFAE`, quiet text `#A08F80`, accent (ember orange) `#E2622B`, gold `#E8B04A`.
- Fonts: Fraunces (titles), DM Sans (everything else), from Google Fonts.
- Rounded corners (12–20), touch targets at least 44 px, no emoji in the UI.

## Rules that matter

- **Low data first**: viewers in Liberia pay for every megabyte. Default to low video quality in Africa regions, preload only the next episode, downloads over WiFi by default.
- **Low-end Android**: must run smoothly on 2 GB RAM phones, Android 7.0+.
- **Nothing hard-coded that the business will change**: prices, free-episode counts, ad limits and home rows come from the backend/admin panel.
- **Prices are not set yet**: show `[PRICE]` placeholders.
- **Secrets never go in the code or Git**: API keys live in environment files that are git-ignored.
- **Payments**: never handle card or mobile-money details directly; use the provider's hosted checkout (Flutterwave or Paystack for mobile money, RevenueCat for app stores).

## Recommended stack

- Flutter (Dart) for the app
- Supabase for auth, database, storage and server functions
- Mux or Cloudflare Stream for video (HLS, signed URLs)
- Flutterwave or Paystack for mobile money; RevenueCat for app-store purchases
- Google AdMob for rewarded ads
- Firebase Cloud Messaging for push; Firebase Crashlytics for crash reports

## Working style

- At the start of each session, say which milestone we are on and what comes next.
- After each milestone, tell the owner how to run the app on her phone or emulator and what to check.
- Commit to Git after each working step with a clear message.
- If something needs an account, a key or a payment, stop and explain what she needs to set up and where.
