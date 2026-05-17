# Getting Started — Step by Step for Non-Coders

> Follow these in order. Each step is a single thing to do.
> If something fails, copy the error message and ask Claude.

## What you need before starting

- A computer (Mac, Windows, or Linux). Mac is best if you want to publish to iOS later, but not required now.
- A phone (iPhone or Android) for testing.
- About 20 GB of free disk space.
- A Google account (for free services we'll use later).

---

## Step 1: Install the basics

### On Mac
Open the **Terminal** app (press `Cmd + Space`, type "Terminal", press Enter). Paste these one at a time:

```bash
# Install Homebrew (the package manager)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Flutter
brew install --cask flutter

# Install Node.js (needed by Claude Code)
brew install node

# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Verify everything is installed
flutter doctor
claude --version
```

### On Windows
1. Install **Flutter** from `https://docs.flutter.dev/get-started/install/windows`
2. Install **Node.js** from `https://nodejs.org` (LTS version)
3. Open PowerShell and run:
```powershell
npm install -g @anthropic-ai/claude-code
flutter doctor
claude --version
```

### On Linux
```bash
# Install Flutter via snap
sudo snap install flutter --classic

# Install Node.js
sudo apt install nodejs npm

# Install Claude Code
sudo npm install -g @anthropic-ai/claude-code

flutter doctor
claude --version
```

**Important**: Run `flutter doctor` and follow whatever it tells you is missing. It will guide you through installing Android Studio and iOS tools (Mac only).

---

## Step 2: Set up Claude Code

Run this in any terminal:

```bash
claude
```

It will ask you to log in (opens a browser). Use your Anthropic account.

---

## Step 3: Create the project folder

```bash
# Go to where you want the project (Documents folder is fine)
cd ~/Documents

# Create the project folder
mkdir quran-app
cd quran-app

# Initialize git (for version history)
git init
```

---

## Step 4: Drop the starter files into the folder

Copy these files (provided to you separately) into `~/Documents/quran-app/`:

- `README.md`
- `CLAUDE.md`
- `GETTING_STARTED.md` (this file)
- `TODO.md`
- `PROGRESS.md`
- `.gitignore`
- `decisions/` folder

---

## Step 5: Start Claude Code in the project

```bash
cd ~/Documents/quran-app
claude
```

You'll see a prompt. This is where you talk to Claude.

---

## Step 6: Your first prompt to Claude Code

Paste this exactly:

```
Read CLAUDE.md and README.md carefully. Then do the following:

1. Run `flutter create . --org com.quranapp --project-name quran_app` to scaffold a Flutter project in this folder.
2. Set up the folder structure described in CLAUDE.md (lib/core, lib/data, lib/domain, lib/features/*, lib/shared).
3. Add these dependencies to pubspec.yaml: flutter_riverpod, drift, drift_flutter, just_audio, just_audio_background, dio, path_provider, shared_preferences.
4. Create a PROGRESS.md file and log what you did.
5. Run `flutter pub get` and confirm it builds with `flutter build apk --debug` (or `flutter build ios --debug --no-codesign` on Mac).
6. Tell me what's done and what to do next.

Do not start building features yet. We're just setting up the foundation.
```

Claude will work through this. It might ask permission to run commands — say yes.

**This will take 10-20 minutes.** Mostly Flutter downloading things.

---

## Step 7: Test that it runs on your phone

After Step 6 finishes:

### Android
1. Enable Developer Mode on your phone (Settings → About phone → tap "Build number" 7 times).
2. Enable USB debugging (Settings → Developer options).
3. Connect phone to computer via USB.
4. In terminal, run: `flutter devices` — your phone should show.
5. Tell Claude: `Run the app on my Android phone`.

### iPhone (Mac only)
1. Connect iPhone to Mac.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. Sign in with your Apple ID under Signing & Capabilities.
4. Tell Claude: `Run the app on my iPhone`.

You'll see a default Flutter "counter" app. That's normal. Next session we replace it.

---

## Step 8: Your second prompt — start the real work

```
Read CLAUDE.md and PROGRESS.md. Now let's start Phase 1, Task 1:

Build the data layer for Quran text. Specifically:
1. Download the Tanzil Uthmani simple text file and bundle it as an asset.
2. Create a Drift database with tables: surahs, ayahs, juzs.
3. Write a seed function that imports the Tanzil text into the database on first launch.
4. Create a QuranRepository in lib/data/ with methods: getSurah(int number), getAyah(int surah, int ayah), getJuz(int number).
5. Write unit tests for the repository.
6. Update PROGRESS.md and TODO.md.

Show me sample output of getSurah(1) when you're done.
```

From this point on, you have a working loop. You give Claude one task at a time, it builds it, you test, you give the next task.

---

## Daily workflow once set up

```bash
cd ~/Documents/quran-app
claude
```

Then tell Claude what to work on. Reference `TODO.md` to see what's next.

When something breaks on your phone, screenshot it and describe it. Claude can read screenshots if you share the file path.

---

## Backup and version history

After every working session, tell Claude:

```
Commit the changes with a clear message and push to GitHub.
```

You'll need a free GitHub account (`github.com`). Claude will walk you through connecting it the first time.

---

## When you're stuck

- **Error you don't understand**: paste it into Claude. That's literally what it's for.
- **App won't run**: tell Claude `flutter doctor` and `flutter run` errors, exactly as they appear.
- **Don't know what to build next**: ask Claude `What's the next sensible task based on TODO.md and PROGRESS.md?`
- **Want to change direction**: edit CLAUDE.md (or ask Claude to). The constitution is yours.

---

## What success looks like at end of Week 1

- App runs on your phone.
- Opens to Surah Al-Fatihah, rendered in the proper Madinah Mushaf font.
- You can scroll/swipe between pages.
- One reciter plays verse-by-verse with text highlighting.
- One translation toggles on/off.

That's it. We don't need more in Week 1. Each week after, we add one big thing.
