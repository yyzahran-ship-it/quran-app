package com.quran.audio.domain.model

data class DownloadProgress(
    val audioKey: String,
    val reciterId: Int,
    val state: DownloadStatus,
    val bytesDownloaded: Long = 0L,
    val totalBytes: Long = 0L,
    val errorMessage: String? = null,
) {
    /** Integer 0–100; -1 if total size is unknown. */
    val percentage: Int
        get() = if (totalBytes > 0) ((bytesDownloaded * 100) / totalBytes).toInt() else -1
}

enum class DownloadStatus {
    PENDING,
    DOWNLOADING,
    COMPLETE,
    FAILED,
    CANCELLED,
    PAUSED,
}
