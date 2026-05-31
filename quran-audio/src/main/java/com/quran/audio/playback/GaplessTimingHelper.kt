package com.quran.audio.playback

import com.quran.audio.data.local.dao.TimingDao
import com.quran.audio.data.local.entity.TimingEntity
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Maps playback positions within a gapless surah MP3 to individual ayah numbers.
 *
 * In gapless mode a single MP3 file covers an entire surah. The timing DB
 * stores the millisecond offset at which each ayah begins, matching the
 * "glide" table format from quran_android's GaplessAudioDbAdapter.
 */
@Singleton
class GaplessTimingHelper @Inject constructor(
    private val timingDao: TimingDao,
) {

    /**
     * Returns the ayah number that is active at [positionMs] inside [surah]'s gapless MP3.
     * Returns 1 if no timing data is available.
     */
    suspend fun ayahAtPosition(reciterId: Int, surah: Int, positionMs: Long): Int =
        timingDao.getAyahAtPosition(reciterId, surah, positionMs) ?: 1

    /**
     * Returns the start offset in milliseconds for [ayah] within [surah]'s MP3.
     * Returns 0 if not found, so playback starts from the beginning.
     */
    suspend fun startTimeForAyah(reciterId: Int, surah: Int, ayah: Int): Long {
        val timings = timingDao.getTimingsForSurah(reciterId, surah)
        return timings.firstOrNull { it.ayahNumber == ayah }?.startTime ?: 0L
    }

    /**
     * Returns the end offset for [ayah] — i.e. the startTime of the next ayah,
     * or [totalDurationMs] if this is the last ayah.
     */
    suspend fun endTimeForAyah(
        reciterId: Int,
        surah: Int,
        ayah: Int,
        totalDurationMs: Long,
    ): Long {
        val timings = timingDao.getTimingsForSurah(reciterId, surah)
        val idx = timings.indexOfFirst { it.ayahNumber == ayah }
        return if (idx >= 0 && idx + 1 < timings.size) timings[idx + 1].startTime
        else totalDurationMs
    }

    /** Stores timing data fetched from the network for a given reciter/surah. */
    suspend fun storeTiming(reciterId: Int, surah: Int, timings: List<Pair<Int, Long>>) {
        val entities = timings.map { (ayah, startMs) ->
            TimingEntity(reciterId, surah, ayah, startMs)
        }
        timingDao.deleteForSurah(reciterId, surah)
        timingDao.insertAll(entities)
    }

    suspend fun hasTimingData(reciterId: Int, surah: Int): Boolean =
        timingDao.countForSurah(reciterId, surah) > 0
}
