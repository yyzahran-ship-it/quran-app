# Quran App — A Better Quran Experience

> Working name. Rename anytime.

A Flutter-based Quran app focused on solving real gaps in existing apps:
multi-script Mushaf, letter-level tajweed feedback, true offline experience,
honest pricing, and a real memorization (hifz) engine with spaced repetition.

## What we're building (MVP scope)

**Phase 1 — Mushaf reader**
- Page-accurate Madinah Mushaf (15-line Uthmani)
- Verse-by-verse audio sync with multiple reciters
- Multiple translations, all offline
- Unlimited bookmarks with tags and dates
- Notes per ayah
- True inverted night mode + accessibility-first font scaling

**Phase 4 — Memorization engine**
- Spaced repetition (FSRS algorithm) tuned for ayah-level review
- Hide-words mode, progressive blur, audio-only recall
- Khatma planner with adaptive daily goals
- Listen-and-follow mode (no AI yet — Phase 3 later)

**Not in MVP** (deliberately, to ship something real):
- Tajweed AI (Phase 3 — needs ML data work, do it later)
- Halaqa/teacher mode (Phase 5)
- Shazam-for-Quran (Phase 6)

## How to work on this project

You don't code. Here's what you do:

1. **Open the terminal** (we'll set this up once).
2. **Run `claude`** in this folder.
3. **Tell Claude what to build next** in plain English.
4. **Test on your phone** via the QR code Flutter prints.
5. **Tell Claude what's wrong or what's next.**

That's the whole loop. The file `CLAUDE.md` in this folder is the project's
"constitution" — Claude reads it on every session so it always knows the goals,
the architecture, the principles, and what NOT to do.

## Data sources we're using

- **Quran text**: Tanzil.net (verified Uthmani + IndoPak)
- **Audio + verse timing**: Quran.com API (free, open)
- **Word-by-word + grammar**: Quranic Arabic Corpus (corpus.quran.com)
- **Translations**: Quran.com API (Sahih International, Pickthall, etc.)
- **Tafsir**: Quran.com API (Ibn Kathir, Sa'di, Jalalayn, Maarif-ul-Quran)

All of these are free and require no paid licensing for the MVP.

## Pricing principles (non-negotiable)

- **Free forever**: full Mushaf, all translations, all tafsir, all reciters,
  basic memorization, no ads ever.
- **Paid (later)**: advanced tajweed AI, teacher/halaqa mode, advanced
  hifz analytics. One-time purchase preferred over subscription.
- **Never** show a popup during reading. **Never** sell user data.
- **Never** paywall the Quran text itself or basic reading features.

## Next step

See `GETTING_STARTED.md` for the exact commands to set up Claude Code
and begin building.
