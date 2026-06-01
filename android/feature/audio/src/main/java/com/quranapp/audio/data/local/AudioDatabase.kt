package com.quranapp.audio.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.quranapp.audio.data.local.dao.AudioDownloadDao
import com.quranapp.audio.data.local.entity.AudioDownloadEntity

@Database(entities = [AudioDownloadEntity::class], version = 1, exportSchema = false)
abstract class AudioDatabase : RoomDatabase() {
    abstract fun downloadDao(): AudioDownloadDao

    companion object {
        const val DATABASE_NAME = "quran_audio.db"
    }
}
