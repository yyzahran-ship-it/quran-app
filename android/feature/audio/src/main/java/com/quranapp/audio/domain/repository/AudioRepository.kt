package com.quranapp.audio.domain.repository

import com.quranapp.audio.domain.model.AudioPlaybackState
import com.quranapp.audio.domain.model.Reciter
import kotlinx.coroutines.flow.Flow

interface AudioRepository {

    val playbackState: Flow<AudioPlaybackState>

    // ── Reciter ──────────────────────────────────────────────────────────────

    fun getReciters(): List<Reciter>

    suspend fun getSelectedReciter(): Reciter

    suspend fun setSelectedReciter(reciter: Reciter)

    // ── Playback ──────────────────────────────────────────────────────────────

    suspend fun play(surahNumber: Int, ayahIndex: Int = 0)

    suspend fun pause()

    suspend fun resume()

    suspend fun stop()

    suspend fun seekTo(positionMs: Long)

    suspend fun nextAyah()

    suspend fun previousAyah()

    suspend fun setRepeatMode(mode: RepeatMode)

    suspend fun setPlaybackSpeed(speed: Float)

    // ── Downloads ─────────────────────────────────────────────────────────────

    fun isDownloaded(reciter: Reciter, surahNumber: Int): Boolean

    /** Returns 0f..1f progress, or null if not downloading. */
    fun downloadProgress(reciter: Reciter, surahNumber: Int): Flow<Float?>

    suspend fun downloadSurah(reciter: Reciter, surahNumber: Int)

    suspend fun cancelDownload(reciter: Reciter, surahNumber: Int)

    suspend fun deleteSurah(reciter: Reciter, surahNumber: Int)
}

enum class RepeatMode { NONE, ONE, SURAH }
