package com.quranapp.audio.data.local.entity

import androidx.room.Entity

@Entity(tableName = "audio_downloads", primaryKeys = ["reciterId", "surahNumber"])
data class AudioDownloadEntity(
    val reciterId: Int,
    val surahNumber: Int,
    val localFilePath: String,
    val downloadedAt: Long = System.currentTimeMillis(),
)
