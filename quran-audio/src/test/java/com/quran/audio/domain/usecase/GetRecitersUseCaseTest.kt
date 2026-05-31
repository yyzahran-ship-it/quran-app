package com.quran.audio.domain.usecase

import com.quran.audio.domain.model.Reciter
import com.quran.audio.domain.repository.AudioRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class GetRecitersUseCaseTest {

    private val repository: AudioRepository = mockk()
    private val useCase = GetRecitersUseCase(repository)

    private val sampleReciters = listOf(
        Reciter(7, "Mishary Alafasy", "mishaari_raashid_al_3afaasee", true, "mp3", null),
        Reciter(1, "AbdulBaset AbdulSamad", "AbdulBaset_AbdulSamad_192kbps", false, "mp3", null),
    )

    @Test
    fun `invoke returns reciters from repository`() = runTest {
        coEvery { repository.getReciters(forceRefresh = false) } returns sampleReciters

        val result = useCase()

        assertEquals(sampleReciters, result)
    }

    @Test
    fun `invoke with forceRefresh passes flag to repository`() = runTest {
        coEvery { repository.getReciters(forceRefresh = true) } returns sampleReciters

        useCase(forceRefresh = true)

        coVerify { repository.getReciters(forceRefresh = true) }
    }

    @Test
    fun `observe delegates to repository flow`() = runTest {
        coEvery { repository.observeReciters() } returns flowOf(sampleReciters)

        val flow = useCase.observe()

        // Just verify it's wired up — detailed Flow tests use Turbine
        flow.collect { list ->
            assertEquals(sampleReciters, list)
        }
    }
}
