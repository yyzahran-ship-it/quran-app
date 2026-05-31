package com.quran.audio.playback

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.PlaybackEvent
import com.quran.audio.domain.model.PlaybackState
import com.quran.audio.domain.model.PlaybackStatus
import com.quran.audio.domain.model.RepeatMode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AudioQueueManager @Inject constructor(
    private val player: ExoPlayer,
    private val timingHelper: GaplessTimingHelper,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _state = MutableStateFlow(PlaybackState())
    val state: StateFlow<PlaybackState> = _state.asStateFlow()

    private val _events = MutableSharedFlow<PlaybackEvent>(extraBufferCapacity = 16)
    val events: SharedFlow<PlaybackEvent> = _events.asSharedFlow()

    private var queue: List<AudioFile> = emptyList()
    private var currentIndex: Int = 0
    private var repeatMode: RepeatMode = RepeatMode.NO_REPEAT
    private var repeatStartKey: String? = null
    private var repeatEndKey: String? = null

    init {
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_ENDED -> onTrackEnded()
                    Player.STATE_BUFFERING -> updateStatus(PlaybackStatus.BUFFERING)
                    Player.STATE_READY -> {
                        if (player.playWhenReady) updateStatus(PlaybackStatus.PLAYING)
                    }
                    Player.STATE_IDLE -> updateStatus(PlaybackStatus.IDLE)
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (isPlaying) updateStatus(PlaybackStatus.PLAYING)
                else if (player.playbackState == Player.STATE_READY) updateStatus(PlaybackStatus.PAUSED)
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                _state.value = _state.value.copy(
                    status = PlaybackStatus.ERROR,
                    errorMessage = error.message,
                )
                emit(PlaybackEvent.Error(error.message ?: "Unknown playback error"))
            }
        })
    }

    // ── Queue management ───────────────────────────────────────────────────────

    fun setQueue(files: List<AudioFile>, startIndex: Int = 0) {
        queue = files
        currentIndex = startIndex.coerceIn(0, (files.size - 1).coerceAtLeast(0))
        prefetchUpcoming()
    }

    fun play() {
        val file = queue.getOrNull(currentIndex) ?: return
        val uri = Uri.parse(file.playbackUri)
        val mediaItem = MediaItem.fromUri(uri)
        player.setMediaItem(mediaItem)
        player.prepare()
        player.playWhenReady = true
        _state.value = _state.value.copy(
            currentKey = file.key,
            status = PlaybackStatus.BUFFERING,
            errorMessage = null,
        )
        emit(PlaybackEvent.TrackChanged(file.key))
    }

    fun pause() {
        player.pause()
        updateStatus(PlaybackStatus.PAUSED)
    }

    fun stop() {
        player.stop()
        player.clearMediaItems()
        updateStatus(PlaybackStatus.STOPPED)
    }

    fun skipToNext() {
        val nextIndex = currentIndex + 1
        if (nextIndex < queue.size) {
            currentIndex = nextIndex
            play()
        } else {
            emit(PlaybackEvent.QueueEnded)
        }
    }

    fun skipToPrevious() {
        if (player.currentPosition > 3_000) {
            // If more than 3 s played, restart current track
            player.seekTo(0)
            return
        }
        val prevIndex = currentIndex - 1
        if (prevIndex >= 0) {
            currentIndex = prevIndex
            play()
        }
    }

    fun seekTo(positionMs: Long) {
        player.seekTo(positionMs)
    }

    // ── Repeat ─────────────────────────────────────────────────────────────────

    fun setRepeatMode(mode: RepeatMode) {
        repeatMode = mode
        _state.value = _state.value.copy(repeatMode = mode)
    }

    fun setRepeatRange(startKey: String, endKey: String) {
        repeatStartKey = startKey
        repeatEndKey = endKey
    }

    // ── Speed / pitch ──────────────────────────────────────────────────────────

    fun setSpeed(speed: Float) {
        val params = player.playbackParameters.withSpeed(speed)
        player.playbackParameters = params
        _state.value = _state.value.copy(speed = speed)
    }

    // ── Position reporting ─────────────────────────────────────────────────────

    val currentPositionMs: Long get() = player.currentPosition
    val durationMs: Long get() = player.duration.takeIf { it != androidx.media3.common.C.TIME_UNSET } ?: 0L

    // ── Private ────────────────────────────────────────────────────────────────

    private fun onTrackEnded() {
        when (repeatMode) {
            RepeatMode.REPEAT_ONE -> {
                player.seekTo(0)
                player.play()
            }
            RepeatMode.REPEAT_ALL -> {
                currentIndex = (currentIndex + 1) % queue.size
                play()
            }
            RepeatMode.REPEAT_RANGE -> {
                val endIdx = queue.indexOfFirst { it.key == repeatEndKey }
                if (currentIndex >= endIdx && endIdx >= 0) {
                    val startIdx = queue.indexOfFirst { it.key == repeatStartKey }
                    currentIndex = startIdx.coerceAtLeast(0)
                } else {
                    currentIndex++
                }
                play()
            }
            RepeatMode.NO_REPEAT -> skipToNext()
        }
    }

    private fun updateStatus(status: PlaybackStatus) {
        _state.value = _state.value.copy(status = status)
    }

    private fun emit(event: PlaybackEvent) {
        scope.launch { _events.emit(event) }
    }

    /** Pre-creates MediaItems for the next few tracks so ExoPlayer can buffer them. */
    private fun prefetchUpcoming() {
        // No-op for verse-by-verse (each ayah is a separate short file).
        // For gapless mode the whole surah is one file — no prefetch needed.
    }
}
