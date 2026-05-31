package com.quran.audio.domain.usecase

import com.quran.audio.domain.model.Reciter
import com.quran.audio.domain.repository.AudioRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class GetRecitersUseCase @Inject constructor(
    private val audioRepository: AudioRepository,
) {
    suspend operator fun invoke(forceRefresh: Boolean = false): List<Reciter> =
        audioRepository.getReciters(forceRefresh)

    fun observe(): Flow<List<Reciter>> = audioRepository.observeReciters()
}
