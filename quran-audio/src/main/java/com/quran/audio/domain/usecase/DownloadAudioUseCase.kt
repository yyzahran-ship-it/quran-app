package com.quran.audio.domain.usecase

import com.quran.audio.domain.model.DownloadProgress
import com.quran.audio.domain.repository.AudioRepository
import com.quran.audio.domain.repository.DownloadRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class DownloadAudioUseCase @Inject constructor(
    private val audioRepository: AudioRepository,
    private val downloadRepository: DownloadRepository,
) {
    /** Download a single file by key (e.g. "001001"). */
    suspend fun downloadFile(reciterId: Int, key: String): Boolean {
        val file = audioRepository.getAudioFile(reciterId, key)
        return downloadRepository.enqueueDownload(file)
    }

    /** Download a batch of files. Returns per-file enqueue results. */
    suspend fun downloadRange(reciterId: Int, keys: List<String>): List<Boolean> {
        val files = audioRepository.getAudioFilesForRange(reciterId, keys)
        return files.map { downloadRepository.enqueueDownload(it) }
    }

    fun observeProgress(key: String, reciterId: Int): Flow<DownloadProgress> =
        downloadRepository.observeDownloadProgress(key, reciterId)

    fun observeAllDownloads(): Flow<List<DownloadProgress>> =
        downloadRepository.observeAllDownloads()

    suspend fun cancelDownload(key: String, reciterId: Int) =
        downloadRepository.cancelDownload(key, reciterId)

    suspend fun pauseDownload(key: String, reciterId: Int) =
        downloadRepository.pauseDownload(key, reciterId)

    suspend fun resumeDownload(key: String, reciterId: Int) =
        downloadRepository.resumeDownload(key, reciterId)

    suspend fun isDownloaded(key: String, reciterId: Int): Boolean =
        downloadRepository.isDownloaded(key, reciterId)
}
