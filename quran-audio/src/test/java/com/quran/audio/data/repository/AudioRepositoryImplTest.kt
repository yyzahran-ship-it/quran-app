package com.quran.audio.data.repository

import com.quran.audio.data.local.dao.ReciterDao
import com.quran.audio.data.local.entity.ReciterEntity
import com.quran.audio.data.remote.AudioApiService
import com.quran.audio.data.remote.dto.ReciterDto
import com.quran.audio.data.remote.dto.RecitersResponse
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class AudioRepositoryImplTest {

    private val reciterDao: ReciterDao = mockk(relaxed = true)
    private val api: AudioApiService = mockk()
    private val repository = AudioRepositoryImpl(reciterDao, api)

    private val entityAlafasy = ReciterEntity(
        id = 7,
        name = "Mishary Alafasy",
        relativePath = "mishaari_raashid_al_3afaasee",
        hasGaplessDatabase = true,
        audioExtension = "mp3",
        gaplessDatabaseUrl = null,
        cachedAt = System.currentTimeMillis(),
    )

    @Test
    fun `getReciters returns cached data when not stale`() = runTest {
        coEvery { reciterDao.getCacheTimestamp() } returns System.currentTimeMillis()
        coEvery { reciterDao.getAll() } returns listOf(entityAlafasy)

        val result = repository.getReciters(forceRefresh = false)

        assertEquals(1, result.size)
        assertEquals("Mishary Alafasy", result[0].name)
        // Network should NOT be called since cache is fresh
        coVerify(exactly = 0) { api.getVerseByVerseReciters(any()) }
    }

    @Test
    fun `getReciters refreshes when cache is stale`() = runTest {
        val staleTimestamp = System.currentTimeMillis() - 25 * 60 * 60 * 1000L // 25 h ago
        coEvery { reciterDao.getCacheTimestamp() } returns staleTimestamp
        coEvery { api.getVerseByVerseReciters(any()) } returns RecitersResponse(
            reciters = listOf(
                ReciterDto(id = 7, name = "Mishary Alafasy", reciterName = "Mishary Alafasy",
                    relativePath = "mishaari_raashid_al_3afaasee", hasGaplessAudio = true)
            )
        )
        coEvery { reciterDao.getAll() } returns listOf(entityAlafasy)

        repository.getReciters(forceRefresh = false)

        coVerify { api.getVerseByVerseReciters(any()) }
        coVerify { reciterDao.upsertAll(any()) }
    }

    @Test
    fun `getAudioFile builds correct CDN URL`() = runTest {
        coEvery { reciterDao.getById(7) } returns entityAlafasy

        val file = repository.getAudioFile(reciterId = 7, key = "002255")

        assertEquals("002255", file.key)
        assertEquals(
            "https://verses.quran.com/mishaari_raashid_al_3afaasee/002255.mp3",
            file.remoteUrl,
        )
    }

    @Test
    fun `getAudioFilesForRange returns one file per key`() = runTest {
        coEvery { reciterDao.getById(7) } returns entityAlafasy

        val keys = listOf("002255", "002256", "002257")
        val files = repository.getAudioFilesForRange(7, keys)

        assertEquals(3, files.size)
        assertEquals("002256", files[1].key)
    }
}
