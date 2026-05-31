package com.quran.audio.data.repository

import com.quran.audio.data.local.dao.DownloadDao
import com.quran.audio.data.local.entity.DownloadEntity
import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.DownloadProgress
import com.quran.audio.domain.model.DownloadStatus
import com.quran.audio.domain.repository.DownloadRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.RandomAccessFile
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DownloadRepositoryImpl @Inject constructor(
    private val downloadDao: DownloadDao,
    private val okHttpClient: OkHttpClient,
    private val downloadDir: File,
) : DownloadRepository {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // ── Observe ────────────────────────────────────────────────────────────────

    override fun observeDownloadProgress(key: String, reciterId: Int): Flow<DownloadProgress> =
        downloadDao.observe(key, reciterId).map { it?.toDomain() ?: DownloadProgress(key, reciterId) }

    override fun observeAllDownloads(): Flow<List<DownloadProgress>> =
        downloadDao.observeAll().map { entities -> entities.map { it.toDomain() } }

    // ── Control ────────────────────────────────────────────────────────────────

    override suspend fun enqueueDownload(file: AudioFile): Boolean {
        val existing = downloadDao.get(file.key, file.reciterId)
        if (existing?.status == DownloadStatus.COMPLETE.name) return true
        if (existing?.status == DownloadStatus.DOWNLOADING.name) return true

        val localFile = localFile(file.key, file.reciterId)
        val entity = DownloadEntity(
            audioKey = file.key,
            reciterId = file.reciterId,
            remoteUrl = file.remoteUrl,
            localPath = localFile.absolutePath,
            status = DownloadStatus.PENDING.name,
        )
        downloadDao.upsert(entity)
        scope.launch { executeDownload(file.key, file.reciterId, file.remoteUrl, localFile) }
        return true
    }

    override suspend fun cancelDownload(key: String, reciterId: Int) {
        downloadDao.updateProgress(
            key, reciterId, DownloadStatus.CANCELLED.name, 0, 0, null,
            System.currentTimeMillis(),
        )
        localFile(key, reciterId).delete()
    }

    override suspend fun pauseDownload(key: String, reciterId: Int) {
        val current = downloadDao.get(key, reciterId) ?: return
        if (current.status == DownloadStatus.DOWNLOADING.name) {
            downloadDao.updateProgress(
                key, reciterId, DownloadStatus.PAUSED.name,
                current.bytesDownloaded, current.totalBytes, null,
                System.currentTimeMillis(),
            )
        }
    }

    override suspend fun resumeDownload(key: String, reciterId: Int) {
        val entity = downloadDao.get(key, reciterId) ?: return
        if (entity.status != DownloadStatus.PAUSED.name &&
            entity.status != DownloadStatus.FAILED.name
        ) return

        downloadDao.updateProgress(
            key, reciterId, DownloadStatus.PENDING.name,
            entity.bytesDownloaded, entity.totalBytes, null,
            System.currentTimeMillis(),
        )
        val localFile = File(entity.localPath)
        scope.launch { executeDownload(key, reciterId, entity.remoteUrl, localFile, entity.bytesDownloaded) }
    }

    override suspend fun getDownloadedPath(key: String, reciterId: Int): String? =
        downloadDao.getCompletedPath(key, reciterId)

    override suspend fun isDownloaded(key: String, reciterId: Int): Boolean =
        downloadDao.getCompletedPath(key, reciterId) != null

    // ── Internal download ──────────────────────────────────────────────────────

    private suspend fun executeDownload(
        key: String,
        reciterId: Int,
        url: String,
        dest: File,
        resumeFrom: Long = 0L,
    ) {
        dest.parentFile?.mkdirs()

        val requestBuilder = Request.Builder().url(url)
        if (resumeFrom > 0) requestBuilder.header("Range", "bytes=$resumeFrom-")

        val call = okHttpClient.newCall(requestBuilder.build())

        try {
            val response = call.execute()
            if (!response.isSuccessful) {
                markFailed(key, reciterId, "HTTP ${response.code}")
                return
            }
            val body = response.body ?: run { markFailed(key, reciterId, "Empty body"); return }
            val contentLength = body.contentLength()
            val totalBytes = if (resumeFrom > 0 && contentLength > 0) resumeFrom + contentLength
            else contentLength

            downloadDao.updateProgress(
                key, reciterId, DownloadStatus.DOWNLOADING.name,
                resumeFrom, totalBytes, null, System.currentTimeMillis(),
            )

            var downloaded = resumeFrom
            val mode = if (resumeFrom > 0) "rw" else "rw"
            RandomAccessFile(dest, mode).use { raf ->
                if (resumeFrom > 0) raf.seek(resumeFrom)
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                body.byteStream().use { stream ->
                    var read: Int
                    while (stream.read(buffer).also { read = it } != -1) {
                        val status = downloadDao.get(key, reciterId)?.status
                        if (status == DownloadStatus.CANCELLED.name ||
                            status == DownloadStatus.PAUSED.name
                        ) return

                        raf.write(buffer, 0, read)
                        downloaded += read
                        downloadDao.updateProgress(
                            key, reciterId, DownloadStatus.DOWNLOADING.name,
                            downloaded, totalBytes, null, System.currentTimeMillis(),
                        )
                    }
                }
            }

            downloadDao.updateProgress(
                key, reciterId, DownloadStatus.COMPLETE.name,
                downloaded, downloaded, null, System.currentTimeMillis(),
            )
        } catch (e: Exception) {
            markFailed(key, reciterId, e.message ?: "Unknown error")
        }
    }

    private suspend fun markFailed(key: String, reciterId: Int, error: String) {
        downloadDao.updateProgress(
            key, reciterId, DownloadStatus.FAILED.name,
            0, 0, error, System.currentTimeMillis(),
        )
    }

    private fun localFile(key: String, reciterId: Int): File =
        File(downloadDir, "$reciterId/$key.mp3")

    private fun DownloadEntity.toDomain() = DownloadProgress(
        key = audioKey,
        reciterId = reciterId,
        status = runCatching { DownloadStatus.valueOf(status) }.getOrDefault(DownloadStatus.PENDING),
        bytesDownloaded = bytesDownloaded,
        totalBytes = totalBytes,
        errorMessage = errorMessage,
    )
}
