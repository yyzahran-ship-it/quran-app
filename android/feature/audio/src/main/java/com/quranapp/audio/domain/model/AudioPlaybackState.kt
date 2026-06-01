package com.quranapp.audio.domain.model

sealed class AudioPlaybackState {
    data object Idle : AudioPlaybackState()
    data object Loading : AudioPlaybackState()
    data class Playing(
        val reciter: Reciter,
        val surahNumber: Int,
        val ayahIndex: Int,       // 0-based
        val positionMs: Long,
        val durationMs: Long,
    ) : AudioPlaybackState()
    data class Paused(
        val reciter: Reciter,
        val surahNumber: Int,
        val ayahIndex: Int,
        val positionMs: Long,
        val durationMs: Long,
    ) : AudioPlaybackState()
    data object Stopped : AudioPlaybackState()
    data class Error(val message: String) : AudioPlaybackState()
}
