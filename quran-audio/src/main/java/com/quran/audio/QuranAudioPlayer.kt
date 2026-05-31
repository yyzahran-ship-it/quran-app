package com.quran.audio

import com.quran.audio.domain.model.DownloadProgress
import com.quran.audio.domain.model.PlaybackState
import com.quran.audio.domain.model.Reciter
import com.quran.audio.domain.model.RepeatMode
import com.quran.audio.domain.usecase.DownloadAudioUseCase
import com.quran.audio.domain.usecase.GetRecitersUseCase
import com.quran.audio.domain.usecase.PlayAudioUseCase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import com.quran.audio.playback.AudioQueueManager
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Public facade for the quran-audio library.
 *
 * Consumers inject this class and interact with it via the typed methods below.
 * All internal implementation details (ExoPlayer, Room, OkHttp) stay hidden
 * behind this surface so callers don't depend on the internal structure.
 *
 * Usage:
 * ```kotlin
 * @Inject lateinit var quranAudioPlayer: QuranAudioPlayer
 *
 * // List reciters
 * val reciters = quranAudioPlayer.getReciters()
 *
 * // Play surah 2 ayah 255 onwards
 * val keys = (255..286).map { ayah -> "002${ayah.toString().padStart(3, '0')}" }
 * quranAudioPlayer.play(reciterId = 7, startKey = "002255", keys = keys)
 *
 * // Observe state
 * quranAudioPlayer.playbackState.collect { state -> /* update UI */ }
 * ```
 */
@Singleton
class QuranAudioPlayer @Inject constructor(
    private val getRecitersUseCase: GetRecitersUseCase,
    private val playAudioUseCase: PlayAudioUseCase,
    private val downloadAudioUseCase: DownloadAudioUseCase,
    private val queueManager: AudioQueueManager,
) {
    // ── State ──────────────────────────────────────────────────────────────────

    /** Live playback state — status, current key, speed, repeat mode. */
    val playbackState: StateFlow<PlaybackState> = queueManager.state

    // ── Reciters ───────────────────────────────────────────────────────────────

    /** Returns cached reciters, refreshing from network if stale (>24 h). */
    suspend fun getReciters(forceRefresh: Boolean = false): List<Reciter> =
        getRecitersUseCase(forceRefresh)

    /** Emits the reciter list whenever it changes in the local DB. */
    fun observeReciters(): Flow<List<Reciter>> = getRecitersUseCase.observe()

    // ── Playback ───────────────────────────────────────────────────────────────

    /**
     * Loads [keys] into the queue and starts playback from [startKey].
     * Keys are in SSSAAA format (zero-padded surah + ayah, e.g. "002255").
     */
    suspend fun play(reciterId: Int, startKey: String, keys: List<String>) =
        playAudioUseCase(reciterId, startKey, keys)

    fun pause() = playAudioUseCase.pause()
    fun resume() = playAudioUseCase.resume()
    fun stop() = playAudioUseCase.stop()
    fun skipToNext() = playAudioUseCase.skipToNext()
    fun skipToPrevious() = playAudioUseCase.skipToPrevious()
    fun seekTo(positionMs: Long) = playAudioUseCase.seekTo(positionMs)

    /** Sets playback speed (0.5–2.0). */
    fun setSpeed(speed: Float) = playAudioUseCase.setSpeed(speed)

    /** Sets repeat mode — no repeat, repeat one, repeat range, repeat all. */
    fun setRepeatMode(mode: RepeatMode) = playAudioUseCase.setRepeatMode(mode)

    /** Sets the key range to repeat when [RepeatMode.REPEAT_RANGE] is active. */
    fun setRepeatRange(startKey: String, endKey: String) =
        playAudioUseCase.setRepeatRange(startKey, endKey)

    // ── Downloads ──────────────────────────────────────────────────────────────

    /** Enqueues a single ayah file for download. Returns false if already queued. */
    suspend fun downloadAyah(reciterId: Int, key: String): Boolean =
        downloadAudioUseCase.downloadFile(reciterId, key)

    /** Enqueues a batch of ayah files for download. */
    suspend fun downloadRange(reciterId: Int, keys: List<String>): List<Boolean> =
        downloadAudioUseCase.downloadRange(reciterId, keys)

    /** Emits download progress updates for [key]. */
    fun observeDownload(key: String, reciterId: Int): Flow<DownloadProgress> =
        downloadAudioUseCase.observeProgress(key, reciterId)

    /** Emits progress updates for all active downloads. */
    fun observeAllDownloads(): Flow<List<DownloadProgress>> =
        downloadAudioUseCase.observeAllDownloads()

    suspend fun cancelDownload(key: String, reciterId: Int) =
        downloadAudioUseCase.cancelDownload(key, reciterId)

    suspend fun pauseDownload(key: String, reciterId: Int) =
        downloadAudioUseCase.pauseDownload(key, reciterId)

    suspend fun resumeDownload(key: String, reciterId: Int) =
        downloadAudioUseCase.resumeDownload(key, reciterId)

    suspend fun isDownloaded(key: String, reciterId: Int): Boolean =
        downloadAudioUseCase.isDownloaded(key, reciterId)
}
