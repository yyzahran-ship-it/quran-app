package com.quran.audio.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.quran.audio.data.local.entity.DownloadEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DownloadDao {

    @Query("SELECT * FROM downloads WHERE audioKey = :key AND reciterId = :reciterId")
    fun observe(key: String, reciterId: Int): Flow<DownloadEntity?>

    @Query("SELECT * FROM downloads")
    fun observeAll(): Flow<List<DownloadEntity>>

    @Query("SELECT * FROM downloads WHERE audioKey = :key AND reciterId = :reciterId")
    suspend fun get(key: String, reciterId: Int): DownloadEntity?

    @Query("SELECT * FROM downloads WHERE status = :status")
    suspend fun getByStatus(status: String): List<DownloadEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: DownloadEntity)

    @Update
    suspend fun update(entity: DownloadEntity)

    @Query("""
        UPDATE downloads
        SET status = :status, bytesDownloaded = :bytes, totalBytes = :total,
            errorMessage = :error, updatedAt = :updatedAt
        WHERE audioKey = :key AND reciterId = :reciterId
    """)
    suspend fun updateProgress(
        key: String,
        reciterId: Int,
        status: String,
        bytes: Long,
        total: Long,
        error: String?,
        updatedAt: Long,
    )

    @Query("DELETE FROM downloads WHERE audioKey = :key AND reciterId = :reciterId")
    suspend fun delete(key: String, reciterId: Int)

    @Query("SELECT localPath FROM downloads WHERE audioKey = :key AND reciterId = :reciterId AND status = 'COMPLETE'")
    suspend fun getCompletedPath(key: String, reciterId: Int): String?
}
