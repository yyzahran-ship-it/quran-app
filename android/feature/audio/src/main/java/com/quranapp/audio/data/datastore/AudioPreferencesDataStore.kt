package com.quranapp.audio.data.datastore

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.quranapp.audio.domain.repository.RepeatMode
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AudioPreferencesDataStore @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) {
    private val keyReciterId = intPreferencesKey("last_reciter_id")
    private val keySurahNumber = intPreferencesKey("last_surah_number")
    private val keyAyahIndex = intPreferencesKey("last_ayah_index")
    private val keySpeed = floatPreferencesKey("playback_speed")
    private val keyRepeat = stringPreferencesKey("repeat_mode")

    suspend fun getLastReciterId(): Int =
        dataStore.data.map { it[keyReciterId] ?: 1 }.first()

    suspend fun setLastReciterId(id: Int) {
        dataStore.edit { it[keyReciterId] = id }
    }

    suspend fun getLastSurahNumber(): Int =
        dataStore.data.map { it[keySurahNumber] ?: 1 }.first()

    suspend fun setLastSurahNumber(surah: Int) {
        dataStore.edit { it[keySurahNumber] = surah }
    }

    suspend fun getLastAyahIndex(): Int =
        dataStore.data.map { it[keyAyahIndex] ?: 0 }.first()

    suspend fun setLastAyahIndex(index: Int) {
        dataStore.edit { it[keyAyahIndex] = index }
    }

    suspend fun getPlaybackSpeed(): Float =
        dataStore.data.map { it[keySpeed] ?: 1.0f }.first()

    suspend fun setPlaybackSpeed(speed: Float) {
        dataStore.edit { it[keySpeed] = speed }
    }

    suspend fun getRepeatMode(): RepeatMode {
        val raw = dataStore.data.map { it[keyRepeat] ?: RepeatMode.NONE.name }.first()
        return RepeatMode.entries.firstOrNull { it.name == raw } ?: RepeatMode.NONE
    }

    suspend fun setRepeatMode(mode: RepeatMode) {
        dataStore.edit { it[keyRepeat] = mode.name }
    }
}
