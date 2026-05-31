package com.quran.audio.playback

import com.quran.audio.data.local.dao.TimingDao
import com.quran.audio.data.local.entity.TimingEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class GaplessTimingHelperTest {

    private val timingDao: TimingDao = mockk()
    private val helper = GaplessTimingHelper(timingDao)

    private val reciterId = 7
    private val surah = 2

    private val timings = listOf(
        TimingEntity(reciterId, surah, ayahNumber = 1, startTime = 0L),
        TimingEntity(reciterId, surah, ayahNumber = 2, startTime = 5_000L),
        TimingEntity(reciterId, surah, ayahNumber = 3, startTime = 12_000L),
        TimingEntity(reciterId, surah, ayahNumber = 4, startTime = 18_500L),
    )

    @Test
    fun `ayahAtPosition returns correct ayah for mid-ayah position`() = runTest {
        coEvery { timingDao.getAyahAtPosition(reciterId, surah, 7_000L) } returns 2

        val result = helper.ayahAtPosition(reciterId, surah, 7_000L)

        assertEquals(2, result)
    }

    @Test
    fun `ayahAtPosition returns 1 when no data`() = runTest {
        coEvery { timingDao.getAyahAtPosition(reciterId, surah, 0L) } returns null

        val result = helper.ayahAtPosition(reciterId, surah, 0L)

        assertEquals(1, result)
    }

    @Test
    fun `startTimeForAyah returns correct offset`() = runTest {
        coEvery { timingDao.getTimingsForSurah(reciterId, surah) } returns timings

        val start = helper.startTimeForAyah(reciterId, surah, ayah = 3)

        assertEquals(12_000L, start)
    }

    @Test
    fun `startTimeForAyah returns 0 when ayah not found`() = runTest {
        coEvery { timingDao.getTimingsForSurah(reciterId, surah) } returns timings

        val start = helper.startTimeForAyah(reciterId, surah, ayah = 99)

        assertEquals(0L, start)
    }

    @Test
    fun `endTimeForAyah returns next ayah's start time`() = runTest {
        coEvery { timingDao.getTimingsForSurah(reciterId, surah) } returns timings

        val end = helper.endTimeForAyah(reciterId, surah, ayah = 2, totalDurationMs = 120_000L)

        assertEquals(12_000L, end) // ayah 3's start
    }

    @Test
    fun `endTimeForAyah returns totalDurationMs for last ayah`() = runTest {
        coEvery { timingDao.getTimingsForSurah(reciterId, surah) } returns timings

        val end = helper.endTimeForAyah(reciterId, surah, ayah = 4, totalDurationMs = 120_000L)

        assertEquals(120_000L, end)
    }

    @Test
    fun `storeTiming clears old data and inserts new entries`() = runTest {
        val newTimings = listOf(1 to 0L, 2 to 5000L, 3 to 12000L)
        coEvery { timingDao.deleteForSurah(reciterId, surah) } returns Unit
        coEvery { timingDao.insertAll(any()) } returns Unit

        helper.storeTiming(reciterId, surah, newTimings)

        coVerify { timingDao.deleteForSurah(reciterId, surah) }
        coVerify {
            timingDao.insertAll(
                match { entities ->
                    entities.size == 3 &&
                        entities[0].startTime == 0L &&
                        entities[1].startTime == 5000L
                }
            )
        }
    }
}
