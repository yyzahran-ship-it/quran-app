# CLAUDE.md — Project Constitution

> **Read this first, every session.** This file defines what we're building,
> why, and how. Update it as decisions change, but never violate it.

## Project identity

- **Working name**: Quran App (pick a real name later)
- **Owner**: Yazan
- **Stack**: Flutter (Dart) — iOS, Android, Web from one codebase
- **State**: Pre-MVP. We are building Phase 1 (Mushaf) + Phase 4 (Memorization).

## Why this project exists

Existing Quran apps fail users in measurable ways. Our research identified
13 specific gaps. We are solving these in this order:

1. **Multi-script Mushaf** — Uthmani 15-line, IndoPak 13/15/16-line, Naskh. (Tarteel admits it can't do this.)
2. **True offline** — translations and tafsir bundled, no re-downloads.
3. **Honest pricing** — no ads ever, no popups during reading, free Mushaf forever.
4. **Real memorization engine** — spaced repetition (FSRS), not just A-B loop.
5. **Accessibility from day one** — inverted night mode, font scaling, dyslexia option.
6. **Unlimited bookmarks with dates and tags** — Ayah's 4-bookmark limit is a gap.
7. **Multi-tafsir side-by-side** — no major app does this.

Features deferred (DO NOT BUILD YET):
- Letter-level tajweed AI (Phase 3, needs ML + data)
- Halaqa/teacher mode (Phase 5)
- Shazam-for-Quran (Phase 6)
- Live khutbah translation (Phase 6)

## Architecture decisions

### Stack
- **Frontend**: Flutter (Dart), latest stable channel
- **State management**: Riverpod (cleaner than Provider for this size)
- **Local DB**: Drift (SQLite wrapper, type-safe, fast)
- **Audio**: `just_audio` + `just_audio_background` for lock-screen control
- **Arabic text**: KFGQPC Uthmanic Hafs font, rendered as SVG glyphs where needed for page-accuracy
- **HTTP**: `dio` with retry + offline cache
- **Backend (later)**: Postgres + minimal Dart backend on Cloud Run. Not needed for MVP.

### Data layer
- **Bundled at install** (offline-first):
  - Full Quran text (Uthmani + IndoPak), verse metadata, surah info
  - 2-3 default translations (Sahih International + Urdu + Indonesian)
  - 1 default reciter audio (Mishary Alafasy, verse-by-verse, ~500MB compressed)
- **Downloaded on demand**:
  - Additional reciters, translations, tafsirs
  - Show download size clearly, allow Wi-Fi-only setting

### Data sources
- **Text**: Tanzil.net (`https://tanzil.net/download/`) — verified, free
- **Audio + timing**: Quran.com API (`https://api.quran.com/api/v4`)
- **Grammar/i'rab**: Quranic Arabic Corpus (corpus.quran.com)
- **All free, no paid licensing required for MVP**

### Folder structure

```
lib/
  core/           # constants, theme, utilities, error handling
  data/           # repositories, API clients, local DB schema
  domain/         # entities, use cases (business logic)
  features/
    mushaf/       # Quran reader
    audio/        # playback engine
    bookmarks/    # bookmarks + notes
    memorization/ # SRS engine, hifz queues
    settings/     # preferences
    onboarding/   # first-run experience
  shared/         # widgets used across features
main.dart
```

## Coding principles

### Hard rules
- **NEVER** ship a build that paywalls Quran text, basic reading, or basic audio.
- **NEVER** add tracking SDKs (Firebase Analytics, Mixpanel, etc.). Crash reporting (Sentry) is OK if user opts in.
- **NEVER** show a subscription popup on app launch. Period.
- **NEVER** modify the Quran text. Use only verified sources (Tanzil, Quran.com).
- **NEVER** commit API keys to git. Use `--dart-define` for secrets.

### Soft rules
- **Offline-first**: every feature must work without internet, except live downloads.
- **Accessibility**: every screen must support font scaling 50%-200% and inverted night mode.
- **Performance budget**: cold start under 2s, page swipe under 16ms (60fps).
- **Test coverage**: aim for >70% on `domain/` and `data/` layers. UI tests for critical flows (reading, bookmarking, SRS review).
- **Comments in code**: Arabic terminology should be explained inline (e.g. `// ayah = verse, surah = chapter, juz = 1/30 of Quran`).

### File and code style
- Use `dart format` on every save.
- Use `flutter_lints` strictly.
- One feature per folder under `features/`. Don't mix concerns.
- Keep widgets small. If a build method exceeds 80 lines, refactor.
- Use named parameters for anything with more than 2 args.

## What to do when starting a session

1. Read this file (CLAUDE.md).
2. Read `PROGRESS.md` to see what was last done.
3. Read the latest entry in `decisions/` if any.
4. Ask Yazan what to work on, or pick the next item from `TODO.md`.
5. After finishing a task, update `PROGRESS.md` with what changed.

## Communication style with Yazan

- Yazan is not a coder. Explain things in plain English when relevant.
- When proposing a technical choice, give a one-line "why" Yazan can understand.
- When something is broken, explain what failed, what you'll try next, and how long it'll take.
- Don't ask for permission for tiny things (formatting, renames). Ask for big things (adding dependencies, changing architecture, adding a paid service).
- When showing progress, mention what's testable on the phone right now.

## When stuck

If you can't decide between two valid approaches, write both into `decisions/NNN-topic.md` with the trade-offs and ask Yazan to pick.

If a library or API behaves unexpectedly, search the web before guessing. Cite the source in code comments.

If you need real Quran data examples (an ayah, a surah structure, a tafsir excerpt), fetch from the Quran.com API rather than typing it from memory.
