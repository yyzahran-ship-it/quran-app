package com.quran.audio.domain.usecase

import app.cash.turbine.test
import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.DownloadProgress
import com.quran.audio.domain.model.DownloadStatus
import com.quran.audio.domain.repository.AudioRepository
import com.quran.audio.domain.repository.DownloadRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class DownloadAudioUseCaseTest {

    private val audioRepository: AudioRepository = mockk()
    private val downloadRepository: DownloadRepository = mockk()
    private val useCase = DownloadAudioUseCase(audioRepository, downloadRepository)

    private val reciterId = 7
    private val key = "002255"
    private val audioFile = AudioFile(
        reciterId = reciterId,
        key = key,
        remoteUrl = "https://verses.quran.com/mishaari/002255.mp3",
    )

    @Test
    fun `downloadFile fetches audio file and enqueues it`() = runTest {
        coEvery { audioRepository.getAudioFile(reciterId, key) } returns audioFile
        coEvery { downloadRepository.enqueueDownload(audioFile) } returns true

        val result = useCase.downloadFile(reciterId, key)

        assertTrue(result)
        coVerify { audioRepository.getAudioFile(reciterId, key) }
        coVerify { downloadRepository.enqueueDownload(audioFile) }
    }

    @Test
    fun `downloadRange enqueues all files`() = runTest {
        val keys = listOf("002255", "002256", "002257")
        val files = keys.map { audioFile.copy(key = it) }
        coEvery { audioRepository.getAudioFilesForRange(reciterId, keys) } returns files
        files.forEach { coEvery { downloadRepository.enqueueDownload(it) } returns true }

        val results = useCase.downloadRange(reciterId, keys)

        assertEquals(3, results.size)
        assertTrue(results.all { it })
    }

    @Test
    fun `observeProgress emits progress from repository`() = runTest {
        val progress = DownloadProgress(key, reciterId, DownloadStatus.DOWNLOADING, 500, 1000)
        coEvery { downloadRepository.observeDownloadProgress(key, reciterId) } returns flowOf(progress)

        useCase.observeProgress(key, reciterId).test {
            assertEquals(progress, awaitItem())
            awaitComplete()
        }
    }

    @Test
    fun `cancelDownload delegates to repository`() = runTest {
        coEvery { downloadRepository.cancelDownload(key, reciterId) } returns Unit

        useCase.cancelDownload(key, reciterId)

        coVerify { downloadRepository.cancelDownload(key, reciterId) }
    }

    @Test
    fun `isDownloaded returns true when file is locally cached`() = runTest {
        coEvery { downloadRepository.isDownloaded(key, reciterId) } returns true

        assertTrue(useCase.isDownloaded(key, reciterId))
    }
}
