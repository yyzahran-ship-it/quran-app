package com.quran.audio.data.repository.integration

import app.cash.turbine.test
import com.quran.audio.data.local.dao.DownloadDao
import com.quran.audio.data.local.entity.DownloadEntity
import com.quran.audio.data.repository.DownloadRepositoryImpl
import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.DownloadProgress
import com.quran.audio.domain.model.DownloadStatus
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

class DownloadRepositoryIntegrationTest {

    @TempDir
    lateinit var tempDir: File

    private val mockWebServer = MockWebServer()
    private val okHttpClient = OkHttpClient()
    private val downloadDao: DownloadDao = mockk(relaxed = true)
    private lateinit var repository: DownloadRepositoryImpl

    private val reciterId = 7
    private val key = "002255"

    @BeforeEach
    fun setUp() {
        mockWebServer.start()
        repository = DownloadRepositoryImpl(downloadDao, okHttpClient, tempDir)
    }

    @AfterEach
    fun tearDown() {
        mockWebServer.shutdown()
    }

    @Test
    fun `enqueueDownload saves file to disk on success`() = runTest {
        val audioBytes = ByteArray(1024) { it.toByte() }
        val buffer = Buffer().write(audioBytes)
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(buffer)
                .setHeader("Content-Length", audioBytes.size.toString()),
        )

        val url = mockWebServer.url("/002255.mp3").toString()
        val audioFile = AudioFile(reciterId, key, url)
        coEvery { downloadDao.get(key, reciterId) } returns null

        repository.enqueueDownload(audioFile)

        // Allow the background coroutine to complete
        kotlinx.coroutines.delay(500)

        val destFile = File(tempDir, "$reciterId/$key.mp3")
        assertTrue(destFile.exists(), "Downloaded file should exist at $destFile")
        assertEquals(1024, destFile.length())
    }

    @Test
    fun `enqueueDownload marks status FAILED on HTTP error`() = runTest {
        mockWebServer.enqueue(MockResponse().setResponseCode(404))

        val url = mockWebServer.url("/missing.mp3").toString()
        val audioFile = AudioFile(reciterId, key, url)
        coEvery { downloadDao.get(key, reciterId) } returns null

        repository.enqueueDownload(audioFile)

        kotlinx.coroutines.delay(300)

        coVerify {
            downloadDao.updateProgress(key, reciterId, DownloadStatus.FAILED.name, any(), any(), match { it != null }, any())
        }
    }

    @Test
    fun `observeDownloadProgress emits from dao`() = runTest {
        val progress = DownloadProgress(key, reciterId, DownloadStatus.DOWNLOADING, 500, 1000)
        coEvery { downloadDao.observe(key, reciterId) } returns flowOf(
            DownloadEntity(
                audioKey = key,
                reciterId = reciterId,
                remoteUrl = "https://example.com/002255.mp3",
                localPath = "/tmp/002255.mp3",
                status = DownloadStatus.DOWNLOADING.name,
                bytesDownloaded = 500,
                totalBytes = 1000,
            )
        )

        repository.observeDownloadProgress(key, reciterId).test {
            val item = awaitItem()
            assertEquals(DownloadStatus.DOWNLOADING, item.status)
            assertEquals(500L, item.bytesDownloaded)
            assertEquals(1000L, item.totalBytes)
            awaitComplete()
        }
    }

    @Test
    fun `isDownloaded returns true when dao has COMPLETE record`() = runTest {
        coEvery { downloadDao.getCompletedPath(key, reciterId) } returns "/tmp/$key.mp3"

        assertTrue(repository.isDownloaded(key, reciterId))
    }
}
