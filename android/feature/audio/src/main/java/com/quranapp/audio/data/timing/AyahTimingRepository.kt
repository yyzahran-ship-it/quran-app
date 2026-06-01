package com.quranapp.audio.data.timing

import com.quranapp.audio.catalog.ReciterCatalog
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Maps playback position (ms) to ayah number for gapless surahs.
 * Al-Fatiha timings are exact; all other surahs use equal-duration estimates.
 */
@Singleton
class AyahTimingRepository @Inject constructor() {

    // ayah 1-indexed, time in ms. Source: quranicaudio.com/quran/12 (Alafasy Fatiha)
    private val fatihaTimingsMs = listOf(
        1 to 0L,
        2 to 3900L,
        3 to 8800L,
        4 to 15600L,
        5 to 20700L,
        6 to 25200L,
        7 to 30900L,
    )

    /**
     * Returns the 1-based ayah number at [positionMs] for [surahNumber].
     * Falls back to ayah 1 if timing data is unavailable.
     */
    fun ayahAtPosition(surahNumber: Int, positionMs: Long, totalDurationMs: Long): Int {
        val timings = buildTimings(surahNumber, totalDurationMs)
        return timings.lastOrNull { (_, startMs) -> positionMs >= startMs }?.first ?: 1
    }

    /** Returns the start time (ms) for the given 1-based [ayahNumber] in [surahNumber]. */
    fun startTimeForAyah(surahNumber: Int, ayahNumber: Int, totalDurationMs: Long): Long {
        val timings = buildTimings(surahNumber, totalDurationMs)
        return timings.firstOrNull { (a, _) -> a == ayahNumber }?.second ?: 0L
    }

    private fun buildTimings(surahNumber: Int, totalDurationMs: Long): List<Pair<Int, Long>> {
        if (surahNumber == 1) return fatihaTimingsMs

        val ayahCount = ReciterCatalog.SURAH_AYAH_COUNTS.getOrElse(surahNumber) { 1 }
        if (totalDurationMs <= 0L || ayahCount <= 0) return listOf(1 to 0L)

        val msPerAyah = totalDurationMs / ayahCount
        return (1..ayahCount).map { ayah -> ayah to (ayah - 1) * msPerAyah }
    }
}
