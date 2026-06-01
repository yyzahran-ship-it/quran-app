package com.quranapp.audio.presentation

import com.quranapp.audio.domain.model.Reciter
import com.quranapp.audio.domain.repository.RepeatMode

data class AudioUiState(
    val reciter: Reciter? = null,
    val surahNumber: Int = 1,
    val ayahIndex: Int = 0,       // 0-based
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val isPlaying: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null,
    val repeatMode: RepeatMode = RepeatMode.NONE,
    val playbackSpeed: Float = 1f,
    val isPlayerVisible: Boolean = false,
    val availableReciters: List<Reciter> = emptyList(),
    val downloadedSurahs: Set<Int> = emptySet(),
    val downloadProgress: Float? = null,   // 0..1 while downloading, null otherwise
) {
    val progress: Float
        get() = if (durationMs > 0L) positionMs.toFloat() / durationMs else 0f
}
