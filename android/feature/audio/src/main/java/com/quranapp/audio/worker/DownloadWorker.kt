package com.quranapp.audio.worker

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.quranapp.audio.catalog.ReciterCatalog
import com.quranapp.audio.domain.repository.AudioRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

@HiltWorker
class DownloadWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: AudioRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val reciterId = inputData.getInt(KEY_RECITER_ID, -1)
        val surahNumber = inputData.getInt(KEY_SURAH_NUMBER, -1)

        if (reciterId == -1 || surahNumber == -1) return Result.failure()

        val reciter = ReciterCatalog.findById(reciterId)
            ?: return Result.failure(workDataOf("error" to "Unknown reciter $reciterId"))

        return try {
            repository.downloadSurah(reciter, surahNumber)
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry()
            else Result.failure(workDataOf("error" to (e.message ?: "Download failed")))
        }
    }

    companion object {
        const val KEY_RECITER_ID = "reciter_id"
        const val KEY_SURAH_NUMBER = "surah_number"
    }
}
