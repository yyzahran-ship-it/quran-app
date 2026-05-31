package com.quran.audio.domain.model

/**
 * Immutable snapshot of the audio player's current state.
 * Emitted as a [kotlinx.coroutines.flow.StateFlow] from [com.quran.audio.QuranAudioPlayer].
 */
data class AudioPlayerState(
    /** Key of the currently loaded item, or null when idle. */
    val currentKey: String? = null,
    val reciterId: Int? = null,
    val isPlaying: Boolean = false,
    val repeatMode: RepeatMode = RepeatMode.NO_REPEAT,
    /** Inclusive start key when [repeatMode] = [RepeatMode.REPEAT_RANGE]. */
    val rangeStart: String? = null,
    /** Inclusive end key when [repeatMode] = [RepeatMode.REPEAT_RANGE]. */
    val rangeEnd: String? = null,
    val speed: Float = 1.0f,
    val status: PlaybackStatus = PlaybackStatus.IDLE,
    /** Playback position within the current item, in milliseconds. */
    val positionMs: Long = 0L,
    /** Duration of the current item in milliseconds; -1 if unknown. */
    val durationMs: Long = -1L,
    /** Index within the active queue; -1 when nothing is loaded. */
    val queueIndex: Int = -1,
)

enum class PlaybackStatus {
    IDLE,
    BUFFERING,
    PLAYING,
    PAUSED,
    STOPPED,
    ERROR,
}

enum class RepeatMode {
    /** Play each item once, stop at the end. */
    NO_REPEAT,
    /** Repeat the currently playing item indefinitely. */
    REPEAT_ONE,
    /** Repeat between [AudioPlayerState.rangeStart] and [AudioPlayerState.rangeEnd]. */
    REPEAT_RANGE,
    /** Repeat the entire queue. */
    REPEAT_ALL,
}

/** One-shot events that must not be buffered in [AudioPlayerState]. */
sealed class PlaybackEvent {
    data class Error(val message: String, val cause: Throwable? = null) : PlaybackEvent()
    data class ItemCompleted(val key: String) : PlaybackEvent()
    data object QueueExhausted : PlaybackEvent()
    data object ServiceDisconnected : PlaybackEvent()
}
