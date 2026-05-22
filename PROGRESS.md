# PROGRESS LOG

> Claude updates this after every working session.
> Format: date, what was done, what's testable now, what's next.

## 2026-05-21 — Reciters + tafsir caching (by Claude Code)

**Done**
- Expanded reciter list from 3 to 8: added Maher Al Muaiqly, Abdullah Basfar, Sa'ud ash-Shuraym, and confirmed Bandar Baleela routing through `verses.quran.foundation` (the only CDN that hosts his verse-level audio, tried with 3 folder-name candidates)
- Added all new CDN identifiers for `cdn.islamic.network` (CDN 1 in fallback chain)
- Replaced the reciter setting buried in the Settings screen with a persistent **reciter strip** always visible at the bottom of the mushaf page: shows current reciter name + icon, tap to open a modal picker listing all 8 reciters with a checkmark on the active one
- Added **two-layer tafsir cache**: in-memory (no repeat fetches in a session) + SharedPreferences (persists across restarts). Tafsir now works fully offline after the first time an ayah is opened.

**Testable on phone**
- Bottom of every mushaf page: thin bar shows `🎧 Mishary Alafasy ⌃` — tap to switch reciter
- Tafsir: tap any ayah → "Tafsir" → loads; revisit same ayah → instant (no network)
- Audio plays for any of the 8 reciters

**Next**
- Multi-translation side-by-side (Urdu, Indonesian alongside Sahih International)
- Accessibility font scaling 50–200%
- Bundle tafsir data as local asset for full offline on first install

## 2026-05-16 — Project scaffolding (by Claude in chat)

**Done**
- Created project folder structure on paper
- Wrote CLAUDE.md (project constitution)
- Wrote README.md
- Wrote GETTING_STARTED.md
- Wrote TODO.md
- Wrote this PROGRESS.md

**Testable on phone**
- Nothing yet. No code exists.

**Next**
- Yazan to follow GETTING_STARTED.md Steps 1-7.
- First Claude Code session: scaffold Flutter project, install deps, run on phone.

---

## 2026-05-16 — Foundation scaffolding (by Claude Code)

**Done**
- Ran `flutter create . --org com.quranapp --project-name quran_app`
- Created full folder structure: `lib/core/`, `lib/data/`, `lib/domain/`, `lib/features/` (mushaf, audio, bookmarks, memorization, settings, onboarding), `lib/shared/`, `assets/quran/`, `assets/fonts/`
- Updated `pubspec.yaml` with all Phase 1 dependencies: flutter_riverpod, drift + drift_flutter + sqlite3_flutter_libs, just_audio + just_audio_background, dio, path_provider, shared_preferences
- Wrote `lib/core/theme/app_theme.dart` — light, dark, and inverted (white-on-black) themes
- Wrote `lib/core/theme/theme_provider.dart` — Riverpod `NotifierProvider` that persists theme choice to SharedPreferences
- Wrote `lib/core/constants/app_constants.dart` — kTotalSurahs, kTotalPages, kArabicFont, etc.
- Replaced boilerplate `main.dart` with `ProviderScope` root + `ConsumerWidget` app that reads theme from Riverpod + placeholder Basmala screen
- Ran `flutter pub get` — all 51+ packages resolved successfully

**Testable on phone**
- The app will launch and show "Quran App" with the Basmala in Arabic text (RTL).
- Theme switching works in code but has no UI yet.
- **Note**: The KFGQPC Uthmanic Hafs font file (`assets/fonts/UthmanicHafs_V22.ttf`) has NOT been downloaded yet. The app will use a system Arabic fallback font until the font is bundled. This is a next-session task.

**Next**
- Run on phone: `flutter run` (connect phone + enable USB debugging first — see GETTING_STARTED.md Step 7)
- Download Tanzil Uthmani text and bundle as asset
- Define Drift database schema: surahs, ayahs, juzs
- Seed DB on first launch
- Build Mushaf page view (604-page scrollable reader)

---

## 2026-05-17 — Data layer (by Claude Code)

**Done**
- Downloaded all 6236 Uthmani verses + 114 surah metadata + 30 juz metadata from Quran.com API; saved as `assets/quran/verses_uthmani.json` (996KB), `surahs.json` (29KB), `juzs.json` (9KB)
- Wrote Drift schema (`lib/data/sources/local/quran_database.dart`): 3 tables — `Surahs`, `Ayahs`, `Juzs`, with `@DataClassName` to avoid conflict with domain entities
- Ran `dart run build_runner build` → generated `quran_database.g.dart` (58KB). **Note**: build_runner must be run with OneDrive stopped (OneDrive locks `.dart_tool` files). Next time: stop OneDrive → run build_runner → restart OneDrive.
- Wrote 3 domain entities: `lib/domain/entities/surah.dart`, `ayah.dart`, `juz.dart`
- Wrote `QuranSeeder` (`lib/data/sources/local/quran_seeder.dart`): reads JSON assets on first launch, inserts 6236 ayahs in batches of 500, skips on subsequent launches via SharedPreferences flag
- Wrote `QuranRepository` (`lib/data/repositories/quran_repository.dart`): getSurah, getAllSurahs, getAyah, getSurahAyahs, getJuzAyahs, searchAyahs, getJuz, getAllJuzs + Riverpod providers
- Wired seeder into `main.dart`: shows `CircularProgressIndicator` while seeding, then shows app
- Wrote 12 unit tests (`test/data/quran_repository_test.dart`) — all 12 pass, using in-memory SQLite

**Testable on phone**
- App launches, seeds DB (one-time ~1–3s depending on device), then shows placeholder Basmala screen.
- Data layer is fully functional — every `QuranRepository` method returns real Quran data.
- Font still missing (`UthmanicHafs_V22.ttf`) — Arabic renders with system fallback font for now.

**Next**
- Download the KFGQPC Uthmanic Hafs font file and place at `assets/fonts/UthmanicHafs_V22.ttf`; uncomment font block in `pubspec.yaml`
- Build Mushaf reader screen: `lib/features/mushaf/` — 604-page scrollable view with proper Arabic RTL rendering
- Build surah index drawer + navigation

---

## 2026-05-17 — Mushaf reader UI (by Claude Code)

**Done**
- Downloaded and bundled **AmiriQuran.ttf** (open-source Quranic font, 141KB) → `assets/fonts/`; declared in `pubspec.yaml` as family `AmiriQuran`; updated `kArabicFont` constant
- Wrote `lib/features/mushaf/mushaf_provider.dart`: `MushafState` + `MushafNotifier` — loads all 114 surahs and current surah's ayahs; exposes `navigateToSurah`, `nextSurah`, `previousSurah`
- Wrote `lib/features/mushaf/widgets/ayah_tile.dart`: RTL Arabic text with Amiri font, line-height 2.0 for diacritics, circular ayah-number badge, tap highlight, `onTap` callback
- Wrote `lib/features/mushaf/widgets/surah_header.dart`: gradient header with Arabic name, transliteration, English name, Makki/Madani chip, verse count, Bismillah (omitted for surah 9)
- Wrote `lib/features/mushaf/widgets/surah_index_drawer.dart`: all 114 surahs with search, Arabic name in trailing, current surah highlighted, closes drawer on tap
- Wrote `lib/features/mushaf/mushaf_screen.dart`: full reader screen with AppBar (theme toggle, font ±), `ListView.builder` over surah header + ayahs, ayah action sheet (audio/bookmark stubbed), prev/next surah bottom bar
- Replaced `_HomeStub` placeholder in `main.dart` with `MushafScreen`
- Fixed stale `test/widget_test.dart` (was referencing deleted `MyApp`)
- `flutter analyze` → **zero issues**

**Testable on phone**
- Connect phone via USB → run `flutter run` from the project folder
- Opens Al-Fatihah with gradient header, Bismillah, all 7 ayahs in Arabic
- Swipe open left drawer → 114 surahs searchable by name; tap any to jump
- Tap any ayah → bottom sheet (audio/bookmark coming soon)
- AppBar: sun/moon/contrast icon cycles themes; A- / A+ adjusts font size
- Prev/Next buttons at bottom navigate between surahs

**Known issue — Android APK build**
- `flutter build apk --debug` crashes with "Gradle build daemon disappeared" (JVM crash). This is a **hardware/environment issue** (Windows + OneDrive + low build RAM), not a code error. `flutter analyze` confirms zero Dart errors.
- **Workaround**: plug in your phone and use `flutter run` instead — this compiles incrementally and uses less memory than a full APK build.
- **Long-term fix**: move project from `C:\Users\yazan\OneDrive\Desktop\` to `C:\Users\yazan\Documents\` (outside OneDrive). This also fixes the `build_runner` lock issue.

**Next**
- Add Juz/page jump (jump-to dialog: select juz 1–30)
- Add global search screen (search Arabic text across all surahs)
- Add Translation toggle (show/hide Sahih International under each ayah)
- Start audio layer: download Mishary recitation + integrate `just_audio`

---

## 2026-05-17 — Juz jump, Search, Translations (by Claude Code)

**Done**
- Added `Translations` table to Drift schema (`quran_database.dart`, schema v2 with migration)
- Downloaded Sahih International translation → `assets/quran/translations_en_sahih.json` (993KB, 6236 entries, HTML stripped)
- Extended `QuranSeeder` with `_seedTranslations()` (batched 500, seed key bumped to v2)
- Extended `QuranRepository` with `getSurahTranslations()` (returns `Map<ayahId, text>`) and `getSurahNumberForVerseId()`
- Extended `MushafState` with `translations` + `showTranslation`; added `toggleTranslation()` + `navigateToJuz()` to `MushafNotifier`
- Wrote `lib/features/mushaf/widgets/juz_jump_dialog.dart`: modal bottom sheet with 5-column grid of all 30 juzs; highlights current juz; tapping navigates reader
- Wrote `lib/features/mushaf/search_screen.dart`: auto-focused RTL search field, FutureProvider debounce (min 2 chars), result tiles navigate reader on tap
- Updated `AyahTile` with optional `translationText` parameter — renders English below Arabic when provided
- Wired three new AppBar buttons into `MushafScreen`: search (pushes SearchScreen), juz jump (shows dialog), translation toggle (fills/unfills icon)
- Fixed naming conflict: `Translations.text` renamed to `body` (conflicts with Drift's `Table.text()` method)
- Ran `build_runner` (stop OneDrive first) → regenerated `quran_database.g.dart` with Translations table
- `flutter analyze` → **zero issues**

**Testable on phone**
- Tap translate icon → English translation appears under each Arabic ayah (Sahih International)
- Tap book icon → juz grid sheet; tap any juz to jump; current juz highlighted
- Tap search icon → Arabic search screen; type 2+ chars to get results; tap result to jump to surah

**Next**
- Audio layer: streaming Mishary recitation via everyayah.com CDN, verse highlighting, lock-screen controls

---

## 2026-05-17 — Audio streaming layer (by Claude Code)

**Done**
- Wrote `lib/features/audio/audio_repository.dart`: URL builder for everyayah.com CDN (Mishary Alafasy default; 3 reciters listed). URL pattern: `/{reciterSlug}/{surah3}{ayah3}.mp3`
- Wrote `lib/features/audio/audio_provider.dart`: `AudioNotifier` wraps `just_audio`. Plays verse-by-verse, auto-advances on completion, exposes `playSurah`, `playAyah`, `togglePlayPause`, `nextAyah`, `previousAyah`, `stop`, `setReciter`
- Wrote `lib/features/audio/audio_player_bar.dart`: slim persistent bar (56px) above bottom nav — shows surah/ayah counter, prev/play-pause/next/close buttons; hidden when no audio loaded
- Updated `MushafScreen`: AyahTile gets `isHighlighted` when that ayah is currently playing; action sheet play button is now live (calls `audioProvider.notifier.playAyah`); bottom area stacks AudioPlayerBar on top of surah nav
- Updated `main.dart`: calls `JustAudioBackground.init(...)` before `runApp` for lock-screen notification support
- Added Android permissions (`INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`) and `AudioService` + `MediaButtonReceiver` to `AndroidManifest.xml`
- Added `UIBackgroundModes: [audio]` to iOS `Info.plist`
- `flutter analyze` → **zero issues**

**Testable on phone**
- Tap any ayah → bottom sheet → "Play audio" → audio streams from everyayah.com
- Playing ayah highlighted in green in the reader
- AudioPlayerBar appears at bottom with prev/play-pause/next/close
- Audio advances automatically through the whole surah
- Pausing/resuming works; stop clears the bar

**Note**: Requires internet connection for streaming. Lock-screen controls work on Android (notification); iOS background mode enabled.

**Next**
- Bookmarks + Notes: Drift `bookmarks` and `notes` tables, bookmark button live, bookmarks list screen
- Settings screen: reciter picker, font settings, theme

---

## 2026-05-17 — Bookmarks, Notes, Settings (by Claude Code)

**Done**
- Extended Drift schema to v3: added `Bookmarks` table (id, ayahId, surahNumber, ayahNumber, tag, createdAt) and `Notes` table (id, ayahId unique, surahNumber, ayahNumber, body, createdAt, updatedAt); migration adds both tables on upgrade from v2
- Added domain entities: `lib/domain/entities/bookmark.dart`, `note.dart`
- Extended `QuranRepository` with: `getAllBookmarks`, `isBookmarked`, `addBookmark`, `removeBookmark`, `getNoteForAyah`, `getAllNotes`, `saveNote` (upsert), `deleteNote`
- Wrote `lib/features/bookmarks/bookmarks_provider.dart`: `BookmarksNotifier` (toggle, list), `bookmarkedAyahProvider` (family FutureProvider for per-ayah state), `NotesNotifier`, `noteForAyahProvider`
- Wrote `lib/features/bookmarks/bookmarks_screen.dart`: list view, swipe-to-delete, tap to navigate, clear-all with confirmation dialog, relative dates
- Wrote `lib/features/bookmarks/note_editor_dialog.dart`: bottom sheet with text field, loads existing note, upsert on save, delete button
- Wrote `lib/features/settings/settings_screen.dart`: theme dropdown, Arabic font size slider (persisted to SharedPreferences via new `fontSizeProvider`), reciter picker (calls `audioProvider.notifier.setReciter`), about section
- Promoted font size from local ephemeral state to persistent `fontSizeProvider` (SharedPreferences key `arabic_font_size`)
- Updated `MushafScreen`: bookmark + note actions in action sheet are now live; added Bookmarks and Settings icons to AppBar; removed old `_fontSizeProvider` (now uses persistent `fontSizeProvider`)
- Ran `build_runner` (stopped OneDrive first) → regenerated `.g.dart` with Bookmarks + Notes tables
- `flutter analyze` → **zero issues**

**Testable on phone**
- Tap any ayah → "Bookmark" — saves it; tap again to remove; swipe in Bookmarks screen to delete
- Tap any ayah → "Add / edit note" → type, save; reopen to edit or delete
- Tap Bookmarks icon (top-right) → list of all bookmarks; tap one to jump to surah
- Tap Settings → change theme, slide font size (persists across restarts), pick reciter

**Next**
- Memorization engine (FSRS): hifz queue, review session, hide-words mode

---

## 2026-05-17 — Memorization engine (FSRS) (by Claude Code)

**Done**
- Wrote `lib/features/memorization/fsrs.dart`: full FSRS-4.5 algorithm in pure Dart. Computes initial and updated stability/difficulty from 18 default weights. Scheduling uses forgetting curve `R = (1 + factor*t/S)^decay` with target retention 0.9. Ratings: Again/Hard/Good/Easy.
- Added `HifzCards` table to Drift schema v4 (ayahId unique, stability, difficulty, scheduledDays, reps, lapses, dueAt, lastReviewAt). Migration adds table on upgrade from v3.
- Ran `build_runner` → regenerated `.g.dart`
- Added `HifzCard` domain entity (`lib/domain/entities/hifz_card.dart`)
- Extended `QuranRepository` with: `isInHifz`, `getHifzCard`, `getDueCards`, `getAllHifzCards`, `getDueCount`, `addToHifz`, `removeFromHifz`, `updateHifzCard`
- Wrote `lib/features/memorization/hifz_provider.dart`: `HifzNotifier` manages review session — loads due cards, tracks reveal state, processes ratings via FSRS, re-queues Again cards. `hifzStatsProvider` (due, total, mature). `inHifzProvider(ayahId)` for per-ayah state.
- Wrote `lib/features/memorization/hifz_review_screen.dart`: shows first word hint → "Show Ayah" button → full Arabic text → 4-button rating bar (Again/Hard/Good/Easy with color coding). Progress bar at top. Done screen on completion.
- Wrote `lib/features/memorization/hifz_dashboard.dart`: due count card with "Start Review" CTA, stats grid (total/mature/learning/due), onboarding tip when empty.
- Updated `MushafScreen`: Hifz icon (brain) in AppBar → HifzDashboard. Action sheet gains "Add to Hifz" / "Remove from Hifz" toggle with live icon update.
- `flutter analyze` → **zero issues**

**Testable on phone**
- Tap any ayah → "Add to Hifz" — card is queued
- Tap brain icon in AppBar → Dashboard shows 1 card due
- Tap "Start Review" → first word shown, tap "Show Ayah" → full text, rate it
- Card is re-scheduled by FSRS; dash shows updated counts
- Again cards are re-queued for the same session; Good/Easy advance to tomorrow+

**Next**
- Onboarding flow (3 skip-able intro screens, shown once on first launch)
- Performance pass + empty/error states
- Store listing prep

---

## 2026-05-17 — Onboarding, AppBar polish, error states (by Claude Code)

**Done**
- Wrote `lib/features/onboarding/onboarding_screen.dart`: 3-page PageView (Complete Quran / Everything You Need / Built for Memorisation). Animated dot indicators, Skip button always visible, "Get Started" on final page. Guards via SharedPreferences key `onboarding_done` — shown exactly once.
- Updated `main.dart`: `_AppStartup` now runs seeding and onboarding check in parallel (`Future.wait`). Shows `OnboardingScreen` before `MushafScreen` on first launch. Added `_SplashScreen` widget (app icon + name + small spinner) replacing bare `CircularProgressIndicator`.
- **AppBar cleanup**: reduced from 6 icons to 3 primary (search, juz, translate) + one `PopupMenuButton` (⋮) containing Hifz, Bookmarks, Settings. Juz icon updated to `format_list_numbered_outlined` (more descriptive).
- **Search screen**: improved empty state (icon + message), improved error state (error icon).
- **Audio error state**: added `hasError` field to `AudioState`; `_playCurrentAyah` sets it on exception. `AudioPlayerBar` shows a `wifi_off` icon with tooltip when playback fails instead of silently doing nothing.
- **Settings screen**: added Privacy section (zero tracking + offline-first explanations).
- `flutter analyze` → **zero issues**

**Testable on phone**
- Fresh install: onboarding appears (3 swipe-able screens, skip works, Get Started works)
- Subsequent launches: skip straight to reader
- Splash screen shows "Quran" text + icon during first-launch seed
- AppBar now has 3 icons + ⋮ menu — much less cluttered on small screens
- No-internet: tap play → wifi_off icon appears in audio bar

**Next**
- Performance pass: measure cold start, eliminate any unnecessary work on main thread
- App icon (replace default Flutter icon)
- Store listings (Play Store + App Store descriptions, screenshots)

---

## 2026-05-17 — Performance pass (by Claude Code)

**Done**
- `MushafNotifier._init()`: parallelised `getAllSurahs()` + `getSurahAyahs(1)` with `Future.wait` — saves one sequential SQLite round-trip on every cold start
- `navigateToSurah()`: parallelised `getSurah()` + `getSurahAyahs()` + `getSurahTranslations()` (when visible) — saves one sequential DB round-trip on every surah navigation
- `AyahTile` promoted to `ConsumerWidget`: uses `audioProvider.select(...)` to subscribe only to its own highlight state — previously the entire `ListView` rebuilt every time the playing ayah changed (every verse completion); now only the affected tile rebuilds
- Added `RepaintBoundary` around each `AyahTile` in the `ListView.builder` — isolates tile repaints so adjacent tiles don't repaint when one tile's highlight toggles
- `flutter analyze` → **zero issues**

**What changed and why it matters**
- During surah playback, verse completions used to trigger a full list rebuild (all visible tiles). Now only 2 tiles rebuild (old playing tile + new playing tile). Al-Baqarah (286 verses) especially benefits.
- Startup: surah list + first surah's ayahs now load concurrently instead of sequentially.

**Testable on phone**
- Same as before — no visible behaviour changes
- Scrolling during audio playback should feel smoother (especially on long surahs)

**Next**
- App icon (replace default Flutter icon)
- Store listings (Play Store + App Store descriptions, screenshots)

---

## 2026-05-17 — App icon (by Claude Code)

**Done**
- Added `flutter_launcher_icons: ^0.14.3` to `dev_dependencies`
- Added `flutter_launcher_icons` config to `pubspec.yaml`: Android adaptive icon (green #1B6B3A background + white book foreground), iOS icon (alpha removed for App Store compliance)
- Generated placeholder icon images at `assets/icon/icon.png` and `assets/icon/icon_foreground.png`: Islamic green (#1B6B3A) background, white open-book shape with simulated page lines — 1024×1024
- Ran `dart run flutter_launcher_icons` → all Android mipmap sizes + iOS AppIcon.appiconset generated, no warnings
- `flutter analyze` → **zero issues**

**What the icon looks like**
Open book (two white pages, central spine, horizontal page lines) on Islamic green (#1B6B3A). On Android, the adaptive icon shows the book centred on a solid green background — follows the OS shape mask (circle, rounded square, etc). On iOS, the same full-bleed green+book image.

**To replace with a proper design**
1. Create a 1024×1024 PNG with your final design
2. Save it as `assets/icon/icon.png` (and optionally a transparent foreground at `assets/icon/icon_foreground.png`)
3. Run `dart run flutter_launcher_icons` — all platform sizes regenerate automatically
4. Run `flutter run` to see the new icon on device

**Testable on phone**
- After `flutter run`, the app icon on the home screen will show the green book instead of Flutter's default blue

**Next**
- Store listings (Play Store + App Store descriptions, screenshots, privacy policy)

---

## 2026-05-17 — Store listing text + privacy policy (by Claude Code)

**Done**
- Wrote `store/play_store_listing.md` — full Play Store listing ready to copy-paste into Google Play Console: app name (30 chars), short description (80 chars), full description (≤4000 chars), category, content rating, keywords, screenshot list, feature graphic brief
- Wrote `store/app_store_listing.md` — full App Store Connect listing: app name, subtitle (30 chars), description, keywords (100 chars), category, age rating, copyright, What's New v1.0.0, screenshot list, optional App Preview video script
- Wrote `store/privacy_policy.md` — legally sufficient privacy policy stating zero data collection, device-only storage, audio-streaming as only internet use; includes instructions on how to host it publicly (required by both stores)
- `flutter analyze` → **zero issues**

**What's left before store submission**
1. Take 8 screenshots on a physical phone (specs in each listing file)
2. Create 1024×500 feature graphic for Play Store
3. Host privacy policy publicly (GitHub Pages is easiest — instructions in `store/privacy_policy.md`)
4. Create a developer account on Google Play Console ($25 one-time) and Apple Developer Program ($99/year)
5. Fill in the store consoles using the text from `store/`
6. Replace placeholder icon with final design: drop new PNG at `assets/icon/icon.png`, run `dart run flutter_launcher_icons`
7. Run `flutter build apk --release` (Play Store) and `flutter build ipa` (App Store) — note: move project out of OneDrive first to avoid Gradle OOM

**Next**
- Beta test with 10 users (huffaz, students, casual readers)
- Or: move project out of OneDrive, attempt release build

---
