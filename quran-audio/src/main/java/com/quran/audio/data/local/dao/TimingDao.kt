package com.quran.audio.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.quran.audio.data.local.entity.TimingEntity

@Dao
interface TimingDao {

    /** Returns all timing rows for a surah, ordered by startTime ascending. */
    @Query("""
        SELECT * FROM timing
        WHERE reciterId = :reciterId AND surahNumber = :surah
        ORDER BY startTime ASC
    """)
    suspend fun getTimingsForSurah(reciterId: Int, surah: Int): List<TimingEntity>

    /**
     * Returns the ayah number that is playing at [positionMs] within [surah]'s MP3.
     * Uses the largest startTime that is <= positionMs.
     */
    @Query("""
        SELECT ayahNumber FROM timing
        WHERE reciterId = :reciterId AND surahNumber = :surah AND startTime <= :positionMs
        ORDER BY startTime DESC
        LIMIT 1
    """)
    suspend fun getAyahAtPosition(reciterId: Int, surah: Int, positionMs: Long): Int?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(timings: List<TimingEntity>)

    @Query("DELETE FROM timing WHERE reciterId = :reciterId AND surahNumber = :surah")
    suspend fun deleteForSurah(reciterId: Int, surah: Int)

    @Query("DELETE FROM timing WHERE reciterId = :reciterId")
    suspend fun deleteForReciter(reciterId: Int)

    @Query("SELECT COUNT(*) FROM timing WHERE reciterId = :reciterId AND surahNumber = :surah")
    suspend fun countForSurah(reciterId: Int, surah: Int): Int
}
