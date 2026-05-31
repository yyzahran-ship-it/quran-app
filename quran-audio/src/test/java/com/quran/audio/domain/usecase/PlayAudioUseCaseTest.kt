package com.quran.audio.domain.usecase

import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.RepeatMode
import com.quran.audio.domain.repository.AudioRepository
import com.quran.audio.domain.repository.DownloadRepository
import com.quran.audio.playback.AudioQueueManager
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test

class PlayAudioUseCaseTest {

    private val audioRepository: AudioRepository = mockk()
    private val downloadRepository: DownloadRepository = mockk()
    private val queueManager: AudioQueueManager = mockk(relaxed = true)
    private val useCase = PlayAudioUseCase(audioRepository, downloadRepository, queueManager)

    private val reciterId = 7
    private val keys = listOf("002255", "002256", "002257")
    private val audioFiles = keys.map { key ->
        AudioFile(reciterId = reciterId, key = key, remoteUrl = "https://cdn.example.com/$key.mp3")
    }

    @Test
    fun `invoke loads queue and starts playback`() = runTest {
        coEvery { audioRepository.getAudioFilesForRange(reciterId, keys) } returns audioFiles
        coEvery { downloadRepository.getDownloadedPath(any(), any()) } returns null

        useCase(reciterId, startKey = "002255", keys = keys)

        coVerify { queueManager.setQueue(audioFiles, 0) }
        verify { queueManager.play() }
    }

    @Test
    fun `invoke prefers local path when file is downloaded`() = runTest {
        val localPath = "/data/data/com.quran.app/files/quran_audio/7/002255.mp3"
        coEvery { audioRepository.getAudioFilesForRange(reciterId, keys) } returns audioFiles
        coEvery { downloadRepository.getDownloadedPath("002255", reciterId) } returns localPath
        coEvery { downloadRepository.getDownloadedPath("002256", reciterId) } returns null
        coEvery { downloadRepository.getDownloadedPath("002257", reciterId) } returns null

        useCase(reciterId, startKey = "002255", keys = keys)

        coVerify {
            queueManager.setQueue(
                match { files ->
                    files[0].localPath == localPath && files[0].isDownloaded &&
                        files[1].localPath == null && !files[1].isDownloaded
                },
                0,
            )
        }
    }

    @Test
    fun `invoke finds correct start index when startKey is not first in list`() = runTest {
        coEvery { audioRepository.getAudioFilesForRange(reciterId, keys) } returns audioFiles
        coEvery { downloadRepository.getDownloadedPath(any(), any()) } returns null

        useCase(reciterId, startKey = "002256", keys = keys)

        coVerify { queueManager.setQueue(any(), 1) }
    }

    @Test
    fun `setRepeatMode delegates to queueManager`() {
        useCase.setRepeatMode(RepeatMode.REPEAT_ONE)
        verify { queueManager.setRepeatMode(RepeatMode.REPEAT_ONE) }
    }

    @Test
    fun `setSpeed delegates to queueManager`() {
        useCase.setSpeed(1.5f)
        verify { queueManager.setSpeed(1.5f) }
    }
}
