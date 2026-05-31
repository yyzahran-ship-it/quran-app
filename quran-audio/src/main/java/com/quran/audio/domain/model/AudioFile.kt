package com.quran.audio.domain.model

/**
 * A single playable audio item, either ayah-level or surah-level (gapless).
 *
 * The [key] is the canonical identifier for a piece of audio.
 * Convention used across this library:
 *   - Per-ayah:   "SSSAAA"  (6-char, zero-padded), e.g. "001001" = Al-Fatihah:1
 *   - Per-surah:  "SSS"     (3-char, zero-padded), e.g. "002"    = Al-Baqarah
 *
 * This matches the file naming on everyayah.com and quranicaudio.com CDNs.
 */
data class AudioFile(
    /** Reciter this file belongs to. */
    val reciterId: Int,
    /** Canonical key, e.g. "001001" for Surah 1, Ayah 1. */
    val key: String,
    /** Fully-qualified CDN URL. */
    val remoteUrl: String,
    /** Absolute local file path once downloaded; null if not yet cached. */
    val localPath: String? = null,
    val isDownloaded: Boolean = false,
    /** Expected file size in bytes; 0 if unknown. */
    val fileSize: Long = 0L,
) {
    val surahNumber: Int get() = key.take(3).toIntOrNull() ?: 0
    val ayahNumber: Int? get() = if (key.length == 6) key.drop(3).toIntOrNull() else null
    val isGapless: Boolean get() = key.length == 3

    /** URI suitable for ExoPlayer: file:// when downloaded, https:// otherwise. */
    val playbackUri: String
        get() = if (isDownloaded && localPath != null) "file://$localPath" else remoteUrl
}
