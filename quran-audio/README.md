# quran-audio

Standalone Android Kotlin library module for Quran audio playback and download management.

## Architecture

Clean Architecture with three layers:

```
domain/          — pure Kotlin models, repository interfaces, use cases
data/            — Room DB, Retrofit API client, repository implementations
playback/        — ExoPlayer service, queue manager, gapless timing helper
di/              — Hilt modules wiring everything together
QuranAudioPlayer — public facade (single entry point for consumers)
```

## Tech stack

| Concern | Library |
|---------|---------|
| Playback | Media3 ExoPlayer |
| Notifications | Media3 PlayerNotificationManager + MediaSession |
| DI | Dagger Hilt |
| Local DB | Room |
| Networking | Retrofit + Moshi + OkHttp |
| Async | Kotlin Coroutines + Flow |
| Tests | JUnit5 + MockK + Turbine + MockWebServer |

## Key concepts

### Verse-by-verse (gapped) mode

Each ayah is an individual MP3 file at:
```
https://verses.quran.com/{reciter-path}/{SSSAAA}.mp3
```
where `SSS` = 3-digit surah, `AAA` = 3-digit ayah (e.g. `002255.mp3`).

### Gapless mode

One MP3 per surah. A SQLite timing database maps millisecond offsets to ayah
numbers, matching quran_android's "glide" table format:

```sql
-- timing table
reciterId  INTEGER
surahNumber INTEGER
ayahNumber  INTEGER
startTime   INTEGER  -- ms offset within the surah's single MP3
```

`GaplessTimingHelper` translates `currentPosition` → ayah number in real time.

## Usage

```kotlin
@Inject lateinit var player: QuranAudioPlayer

// Load reciters (cached 24 h, auto-refreshes from api.quran.com)
val reciters = player.getReciters()

// Play Ayat Al-Kursi (2:255)
val keys = listOf("002255")
player.play(reciterId = 7, startKey = "002255", keys = keys)

// Observe state
player.playbackState.collect { state ->
    when (state.status) {
        PlaybackStatus.PLAYING  -> showPauseButton()
        PlaybackStatus.PAUSED   -> showPlayButton()
        PlaybackStatus.BUFFERING -> showSpinner()
        else -> {}
    }
}

// Download a surah for offline use
val surah2keys = (1..286).map { "002${it.toString().padStart(3, '0')}" }
player.downloadRange(reciterId = 7, keys = surah2keys)

// Observe download progress
player.observeAllDownloads().collect { downloads ->
    downloads.forEach { d -> println("${d.key}: ${d.progress}%") }
}
```

## Setup

1. Add the module to your `settings.gradle.kts`:
   ```kotlin
   include(":quran-audio")
   ```

2. Add the dependency:
   ```kotlin
   implementation(project(":quran-audio"))
   ```

3. The module uses Hilt — your Application must be annotated with `@HiltAndroidApp`.

4. Declare the playback service in your app's `AndroidManifest.xml`:
   ```xml
   <service
       android:name="com.quran.audio.playback.AudioPlaybackService"
       android:exported="false"
       android:foregroundServiceType="mediaPlayback" />
   ```

## Running tests

```bash
./gradlew :quran-audio:test
```
