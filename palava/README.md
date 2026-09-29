# Palava

Original African micro-dramas: short vertical episodes that end on cliffhangers.
The project brief is in [CLAUDE.md](CLAUDE.md).

## Where we are

| Milestone | Status |
|---|---|
| 1. Project setup (Flutter app, Git, folders, theme) | Done |
| 2. Seven screens with sample data | Done |
| 3. Video player | Done |
| 4. Backend (Supabase) | Done (real SMS and Google/Apple sign-in later) |
| 5. Admin panel | Done |
| 6. Monetization and payments | In progress: coins, passes, test ads and test payments done; real payments need accounts |
| 7. Downloads, data saver, notifications | Later |

Everything you see is sample data. Videos are free public test clips from
Google (not African dramas, and landscape rather than vertical); they only prove
the player works. Each sample episode stops after 75 seconds so you can see the
next one start by itself. Buttons that need a later milestone (real payments,
downloads, sharing) show a short message saying so. Payments run in **test
mode**: nothing is charged, and you confirm each purchase in the admin panel.
Ads are Google's test ads, which never pay out.

---

## One-time setup on your computer

Do these in order. Each step says how to check that it worked.

### Step 0: Open a terminal

The terminal is a window where you type commands.

- **Windows:** press the Windows key, type `PowerShell`, and open **Windows PowerShell**.
- **Mac:** press Cmd + Space, type `Terminal`, and press Enter.

### Step 1: Check what is already installed

Type each line below and press Enter after each one:

```
git --version
flutter --version
```

- If `git --version` prints something like `git version 2.x`, Git is installed. Skip Step 2.
- If `flutter --version` prints `Flutter 3.x`, Flutter is installed. Skip Step 4.
- If you see "not recognized" or "command not found", that tool is not installed yet.
- For Android Studio, look in your Start menu (Windows) or Applications folder (Mac).
  If it is there, skip Step 3.

### Step 2: Install Git

- **Windows:** go to <https://git-scm.com/downloads/win>, download the installer,
  run it, and click **Next** on every screen (the defaults are fine).
- **Mac:** in Terminal, type `xcode-select --install` and click **Install** in the
  window that appears. This takes a few minutes.

Check: close the terminal, open a new one, and type `git --version`.

### Step 3: Install Android Studio

1. Go to <https://developer.android.com/studio> and click **Download Android Studio**.
2. Run the installer. When it asks, choose **Standard** setup and accept the licences.
   It downloads the Android tools, which can take 10–20 minutes.
3. When you reach the "Welcome to Android Studio" window:
   - Click **Plugins**, search for **Flutter**, click **Install**, and accept
     when it offers to install **Dart** too. Restart Android Studio when asked.
   - Click **More Actions > SDK Manager**, open the **SDK Tools** tab, tick
     **Android SDK Command-line Tools (latest)**. Then tick **Show Package Details**
     (bottom right), expand **NDK (Side by side)**, and tick version
     **28.2.13676358**. Click **Apply**, then **OK**. (Flutter needs this exact NDK
     version and cannot always download it by itself.)

### Step 4: Install Flutter

1. Go to <https://docs.flutter.dev/install/archive> and download the latest
   **Stable** release for your computer:
   - Windows: the Windows zip file.
   - Mac: the file for **arm64** if your Mac has an Apple chip (M1, M2, M3, M4),
     otherwise **x64**. (Apple menu > About This Mac tells you which chip you have.)
2. Unzip it:
   - **Windows:** create the folder `C:\src` and unzip so you have `C:\src\flutter`.
   - **Mac:** create a folder called `development` in your home folder and unzip
     into it, so you have `development/flutter`.
3. Tell your computer where Flutter lives:
   - **Windows:** press the Windows key, type `environment`, open **Edit environment
     variables for your account**, select **Path**, click **Edit**, then **New**, type
     `C:\src\flutter\bin`, and click **OK** twice.
   - **Mac:** in Terminal, paste this line and press Enter:
     ```
     echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
     ```
4. Close the terminal and open a new one. Then run:
   ```
   flutter doctor --android-licenses
   ```
   Type `y` and press Enter each time it asks.
5. Run:
   ```
   flutter doctor
   ```
   You want green ticks next to **Flutter**, **Android toolchain** and
   **Android Studio**. Lines about Chrome, Visual Studio or Xcode don't matter yet.
   If anything else has a red cross, copy the whole output and send it to Claude.

### Step 5: Get the Palava code

In the terminal, go to where you want the project to live (for example your
Documents folder), then run these one at a time:

```
cd Documents
git clone https://github.com/gatewayoffices/Gateway.git
cd Gateway
git checkout claude/nifty-hopper-x7xg7u
cd palava
```

If a GitHub sign-in window opens, sign in with your GitHub account.

### Step 6: Get your Android phone ready

1. On the phone, open **Settings > About phone** and tap **Build number** seven
   times. You'll see "You are now a developer".
   (On Samsung it is under **Settings > About phone > Software information**.)
2. Go back to **Settings**, open **Developer options** (sometimes under
   **System**), and turn on **USB debugging**.
3. Plug the phone into your computer with a USB cable that carries data
   (some charging-only cables don't work).
4. On the phone, tap **Allow** when it asks "Allow USB debugging?"
   (tick "Always allow from this computer").

Check: in the terminal, inside the `palava` folder, run `flutter devices`.
Your phone should be listed.

---

## Running the app on your phone

From the `palava` folder in the terminal:

```
flutter run
```

Once Supabase is connected (see "Connecting the app to Supabase" below), add
`--dart-define-from-file=env.json` to every `flutter run`. Without it the app
uses the built-in sample data.

The first run takes 5–10 minutes while it downloads build tools. After that it
takes under a minute. The app opens on your phone by itself, and it stays
installed after you unplug.

If more than one phone or device is connected, pick the phone by its ID from
`flutter devices`, for example `flutter run -d 5A210DLCQ002B1`.

If the build fails with **"did not install NDK"**, install the NDK version it
names using the SDK Manager steps in Step 3, then run `flutter run` again.

In the terminal while it is running: press `r` to refresh after code changes,
and `q` to quit.

**Using Android Studio instead:** choose **Open**, pick the `palava` folder, wait
for it to finish loading, select your phone in the device list at the top, and
press the green **Run** triangle.

**Getting new versions later:** from the `palava` folder run `git pull`, then
`flutter run` again.

## What to check on your phone (Milestone 2: screens)

1. **Welcome:** switch language, pick some genres, enter a phone number after
   +231 and tap **Send me a code** (sample mode signs you in straight away), or
   tap **Browse as a guest**.
2. **Home:** featured series, "Continue watching" with progress bars,
   "Trending in Monrovia". Tap the search icon and search "romance" or "Waterside".
   Tap the coin balance to open the Wallet.
3. **For You:** swipe up and down between series. Tap Like and My List (they
   change colour), Episodes (opens the episode grid), and **Watch all episodes**.
4. **Series page:** episodes 1–8 have no lock; 9 and up show a gold lock.
5. **Unlock sheet:** tap a locked episode. Try **Unlock with 30 coins** (you
   start with 45, so it works once), then try again with too few coins. Try
   **Watch a short ad**, which counts down from 3.
6. **Wallet:** choose a coin pack and tap **Pay**. Pretend coins are added.
   All prices show `[PRICE]`.
7. **Profile:** switches for data saver, WiFi-only downloads and notifications,
   language picker, and Sign in / Log out.
8. **My List:** shows what you saved from the feed or series pages.

## What to check on your phone (Milestone 3: video player)

Use WiFi or mobile data; the videos stream from the internet.

1. **Play:** open any series and tap **Play episode 1**. The video fills the
   screen and starts by itself. Tap the video to pause, tap again to play.
2. **Subtitles:** lines appear near the bottom (sample text, not matched to the
   clip). Tap the **CC** button at the top right to turn them off and on. The
   same switch is in **Profile > Subtitles**.
3. **Swipe:** swipe up for the next episode, down for the previous one.
4. **Autoplay:** wait 75 seconds (or drag the progress bar near the end). The
   next episode slides in and plays by itself.
5. **Jump:** drag or tap the thin orange bar at the bottom to move within the
   episode.
6. **Locked episodes:** keep going past episode 8 (or tap **Episodes** at the
   top right and pick 9). The unlock sheet appears. Unlock with coins or a
   short ad, and it plays. Turn on **Auto-unlock** in that sheet and the next
   locked episode unlocks by itself while you have coins.
7. **Resume:** watch part of an episode, go back, and close the app completely.
   Open it again: **Home > Continue watching** now shows that series with its
   progress bar, and the series button says **Continue episode N**. Tapping
   either picks up where you stopped.
8. **For You:** the feed now plays video. Swipe between series. Switching to
   another tab pauses it. **Watch all episodes** continues the same episode in
   the full player from the same moment.
9. **Data saver** (on by default, in Profile): plays a lower quality to use less
   data. You may notice the picture is softer; that is expected.
10. **Leaving the app** (home button) pauses the video; coming back resumes it.

Tell Claude anything that looks wrong, feels slow, or reads badly.

---

## Connecting the app to Supabase (Milestone 4)

Until these steps are done, the app runs on its built-in sample data, exactly
as before. Do them in order; each takes a few minutes.

**Safety rule:** Supabase shows two kinds of keys. The **publishable** key
(sometimes labelled **anon** or **public**) goes in the app. The **secret** key
(labelled **secret** or **service_role**) must never be put in the app, in
`env.json`, in Git, or sent in a chat.

### Step A: Create the Supabase project

1. Go to <https://supabase.com> and click **Start your project**. Sign in with
   your GitHub account.
2. Click **New project**. If asked, create an organization (any name, **Free**
   plan).
3. Fill in:
   - **Name:** `palava`
   - **Database password:** click **Generate a password**, then save it in a
     password manager. The app never needs it, but you may later.
   - **Region:** **West EU (London)**: closest to both Liberia and the UK/US
     diaspora.
4. Click **Create new project** and wait a minute or two until it is ready.

### Step B: Create the database tables

1. First get the latest code: in PowerShell, from the `palava` folder, run
   `git pull`.
2. In Supabase, click **SQL Editor** in the left menu, then **New query**.
3. On your computer, open
   `Documents\Gateway\palava\supabase\migrations\20260929000000_initial_schema.sql`
   with Notepad (right-click > Open with > Notepad). Press **Ctrl+A**, then
   **Ctrl+C**.
4. Click in the Supabase query box, press **Ctrl+V**, then click **Run**. You
   should see "Success. No rows returned".
5. Click **New query** again and do the same with
   `Documents\Gateway\palava\supabase\migrations\20260930000000_grant_app_access.sql`.
   This lets the app read the tables (newer Supabase projects do not allow it
   automatically).
6. Click **New query** again and do the same with
   `Documents\Gateway\palava\supabase\seed.sql`. This loads the sample series.
7. Check: click **Table Editor** in the left menu. You should see tables such
   as `series` (8 rows) and `episodes`.

### Step C: Connect the app

1. In Supabase, open **Project Settings** (gear icon) > **API Keys** (or **Data
   API**). Copy the **Project URL** and the **publishable / anon** key.
2. In PowerShell, from the `palava` folder:
   ```
   copy env.example.json env.json
   notepad env.json
   ```
3. Replace the two example values with your Project URL and publishable key,
   keeping the quote marks. Save and close Notepad. (`env.json` is kept out of
   Git automatically.)
4. Run the app with the new settings:
   ```
   flutter run -d 5A210DLCQ002B1 --dart-define-from-file=env.json
   ```
   From now on, always add `--dart-define-from-file=env.json`.

### Step D: Turn on phone sign-in

Phone codes are sent by text message through an SMS company that Supabase
connects to (for example **Twilio**). Texts to Liberia cost money per
message, so for testing use a free test number that never sends a text:

1. In Supabase: **Authentication** > **Sign In / Providers** > **Phone**, and
   turn on **Enable Phone provider**.
2. Supabase requires SMS company details before it will save. Until we pick a
   real SMS company, use these placeholders (they are not real accounts):
   - **SMS provider:** Twilio
   - **Twilio Account SID:** `AC00000000000000000000000000000000`
   - **Twilio Auth Token:** `placeholder`
   - **Twilio Message Service SID:** `MG00000000000000000000000000000000`
3. **SMS OTP Expiry:** `300` seconds (texts can arrive slowly).
4. **Test Phone Numbers and OTPs:** `231770000001=123456` (no `+`, no spaces).
5. **Test OTPs Valid Until:** a date a few months ahead. Test numbers stop
   working after this date, and Supabase then tries to send a real text,
   which fails with a Twilio "account does not exist" error.
6. Click **Save**, reopen **Phone**, and check everything stayed.

That number then signs in with the code `123456`. Real phone numbers will not
receive codes until a real SMS company is connected.

### Step E (later): Google and Apple sign-in

Google needs a Google Cloud account and Apple needs an Apple Developer
account (paid, yearly). Claude will walk you through these when you are
ready. Until then the app shows only phone sign-in.

## What to check on your phone (Milestone 4: backend)

With `env.json` in place (Step C):

1. The app opens with a short loading screen, then Welcome. The series are
   now coming from Supabase.
2. **Browse as a guest**, open a series and tap a locked episode (9 or
   later): the sheet now says **Sign in to unlock**.
3. Sign in: enter `770000001` after +231, tap **Send me a code**, enter
   `123456`. You land on Home.
4. **Profile** shows `+231 ** *** 001` and a Wallet with **45 coins** (the
   welcome coins, set in the `app_settings` table).
5. Unlock episode 9 with 30 coins. In Supabase **Table Editor** >
   `wallets`, your balance is now 15. Try unlocking another: the sheet says
   you do not have enough coins.
6. Add a series to **My List**, watch part of an episode, then close the app
   completely and open it again: you are still signed in, My List and
   Continue watching are still there.
7. **Log out**, then sign in again with the same number: everything comes
   back from the server.
8. Try changing something in Supabase, for example in **Table Editor** >
   `app_settings` set `unlock_cost_coins` to 20, or rename a `home_rows`
   title. Close and reopen the app: the change shows up without a new app
   build.

## Admin panel (Milestone 5)

A website for managing Palava without touching Supabase: series, episodes,
settings, coin packs, passes and Home rows. It runs in Chrome on your
computer, from the `palava\admin` folder, and uses the same `env.json`.

### One-time setup

1. **Allow admins in the database.** In PowerShell, from the `palava` folder:
   ```
   git pull
   notepad supabase\migrations\20261001000000_admin_access.sql
   ```
   Press Ctrl+A, Ctrl+C. In Supabase: **SQL Editor** > **New query**, paste,
   **Run**. Expect "Success. No rows returned". (PowerShell commands go in
   PowerShell; only the file's contents go in Supabase.)
2. **Create your admin login.** In Supabase: **Authentication** > **Users** >
   **Add user** > **Create new user**. Enter your email and a strong password,
   tick **Auto Confirm User**, and click **Create user**.
3. **Make that login an admin.** In Supabase: **SQL Editor** > **New query**,
   paste this with your email, and **Run**:
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'you@example.com';
   ```
   Expect "Success. 1 row" (or "No rows returned" if the email is wrong).

### Opening the admin panel

In PowerShell:
```
cd $HOME\Documents\Gateway\palava\admin
flutter run -d chrome --dart-define-from-file=../env.json
```
Chrome opens with the sign-in page. The first start takes a minute or two.
Press `q` in PowerShell to stop it.

### What to check (Milestone 5)

1. Sign in with your admin email and password. You see the 8 series.
2. **Series > New series:** create one (for example "Test Show"), leave it
   **Hidden**, click **Create series**. Then **Add episodes**: 3 episodes,
   length `75`, video link
   `https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8`.
3. On your phone the new series does not appear yet (it is hidden). Back in
   the admin panel, switch **Published** on and **Save changes**. Close and
   reopen the app: the series is there and its episodes play.
4. **Settings:** change **Coins to unlock an episode** to 20 and **Save
   settings**. Reopen the app: unlock buttons say 20 coins.
5. **Home rows:** create a row, add two series, save. Reopen the app: the
   row is on Home.
6. **Store:** add a coin pack with a price label such as `USD 1.99`. The
   Wallet shows it.

Videos: the admin panel takes a **video link** (an HLS `.m3u8` address) for
each episode. Uploading video files needs a video hosting account (Mux or
Cloudflare Stream), which turns uploads into data-saving streams; Claude will
add uploading once that account exists.

## Coins, passes, ads and test payments (Milestone 6)

### One-time setup

1. **Update the database.** In PowerShell, from the `palava` folder:
   ```
   git pull
   notepad supabase\migrations\20261002000000_monetization.sql
   ```
   Press Ctrl+A, Ctrl+C. In Supabase: **SQL Editor** > **New query**, paste,
   **Run**. Expect "Success. No rows returned". Safe to run again.
2. **Restart the admin panel** (press `q` in its PowerShell window, then run
   it again) so it shows the new **Purchases** page.
3. **Restart the app on your phone** (press `q`, then the usual
   `flutter run` command). The first build after this update takes longer:
   it downloads Google's ads library.

### How test payments work

When a viewer taps **Pay**, the app creates a purchase marked **Waiting** and
shows a reference such as `PAL-7F3A9C21`. Nothing is charged. On the admin
panel's **Purchases** page you click **Confirm**, and the viewer gets the
coins or the pass (they see it when they pull the Wallet down or come back
to the app). **Cancel** gives them nothing. In **Settings** > **Payments**
you can switch payments **Off**, which makes Pay say "Payments are not open
yet".

Later, a payment provider replaces the Confirm button: the viewer pays on
the provider's own page and the provider tells Supabase, which pays out
through the same code.

### What to check (Milestone 6)

Do these in this order: a pass unlocks everything, so test it last.

1. **Buy coins.** Wallet > **300** > **MTN Mobile Money** > **Pay**. A "Test
   payment started" box shows a reference. Under **Recent payments** it says
   **Waiting**, and your balance has not changed.
2. **Confirm it.** Admin panel > **Purchases**: the payment is at the top with
   your phone number. Click **Confirm**. On the phone, pull the Wallet down:
   the balance is 320 coins higher and the payment says **Paid**.
3. **Rewarded ad.** Open a locked episode (for example episode 12 of any
   series) and tap **Watch a short ad**. A Google test ad plays (it says
   "Test Ad"). Watch it to the end and close it: the episode unlocks and the
   count of free ads left goes down by one. Try again and close the ad early:
   the app says to watch the whole ad, and nothing unlocks.
4. **Auto-unlock.** Turn on **Auto-unlock next episodes** in the unlock
   sheet, close the app completely and reopen it: the switch is still on.
5. **Payments off.** Admin panel > **Settings** > **Payments** > **Off** >
   **Save settings**. On the phone, pull Home down, then try **Pay**: "Payments
   are not open yet". Switch it back to **Test mode** and save.
6. **Day pass.** Wallet > **Day pass** > **Pay**, then **Confirm** it in the
   admin panel. Pull the Wallet down: "Pass active ... until" shows the end
   time, and every episode plays without the unlock sheet for 24 hours.

### Accounts needed for real money and real ads

Nothing here is needed to keep building; test mode works without them.

- **Mobile money and cards:** an account with **Flutterwave** or **Paystack**.
  Before choosing, ask each one whether it can take payments from **MTN
  Mobile Money Liberia** and **Orange Money Liberia**, whether it can pay out
  to your business, and in which currencies. Both ask for business
  documents. Once the account exists, it gives *test keys* right away; the
  secret key goes into Supabase (**Edge Functions** > **Secrets**), never
  into `env.json`, Git or a chat.
- **App store purchases:** a **Google Play Console** developer account (a
  one-time fee), then a free **RevenueCat** account. Note that Google's rules
  generally require coins sold *inside* an Android app to go through Google
  Play billing, so check with Google Play's payments policy (or an adviser)
  how mobile money payments may be offered before launch.
- **Real rewarded ads:** a **Google AdMob** account (admob.google.com). Add
  the Palava Android app and create a **Rewarded** ad unit. AdMob then shows
  an **App ID** (with a `~`) and an **ad unit ID** (with a `/`). These are
  not secret. Put the App ID in `android/gradle.properties` as
  `admobAppId=...` and the ad unit ID in `env.json` as
  `"ADMOB_REWARDED_ID": "..."`. Before launch, AdMob's **Privacy &
  messaging** consent form is needed for viewers in the UK and Europe.

## For developers

- `lib/theme/`: colours, fonts and the app theme (brief: "fireside").
- `lib/data/`: data models and `sample_data.dart`. Business values (free
  episode count, unlock cost, ad limit, coin packs, passes, home rows) live in
  `AppConfig`, which will come from Supabase in Milestone 4.
- `lib/state/app_state.dart`: app state (wallet, My List, settings). Watch
  history, Data saver and Subtitles are saved on the phone.
- `lib/playback/`: the video player. `episode_feed.dart` is the vertical
  swipe list used by both For You and the series player (autoplay, preload
  only the next item after 10 seconds, pause when covered, resume, progress
  saving). `video_controllers.dart` creates players, applies Data saver
  (`AppConfig.dataSaverMaxBitrate`) and holds at most two players at a time.
  `watch_history.dart` stores where the viewer stopped.
- `lib/backend/`: `Backend` is everything the app asks of a server.
  `SampleBackend` fakes it on the phone (no `env.json`, and in tests);
  `SupabaseBackend` talks to Supabase. `AppState` holds the viewer's copy and
  never changes coins itself: unlocks go through database functions.
- `supabase/migrations/`: the database schema with row level security.
  `supabase/seed.sql`: sample content. `supabase/tests/run_tests.sh` checks the
  security rules on a plain PostgreSQL; `supabase/tests/run_api_tests.sh`
  runs `test/supabase_backend_test.dart` against PostgREST (the server
  Supabase uses).
- `admin/`: the admin panel (Flutter web). `admin/lib/api/admin_api.dart`
  talks to Supabase; `supabase/migrations/20261001000000_admin_access.sql`
  lets accounts in `public.admins` change the catalog. Tests:
  `cd admin && flutter test` (screens, with a fake server) and
  `supabase/tests/run_api_tests.sh` (against PostgREST).
- Monetization: `supabase/migrations/20261002000000_monetization.sql`.
  `start_purchase` creates a pending purchase; `complete_purchase` (not
  callable from the app) is the only place coins or passes are paid out.
  `app_settings.payment_mode` is `test` (admins confirm on the Purchases page
  via `admin_confirm_purchase`) or `off`. A provider webhook will call
  `complete_purchase` with the service role. Rewarded ads:
  `lib/ads/rewarded_ads.dart` (Google test ad unit unless
  `ADMOB_REWARDED_ID` is set; the Android app id comes from `admobAppId` in
  `android/gradle.properties`). Ad unlocks are still trusted from the app,
  limited per day on the server; AdMob server-side verification comes with
  the AdMob account.
- Sample episodes use Google's public HLS test streams and stop at 75 seconds
  (`Episode.endsAt`); sample WebVTT subtitles come from `sample_data.dart`.
- `lib/screens/`: one file per screen. `lib/widgets/`: shared pieces.
- `assets/fonts/`: Fraunces and DM Sans bundled (OFL licensed) so the app never
  downloads fonts over mobile data.
- Checks: `flutter analyze` and `flutter test`.
- Minimum Android version is 7.0 (API 24).
