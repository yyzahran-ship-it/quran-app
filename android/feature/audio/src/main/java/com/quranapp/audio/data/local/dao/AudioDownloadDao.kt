package com.quranapp.audio.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.quranapp.audio.data.local.entity.AudioDownloadEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface AudioDownloadDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: AudioDownloadEntity)

    @Query("SELECT * FROM audio_downloads WHERE reciterId = :reciterId AND surahNumber = :surahNumber LIMIT 1")
    suspend fun get(reciterId: Int, surahNumber: Int): AudioDownloadEntity?

    @Query("SELECT * FROM audio_downloads WHERE reciterId = :reciterId")
    fun observeForReciter(reciterId: Int): Flow<List<AudioDownloadEntity>>

    @Query("DELETE FROM audio_downloads WHERE reciterId = :reciterId AND surahNumber = :surahNumber")
    suspend fun delete(reciterId: Int, surahNumber: Int)
}
