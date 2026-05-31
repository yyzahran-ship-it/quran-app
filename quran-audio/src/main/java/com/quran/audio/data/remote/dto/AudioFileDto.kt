package com.quran.audio.data.remote.dto

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class AudioFilesResponse(
    @Json(name = "audio_files") val audioFiles: List<AudioFileDto>,
)

@JsonClass(generateAdapter = true)
data class AudioFileDto(
    val id: Int,
    @Json(name = "chapter_id") val chapterId: Int,
    @Json(name = "file_size") val fileSize: Long? = null,
    @Json(name = "format") val format: String? = null,
    @Json(name = "audio_url") val audioUrl: String,
)

@JsonClass(generateAdapter = true)
data class TimingFilesResponse(
    @Json(name = "audio_files") val audioFiles: List<TimingFileDto>,
)

@JsonClass(generateAdapter = true)
data class TimingFileDto(
    val id: Int,
    @Json(name = "chapter_id") val chapterId: Int,
    @Json(name = "audio_url") val audioUrl: String,
    /** Direct URL to the gapless SQLite DB for this reciter/chapter combination. */
    @Json(name = "segments") val segments: List<List<Long>>? = null,
)
