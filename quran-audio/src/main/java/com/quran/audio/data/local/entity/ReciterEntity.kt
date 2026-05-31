package com.quran.audio.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "reciters")
data class ReciterEntity(
    @PrimaryKey val id: Int,
    val name: String,
    val relativePath: String,
    val hasGaplessDatabase: Boolean,
    val audioExtension: String,
    val gaplessDatabaseUrl: String?,
    /** Epoch millis when this row was last refreshed from the network. */
    val cachedAt: Long = System.currentTimeMillis(),
)
