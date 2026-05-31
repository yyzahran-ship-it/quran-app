package com.quran.audio.data.remote.dto

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class RecitersResponse(
    @Json(name = "audio_files") val audioFiles: List<ReciterDto>? = null,
    val reciters: List<ReciterDto>? = null,
)

@JsonClass(generateAdapter = true)
data class ReciterDto(
    val id: Int,
    val name: String,
    @Json(name = "reciter_name") val reciterName: String? = null,
    @Json(name = "relative_path") val relativePath: String? = null,
    @Json(name = "quranic_filename") val quranicFilename: String? = null,
    @Json(name = "file_name") val fileName: String? = null,
    @Json(name = "has_gapless_audio") val hasGaplessAudio: Boolean = false,
    @Json(name = "format") val format: String? = null,
    @Json(name = "audio_url") val audioUrl: String? = null,
    @Json(name = "slug") val slug: String? = null,
)
