package com.quranapp.audio

import app.cash.turbine.test
import com.quranapp.audio.domain.model.AudioPlaybackState
import com.quranapp.audio.domain.model.Reciter
import com.quranapp.audio.domain.repository.AudioRepository
import com.quranapp.audio.domain.repository.RepeatMode
import com.quranapp.audio.presentation.AudioPlayerViewModel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AudioPlayerViewModelTest {

    private val dispatcher = StandardTestDispatcher()
    private val stateFlow = MutableStateFlow<AudioPlaybackState>(AudioPlaybackState.Idle)
    private val repository = mockk<AudioRepository>(relaxed = true) {
        every { playbackState } returns stateFlow
        every { getReciters() } returns emptyList()
    }

    @BeforeEach
    fun setUp() { Dispatchers.setMain(dispatcher) }

    @AfterEach
    fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `initial uiState is not playing`() = runTest {
        val vm = AudioPlayerViewModel(repository)
        dispatcher.scheduler.advanceUntilIdle()
        assertFalse(vm.uiState.value.isPlaying)
    }

    @Test
    fun `playing state updates uiState isPlaying to true`() = runTest {
        val vm = AudioPlayerViewModel(repository)
        val reciter = Reciter(1, "Test", "اختبار", "test/", false)
        stateFlow.value = AudioPlaybackState.Playing(reciter, 1, 0, 1000L, 30_000L)
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(vm.uiState.value.isPlaying)
    }

    @Test
    fun `togglePlayPause calls pause when playing`() = runTest {
        val reciter = Reciter(1, "Test", "اختبار", "test/", false)
        stateFlow.value = AudioPlaybackState.Playing(reciter, 1, 0, 0L, 0L)
        val vm = AudioPlayerViewModel(repository)
        dispatcher.scheduler.advanceUntilIdle()
        vm.togglePlayPause()
        dispatcher.scheduler.advanceUntilIdle()
        coVerify { repository.pause() }
    }
}
