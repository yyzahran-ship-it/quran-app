package com.quran.audio.domain.model

/**
 * Represents a Quran reciter.
 *
 * Mirrors the Reciter model used in quran/quran_android (common/audio module).
 *
 * @param id            Unique integer ID from the remote catalog.
 * @param name          Display name of the reciter.
 * @param relativePath  Folder path segment used to build CDN URLs, e.g.
 *                      "Alafasy_128kbps" → cdn/.../Alafasy_128kbps/001001.mp3
 * @param hasGaplessDatabase  When true, a single MP3 per surah is used with a
 *                            SQLite timing database to locate individual ayahs.
 * @param audioExtension      File extension of audio files ("mp3", "ogg").
 * @param gaplessDatabaseUrl  Remote URL for the SQLite timing database zip/db
 *                            (only relevant when [hasGaplessDatabase] = true).
 */
data class Reciter(
    val id: Int,
    val name: String,
    val relativePath: String,
    val hasGaplessDatabase: Boolean = false,
    val audioExtension: String = "mp3",
    val gaplessDatabaseUrl: String? = null,
)
