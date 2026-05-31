package com.quran.audio.data.remote

import com.quran.audio.data.remote.dto.AudioFilesResponse
import com.quran.audio.data.remote.dto.RecitersResponse
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.Streaming
import retrofit2.http.Url

interface AudioApiService {

    /** List all verse-by-verse reciters. language=en returns English names. */
    @GET("resources/recitations")
    suspend fun getVerseByVerseReciters(
        @Query("language") language: String = "en",
    ): RecitersResponse

    /**
     * Fetch verse audio files for a single chapter from a given recitation.
     * recitationId corresponds to ReciterEntity.id.
     */
    @GET("recitations/{recitationId}/by_chapter/{chapterNumber}")
    suspend fun getAudioFilesForChapter(
        @Path("recitationId") recitationId: Int,
        @Path("chapterNumber") chapterNumber: Int,
    ): AudioFilesResponse

    /**
     * Fetch audio files for a range of verses.
     * verseKey format: "1:1" (surah:ayah).
     */
    @GET("recitations/{recitationId}/by_ayah/{verseKey}")
    suspend fun getAudioFileForVerse(
        @Path("recitationId") recitationId: Int,
        @Path("verseKey") verseKey: String,
    ): AudioFilesResponse

    /**
     * Stream a remote file. Callers pass the full URL.
     * @Streaming prevents buffering the entire response body in memory.
     */
    @Streaming
    @GET
    suspend fun downloadFile(@Url url: String): Response<ResponseBody>
}
