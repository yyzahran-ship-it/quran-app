package com.quran.audio.data.repository

import com.quran.audio.data.local.dao.ReciterDao
import com.quran.audio.data.local.entity.ReciterEntity
import com.quran.audio.data.remote.AudioApiService
import com.quran.audio.domain.model.AudioFile
import com.quran.audio.domain.model.Reciter
import com.quran.audio.domain.repository.AudioRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private const val CACHE_TTL_MS = 24 * 60 * 60 * 1000L // 24 hours

@Singleton
class AudioRepositoryImpl @Inject constructor(
    private val reciterDao: ReciterDao,
    private val api: AudioApiService,
) : AudioRepository {

    override fun observeReciters(): Flow<List<Reciter>> =
        reciterDao.observeAll().map { entities -> entities.map { it.toDomain() } }

    override suspend fun getReciters(forceRefresh: Boolean): List<Reciter> {
        val cacheTs = reciterDao.getCacheTimestamp()
        val stale = cacheTs == null || (System.currentTimeMillis() - cacheTs) > CACHE_TTL_MS
        if (forceRefresh || stale) {
            refreshReciters()
        }
        return reciterDao.getAll().map { it.toDomain() }
    }

    private suspend fun refreshReciters() {
        val response = api.getVerseByVerseReciters()
        val reciters = (response.reciters ?: response.audioFiles) ?: return
        val entities = reciters.map { dto ->
            ReciterEntity(
                id = dto.id,
                name = dto.reciterName ?: dto.name,
                relativePath = dto.relativePath ?: dto.slug ?: dto.fileName ?: "",
                hasGaplessDatabase = dto.hasGaplessAudio,
                audioExtension = dto.format ?: "mp3",
                gaplessDatabaseUrl = dto.audioUrl,
            )
        }
        reciterDao.upsertAll(entities)
    }

    override suspend fun getAudioFile(reciterId: Int, key: String): AudioFile {
        val reciter = reciterDao.getById(reciterId)
            ?: error("Reciter $reciterId not found in local DB")
        val (surah, ayah) = parseKey(key)
        val url = buildUrl(reciter.relativePath, surah, ayah, reciter.audioExtension)
        return AudioFile(
            reciterId = reciterId,
            key = key,
            remoteUrl = url,
        )
    }

    override suspend fun getAudioFilesForRange(reciterId: Int, keys: List<String>): List<AudioFile> {
        val reciter = reciterDao.getById(reciterId)
            ?: error("Reciter $reciterId not found in local DB")
        return keys.map { key ->
            val (surah, ayah) = parseKey(key)
            AudioFile(
                reciterId = reciterId,
                key = key,
                remoteUrl = buildUrl(reciter.relativePath, surah, ayah, reciter.audioExtension),
            )
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    /** key format is SSSAAA (zero-padded surah + ayah, 3 digits each) */
    private fun parseKey(key: String): Pair<Int, Int> {
        require(key.length == 6) { "Invalid key: $key" }
        return key.substring(0, 3).toInt() to key.substring(3, 6).toInt()
    }

    /** Builds the CDN URL matching Quran.com's layout. */
    private fun buildUrl(relativePath: String, surah: Int, ayah: Int, ext: String): String {
        val surahPart = surah.toString().padStart(3, '0')
        val ayahPart = ayah.toString().padStart(3, '0')
        return "https://verses.quran.com/$relativePath/$surahPart$ayahPart.$ext"
    }

    private fun ReciterEntity.toDomain() = Reciter(
        id = id,
        name = name,
        relativePath = relativePath,
        hasGaplessDatabase = hasGaplessDatabase,
        audioExtension = audioExtension,
        gaplessDatabaseUrl = gaplessDatabaseUrl,
    )
}
