package com.quran.audio.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.quran.audio.data.local.entity.ReciterEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ReciterDao {

    @Query("SELECT * FROM reciters ORDER BY id ASC")
    fun observeAll(): Flow<List<ReciterEntity>>

    @Query("SELECT * FROM reciters ORDER BY id ASC")
    suspend fun getAll(): List<ReciterEntity>

    @Query("SELECT * FROM reciters WHERE id = :id")
    suspend fun getById(id: Int): ReciterEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(reciters: List<ReciterEntity>)

    @Query("SELECT cachedAt FROM reciters LIMIT 1")
    suspend fun getCacheTimestamp(): Long?

    @Query("DELETE FROM reciters")
    suspend fun deleteAll()
}
