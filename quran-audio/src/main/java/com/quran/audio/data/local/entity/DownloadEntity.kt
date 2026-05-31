package com.quran.audio.data.local.entity

import androidx.room.Entity
import androidx.room.Index

@Entity(
    tableName = "downloads",
    primaryKeys = ["audioKey", "reciterId"],
    indices = [
        Index("reciterId"),
        Index("status"),
    ],
)
data class DownloadEntity(
    val audioKey: String,
    val reciterId: Int,
    val remoteUrl: String,
    /** Absolute path where the file will be saved / has been saved. */
    val localPath: String,
    /** Serialised [com.quran.audio.domain.model.DownloadStatus] name. */
    val status: String,
    val bytesDownloaded: Long = 0L,
    val totalBytes: Long = 0L,
    val errorMessage: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
)
