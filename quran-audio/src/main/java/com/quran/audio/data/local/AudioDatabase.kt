package com.quran.audio.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.quran.audio.data.local.dao.DownloadDao
import com.quran.audio.data.local.dao.ReciterDao
import com.quran.audio.data.local.dao.TimingDao
import com.quran.audio.data.local.entity.DownloadEntity
import com.quran.audio.data.local.entity.ReciterEntity
import com.quran.audio.data.local.entity.TimingEntity

@Database(
    entities = [
        ReciterEntity::class,
        DownloadEntity::class,
        TimingEntity::class,
    ],
    version = 1,
    exportSchema = true,
)
abstract class AudioDatabase : RoomDatabase() {
    abstract fun reciterDao(): ReciterDao
    abstract fun downloadDao(): DownloadDao
    abstract fun timingDao(): TimingDao

    companion object {
        const val DATABASE_NAME = "quran_audio.db"
    }
}
