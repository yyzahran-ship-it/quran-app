package com.quran.audio.domain.repository

import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.DownloadProgress
import kotlinx.coroutines.flow.Flow

interface DownloadRepository {
    /** Emits real-time progress for a single file. Completes when the download finishes. */
    fun observeDownloadProgress(key: String, reciterId: Int): Flow<DownloadProgress>

    /** Emits the full list of tracked downloads whenever any entry changes. */
    fun observeAllDownloads(): Flow<List<DownloadProgress>>

    /**
     * Enqueues a download for [audioFile].
     * Returns true if a new download was started; false if already complete or queued.
     */
    suspend fun enqueueDownload(audioFile: AudioFile): Boolean

    suspend fun pauseDownload(key: String, reciterId: Int)
    suspend fun resumeDownload(key: String, reciterId: Int)
    suspend fun cancelDownload(key: String, reciterId: Int)

    /** Returns the absolute local path if the file is fully downloaded; null otherwise. */
    suspend fun getDownloadedPath(key: String, reciterId: Int): String?

    suspend fun isDownloaded(key: String, reciterId: Int): Boolean
}
