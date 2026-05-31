package com.quran.audio.domain.repository

import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.Reciter
import kotlinx.coroutines.flow.Flow

interface AudioRepository {
    /**
     * Returns a list of available reciters.
     * Serves from local cache unless [forceRefresh] is true or cache is stale.
     */
    suspend fun getReciters(forceRefresh: Boolean = false): List<Reciter>

    /** Cold [Flow] that emits whenever the cached reciter list changes. */
    fun observeReciters(): Flow<List<Reciter>>

    /**
     * Returns an [AudioFile] with a valid [AudioFile.remoteUrl] and, if previously
     * downloaded, a populated [AudioFile.localPath].
     */
    suspend fun getAudioFile(reciterId: Int, key: String): AudioFile

    /** Batch variant of [getAudioFile]. Preserves input order. */
    suspend fun getAudioFilesForRange(reciterId: Int, keys: List<String>): List<AudioFile>
}
