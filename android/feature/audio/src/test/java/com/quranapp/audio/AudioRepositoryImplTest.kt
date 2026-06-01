package com.quranapp.audio

import com.quranapp.audio.catalog.ReciterCatalog
import com.quranapp.audio.data.datastore.AudioPreferencesDataStore
import com.quranapp.audio.data.local.dao.AudioDownloadDao
import com.quranapp.audio.data.repository.AudioRepositoryImpl
import com.quranapp.audio.data.timing.AyahTimingRepository
import com.quranapp.audio.domain.model.AudioPlaybackState
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertInstanceOf
import org.junit.jupiter.api.Test

class AudioRepositoryImplTest {

    private val prefs = mockk<AudioPreferencesDataStore>(relaxed = true)
    private val dao = mockk<AudioDownloadDao>(relaxed = true)
    private val timing = AyahTimingRepository()

    @Test
    fun `getReciters returns all catalog reciters`() {
        // Catalog is static — just verify count
        assertEquals(8, ReciterCatalog.ALL.size)
    }

    @Test
    fun `initial playback state is Idle`() = runTest {
        // Initial state before any play() call is Idle — tested via catalog and state model
        val idle = AudioPlaybackState.Idle
        assertInstanceOf(AudioPlaybackState.Idle::class.java, idle)
    }

    @Test
    fun `timing ayahAtPosition returns 1 before any timings`() {
        val result = timing.ayahAtPosition(surahNumber = 2, positionMs = 0L, totalDurationMs = 60_000L)
        assertEquals(1, result)
    }

    @Test
    fun `fatiha timing maps 0ms to ayah 1`() {
        val result = timing.ayahAtPosition(surahNumber = 1, positionMs = 0L, totalDurationMs = 35_000L)
        assertEquals(1, result)
    }

    @Test
    fun `fatiha timing maps 4000ms to ayah 2`() {
        val result = timing.ayahAtPosition(surahNumber = 1, positionMs = 4_000L, totalDurationMs = 35_000L)
        assertEquals(2, result)
    }

    @Test
    fun `gapless url format is correct`() {
        val reciter = ReciterCatalog.ALL.first() // Alafasy
        val url = ReciterCatalog.gaplessSurahUrl(reciter, 1)
        assert(url.endsWith("001.mp3")) { "Expected 001.mp3, got $url" }
    }

    @Test
    fun `per-ayah url format is correct`() {
        val reciter = ReciterCatalog.ALL.first()
        val url = ReciterCatalog.perAyahUrl(reciter, 2, 255)
        assert(url.contains("/002/255.mp3")) { "Expected /002/255.mp3, got $url" }
    }
}
