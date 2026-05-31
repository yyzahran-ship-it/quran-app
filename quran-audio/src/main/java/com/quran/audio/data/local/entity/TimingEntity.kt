package com.quran.audio.data.local.entity

import androidx.room.Entity
import androidx.room.Index

/**
 * Row from the gapless timing database.
 *
 * In gapless mode a single MP3 per surah is used. This table maps the
 * millisecond offset within that MP3 to an individual ayah number, mirroring
 * the "glide" table format used in quran/quran_android's GaplessAudioDbAdapter.
 *
 * The original DB has columns: (sura INTEGER, ayah INTEGER, startTime INTEGER).
 * We store reciterId additionally so multiple reciters share one Room database.
 */
@Entity(
    tableName = "timing",
    primaryKeys = ["reciterId", "surahNumber", "ayahNumber"],
    indices = [
        Index(value = ["reciterId", "surahNumber"]),
    ],
)
data class TimingEntity(
    val reciterId: Int,
    val surahNumber: Int,
    val ayahNumber: Int,
    /** Start of this ayah within the surah MP3, in milliseconds. */
    val startTime: Long,
)
