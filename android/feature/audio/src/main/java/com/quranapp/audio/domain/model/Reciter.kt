package com.quranapp.audio.domain.model

data class Reciter(
    val id: Int,
    val name: String,
    val arabicName: String,
    val relativePath: String,
    val hasGaplessAudio: Boolean,
    val imageUrl: String? = null,
)
