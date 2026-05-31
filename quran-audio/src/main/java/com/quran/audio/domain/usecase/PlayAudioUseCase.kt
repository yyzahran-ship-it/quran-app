package com.quran.audio.domain.usecase

import com.quran.audio.domain.model.RepeatMode
import com.quran.audio.domain.repository.AudioRepository
import com.quran.audio.domain.repository.DownloadRepository
import com.quran.audio.playback.AudioQueueManager
import javax.inject.Inject

class PlayAudioUseCase @Inject constructor(
    private val audioRepository: AudioRepository,
    private val downloadRepository: DownloadRepository,
    private val queueManager: AudioQueueManager,
) {
    /**
     * Loads [keys] into the queue and starts playback from [startKey].
     * Local cached files are preferred over remote URLs.
     */
    suspend operator fun invoke(
        reciterId: Int,
        startKey: String,
        keys: List<String>,
    ) {
        val audioFiles = audioRepository.getAudioFilesForRange(reciterId, keys)
        val enriched = audioFiles.map { file ->
            val localPath = downloadRepository.getDownloadedPath(file.key, reciterId)
            if (localPath != null) file.copy(localPath = localPath, isDownloaded = true)
            else file
        }
        val startIndex = enriched.indexOfFirst { it.key == startKey }.coerceAtLeast(0)
        queueManager.setQueue(enriched, startIndex)
        queueManager.play()
    }

    fun setRepeatMode(mode: RepeatMode) = queueManager.setRepeatMode(mode)
    fun setRepeatRange(startKey: String, endKey: String) = queueManager.setRepeatRange(startKey, endKey)
    fun setSpeed(speed: Float) = queueManager.setSpeed(speed)
    fun pause() = queueManager.pause()
    fun resume() = queueManager.play()
    fun stop() = queueManager.stop()
    fun skipToNext() = queueManager.skipToNext()
    fun skipToPrevious() = queueManager.skipToPrevious()
    fun seekTo(positionMs: Long) = queueManager.seekTo(positionMs)
}
