package com.quranapp.audio.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.quranapp.audio.domain.model.AudioPlaybackState
import com.quranapp.audio.domain.model.Reciter
import com.quranapp.audio.domain.repository.AudioRepository
import com.quranapp.audio.domain.repository.RepeatMode
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AudioPlayerViewModel @Inject constructor(
    private val repository: AudioRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AudioUiState())
    val uiState: StateFlow<AudioUiState> = _uiState.asStateFlow()

    init {
        _uiState.update { it.copy(availableReciters = repository.getReciters()) }
        viewModelScope.launch { observePlaybackState() }
    }

    private suspend fun observePlaybackState() {
        repository.playbackState.collect { state ->
            _uiState.update { current ->
                when (state) {
                    is AudioPlaybackState.Idle -> current.copy(
                        isPlaying = false, isLoading = false, error = null
                    )
                    is AudioPlaybackState.Loading -> current.copy(
                        isLoading = true, error = null
                    )
                    is AudioPlaybackState.Playing -> current.copy(
                        reciter = state.reciter,
                        surahNumber = state.surahNumber,
                        ayahIndex = state.ayahIndex,
                        positionMs = state.positionMs,
                        durationMs = state.durationMs,
                        isPlaying = true,
                        isLoading = false,
                        isPlayerVisible = true,
                        error = null,
                    )
                    is AudioPlaybackState.Paused -> current.copy(
                        reciter = state.reciter,
                        surahNumber = state.surahNumber,
                        ayahIndex = state.ayahIndex,
                        positionMs = state.positionMs,
                        durationMs = state.durationMs,
                        isPlaying = false,
                        isLoading = false,
                        isPlayerVisible = true,
                        error = null,
                    )
                    is AudioPlaybackState.Stopped -> current.copy(
                        isPlaying = false, isLoading = false
                    )
                    is AudioPlaybackState.Error -> current.copy(
                        isPlaying = false, isLoading = false, error = state.message
                    )
                }
            }
        }
    }

    // ── User actions ──────────────────────────────────────────────────────────

    fun play(surahNumber: Int, ayahIndex: Int = 0) {
        viewModelScope.launch { repository.play(surahNumber, ayahIndex) }
    }

    fun togglePlayPause() {
        viewModelScope.launch {
            if (_uiState.value.isPlaying) repository.pause()
            else repository.resume()
        }
    }

    fun seekTo(positionMs: Long) {
        viewModelScope.launch { repository.seekTo(positionMs) }
    }

    fun nextAyah() {
        viewModelScope.launch { repository.nextAyah() }
    }

    fun previousAyah() {
        viewModelScope.launch { repository.previousAyah() }
    }

    fun setReciter(reciter: Reciter) {
        viewModelScope.launch { repository.setSelectedReciter(reciter) }
    }

    fun cycleRepeatMode() {
        val next = when (_uiState.value.repeatMode) {
            RepeatMode.NONE -> RepeatMode.ONE
            RepeatMode.ONE -> RepeatMode.SURAH
            RepeatMode.SURAH -> RepeatMode.NONE
        }
        _uiState.update { it.copy(repeatMode = next) }
        viewModelScope.launch { repository.setRepeatMode(next) }
    }

    fun setSpeed(speed: Float) {
        _uiState.update { it.copy(playbackSpeed = speed) }
        viewModelScope.launch { repository.setPlaybackSpeed(speed) }
    }

    fun downloadCurrentSurah() {
        val state = _uiState.value
        val reciter = state.reciter ?: return
        viewModelScope.launch {
            repository.downloadProgress(reciter, state.surahNumber).collect { progress ->
                _uiState.update { it.copy(downloadProgress = progress) }
            }
        }
        viewModelScope.launch {
            repository.downloadSurah(reciter, state.surahNumber)
        }
    }

    fun hidePlayer() {
        _uiState.update { it.copy(isPlayerVisible = false) }
        viewModelScope.launch { repository.stop() }
    }
}
