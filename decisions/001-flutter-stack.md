# Decision: Flutter over native or web

Date: 2026-05-16
Status: accepted

## Context

The project owner (Yazan) is not a coder. We need maximum reach (iOS + Android,
ideally Web later) with minimum complexity, while supporting high-quality Arabic
text rendering and reliable offline audio.

## Options considered

1. **Flutter (Dart)** — One codebase, iOS + Android + Web. Strong Arabic text
   support. Excellent dev experience. Claude Code handles it well. Hot reload.
   Downsides: smaller talent pool than native; some platform-specific edges.

2. **Native iOS first (Swift)** — Best iOS-only quality. CarPlay, watch, widgets
   all easier. Downsides: doubles effort to reach Android; locks out 75% of the
   global Muslim user base on Android.

3. **Native both (Swift + Kotlin)** — Best quality on both. Downsides: literally
   2x the code, 2x the bugs, 2x the time. Wrong choice for a solo non-coder
   building with AI.

4. **React Native** — Cross-platform like Flutter. Downsides: Arabic text
   rendering historically weaker; audio packages less mature.

5. **Web first (Next.js, PWA)** — Fastest to ship. Downsides: no real offline
   audio, no app-store presence, no push notifications on iOS PWAs, weaker
   Arabic font rendering control.

## Decision

**Flutter.** Best balance of single codebase, Arabic rendering quality, and
LLM-assisted development. Web can be added later via `flutter run -d chrome`
once mobile is stable.

## Consequences

- All code in Dart.
- Use Flutter ecosystem packages (Riverpod, Drift, just_audio).
- Web build is a future bonus, not a goal for MVP.
- If Flutter ever blocks us on a critical native feature (CarPlay, Watch),
  we add a minimal native module via platform channels — we don't switch stacks.
