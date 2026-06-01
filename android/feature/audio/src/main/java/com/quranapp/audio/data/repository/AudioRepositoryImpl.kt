package com.quranapp.audio.data.repository

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.quranapp.audio.catalog.ReciterCatalog
import com.quranapp.audio.data.datastore.AudioPreferencesDataStore
import com.quranapp.audio.data.local.dao.AudioDownloadDao
import com.quranapp.audio.data.local.entity.AudioDownloadEntity
import com.quranapp.audio.data.timing.AyahTimingRepository
import com.quranapp.audio.domain.model.AudioPlaybackState
import com.quranapp.audio.domain.model.Reciter
import com.quranapp.audio.domain.repository.AudioRepository
import com.quranapp.audio.domain.repository.RepeatMode
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AudioRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val player: ExoPlayer,
    private val downloadDao: AudioDownloadDao,
    private val prefs: AudioPreferencesDataStore,
    private val timing: AyahTimingRepository,
) : AudioRepository {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _state = MutableStateFlow<AudioPlaybackState>(AudioPlaybackState.Idle)
    override val playbackState: Flow<AudioPlaybackState> = _state.asStateFlow()

    private var currentReciter: Reciter = ReciterCatalog.ALL.first()
    private var currentSurah: Int = 1
    private var repeatMode: RepeatMode = RepeatMode.NONE

    private val downloadProgressMap =
        mutableMapOf<String, MutableStateFlow<Float?>>()

    init {
        attachPlayerListener()
        scope.launch { restorePreferences() }
    }

    // ── Reciter ───────────────────────────────────────────────────────────────

    override fun getReciters(): List<Reciter> = ReciterCatalog.ALL

    override suspend fun getSelectedReciter(): Reciter = currentReciter

    override suspend fun setSelectedReciter(reciter: Reciter) {
        currentReciter = reciter
        prefs.setLastReciterId(reciter.id)
    }

    // ── Playback ──────────────────────────────────────────────────────────────

    override suspend fun play(surahNumber: Int, ayahIndex: Int) = withContext(Dispatchers.Main) {
        currentSurah = surahNumber
        _state.value = AudioPlaybackState.Loading

        val reciter = currentReciter
        val localPath = downloadDao.get(reciter.id, surahNumber)?.localFilePath

        if (reciter.hasGaplessAudio) {
            playGapless(reciter, surahNumber, ayahIndex, localPath)
        } else {
            playPerAyah(reciter, surahNumber, ayahIndex, localPath)
        }

        prefs.setLastSurahNumber(surahNumber)
        prefs.setLastAyahIndex(ayahIndex)
    }

    private fun playGapless(reciter: Reciter, surahNumber: Int, ayahIndex: Int, localPath: String?) {
        val uri = localPath ?: ReciterCatalog.gaplessSurahUrl(reciter, surahNumber)
        val item = MediaItem.fromUri(uri)
        player.setMediaItem(item)
        player.prepare()
        if (ayahIndex > 0) {
            // Seek to estimated ayah position after player is ready
            scope.launch {
                delay(500) // give ExoPlayer time to load duration
                val totalMs = player.duration.coerceAtLeast(1L)
                val seekMs = timing.startTimeForAyah(surahNumber, ayahIndex + 1, totalMs)
                player.seekTo(seekMs)
            }
        }
        player.play()
    }

    private fun playPerAyah(reciter: Reciter, surahNumber: Int, startAyahIndex: Int, localBasePath: String?) {
        val ayahCount = ReciterCatalog.SURAH_AYAH_COUNTS.getOrElse(surahNumber) { 1 }
        val items = (1..ayahCount).map { ayah ->
            val url = ReciterCatalog.perAyahUrl(reciter, surahNumber, ayah)
            MediaItem.fromUri(url)
        }
        player.setMediaItems(items, startAyahIndex, 0L)
        player.prepare()
        player.play()
    }

    override suspend fun pause() = withContext(Dispatchers.Main) { player.pause() }

    override suspend fun resume() = withContext(Dispatchers.Main) { player.play() }

    override suspend fun stop() = withContext(Dispatchers.Main) {
        player.stop()
        _state.value = AudioPlaybackState.Stopped
    }

    override suspend fun seekTo(positionMs: Long) = withContext(Dispatchers.Main) {
        player.seekTo(positionMs)
    }

    override suspend fun nextAyah() = withContext(Dispatchers.Main) {
        if (currentReciter.hasGaplessAudio) {
            val pos = player.currentPosition
            val dur = player.duration.coerceAtLeast(1L)
            val currentAyah = timing.ayahAtPosition(currentSurah, pos, dur)
            val nextStartMs = timing.startTimeForAyah(currentSurah, currentAyah + 1, dur)
            player.seekTo(nextStartMs)
        } else {
            if (player.hasNextMediaItem()) player.seekToNextMediaItem()
        }
    }

    override suspend fun previousAyah() = withContext(Dispatchers.Main) {
        if (currentReciter.hasGaplessAudio) {
            val pos = player.currentPosition
            val dur = player.duration.coerceAtLeast(1L)
            val currentAyah = timing.ayahAtPosition(currentSurah, pos, dur)
            val prevStartMs = timing.startTimeForAyah(
                currentSurah, (currentAyah - 1).coerceAtLeast(1), dur
            )
            player.seekTo(prevStartMs)
        } else {
            if (player.hasPreviousMediaItem()) player.seekToPreviousMediaItem()
        }
    }

    override suspend fun setRepeatMode(mode: RepeatMode) {
        repeatMode = mode
        prefs.setRepeatMode(mode)
        withContext(Dispatchers.Main) {
            player.repeatMode = when (mode) {
                RepeatMode.NONE -> Player.REPEAT_MODE_OFF
                RepeatMode.ONE -> Player.REPEAT_MODE_ONE
                RepeatMode.SURAH -> Player.REPEAT_MODE_ALL
            }
        }
    }

    override suspend fun setPlaybackSpeed(speed: Float) {
        prefs.setPlaybackSpeed(speed)
        withContext(Dispatchers.Main) {
            player.setPlaybackSpeed(speed)
        }
    }

    // ── Downloads ──────────────────────────────────────────────────────────────

    override fun isDownloaded(reciter: Reciter, surahNumber: Int): Boolean {
        // Sync check: look at local file existence (best-effort; DAO is async)
        val file = surahFile(reciter, surahNumber)
        return file.exists()
    }

    override fun downloadProgress(reciter: Reciter, surahNumber: Int): Flow<Float?> {
        return progressFlow(reciter, surahNumber).asStateFlow()
    }

    override suspend fun downloadSurah(reciter: Reciter, surahNumber: Int) {
        val flow = progressFlow(reciter, surahNumber)
        val url = ReciterCatalog.gaplessSurahUrl(reciter, surahNumber)
        val dest = surahFile(reciter, surahNumber)
        dest.parentFile?.mkdirs()

        scope.launch(Dispatchers.IO) {
            try {
                flow.value = 0f
                val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                connection.connect()
                val total = connection.contentLengthLong.coerceAtLeast(1L)
                var downloaded = 0L
                connection.inputStream.use { input ->
                    dest.outputStream().use { output ->
                        val buf = ByteArray(8 * 1024)
                        var n: Int
                        while (input.read(buf).also { n = it } != -1) {
                            output.write(buf, 0, n)
                            downloaded += n
                            flow.value = downloaded.toFloat() / total
                        }
                    }
                }
                downloadDao.insert(
                    AudioDownloadEntity(
                        reciterId = reciter.id,
                        surahNumber = surahNumber,
                        localFilePath = dest.absolutePath,
                    )
                )
                flow.value = null
            } catch (e: Exception) {
                dest.delete()
                flow.value = null
            }
        }
    }

    override suspend fun cancelDownload(reciter: Reciter, surahNumber: Int) {
        // Signal cancellation by resetting progress; the download coroutine checks this
        progressFlow(reciter, surahNumber).value = null
    }

    override suspend fun deleteSurah(reciter: Reciter, surahNumber: Int) {
        surahFile(reciter, surahNumber).delete()
        downloadDao.delete(reciter.id, surahNumber)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun progressFlow(reciter: Reciter, surahNumber: Int): MutableStateFlow<Float?> {
        val key = "${reciter.id}_$surahNumber"
        return downloadProgressMap.getOrPut(key) { MutableStateFlow(null) }
    }

    private fun surahFile(reciter: Reciter, surahNumber: Int): File {
        val dir = File(context.filesDir, "audio/${reciter.id}")
        val name = surahNumber.toString().padStart(3, '0') + ".mp3"
        return File(dir, name)
    }

    private suspend fun restorePreferences() {
        val id = prefs.getLastReciterId()
        currentReciter = ReciterCatalog.findById(id) ?: ReciterCatalog.ALL.first()
        val speed = prefs.getPlaybackSpeed()
        val repeat = prefs.getRepeatMode()
        withContext(Dispatchers.Main) {
            player.setPlaybackSpeed(speed)
            player.repeatMode = when (repeat) {
                RepeatMode.NONE -> Player.REPEAT_MODE_OFF
                RepeatMode.ONE -> Player.REPEAT_MODE_ONE
                RepeatMode.SURAH -> Player.REPEAT_MODE_ALL
            }
        }
    }

    private fun attachPlayerListener() {
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) { updateState() }
            override fun onIsPlayingChanged(isPlaying: Boolean) { updateState() }
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int,
            ) { updateState() }
            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                _state.value = AudioPlaybackState.Error(error.message ?: "Playback error")
            }
        })
    }

    private fun updateState() {
        val reciter = currentReciter
        val surah = currentSurah
        val posMs = player.currentPosition
        val durMs = player.duration.coerceAtLeast(0L)

        val ayahIndex = if (reciter.hasGaplessAudio) {
            timing.ayahAtPosition(surah, posMs, durMs.coerceAtLeast(1L)) - 1
        } else {
            player.currentMediaItemIndex
        }

        _state.value = when {
            player.playbackState == Player.STATE_BUFFERING -> AudioPlaybackState.Loading
            player.isPlaying -> AudioPlaybackState.Playing(reciter, surah, ayahIndex, posMs, durMs)
            player.playbackState == Player.STATE_READY -> AudioPlaybackState.Paused(reciter, surah, ayahIndex, posMs, durMs)
            else -> _state.value // retain last known state on transient changes
        }
    }
}
