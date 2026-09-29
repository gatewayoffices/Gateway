# Palava

Original African micro-dramas: short vertical episodes that end on cliffhangers.
The project brief is in [CLAUDE.md](CLAUDE.md).

## Where we are

| Milestone | Status |
|---|---|
| 1. Project setup (Flutter app, Git, folders, theme) | Done |
| 2. Seven screens with sample data | Done |
| 3. Video player | Next |
| 4. Backend (Supabase) | Later |
| 5. Admin panel | Later |
| 6. Monetization and payments | Later |
| 7. Downloads, data saver, notifications | Later |

Everything you see is sample data. Buttons that need a later milestone (playing
video, real payments, downloads, sharing) show a short message saying so. Coins
you "buy" in the Wallet are pretend: no money moves.

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

## What to check on your phone (Milestone 2)

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

Tell Claude anything that looks wrong, feels slow, or reads badly.

---

## For developers

- `lib/theme/`: colours, fonts and the app theme (brief: "fireside").
- `lib/data/`: data models and `sample_data.dart`. Business values (free
  episode count, unlock cost, ad limit, coin packs, passes, home rows) live in
  `AppConfig`, which will come from Supabase in Milestone 4.
- `lib/state/app_state.dart`: in-memory state (wallet, My List, settings).
- `lib/screens/`: one file per screen. `lib/widgets/`: shared pieces.
- `assets/fonts/`: Fraunces and DM Sans bundled (OFL licensed) so the app never
  downloads fonts over mobile data.
- Checks: `flutter analyze` and `flutter test`.
- Minimum Android version is 7.0 (API 24).
