package com.quranapp.audio.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import com.quranapp.audio.data.local.AudioDatabase
import com.quranapp.audio.data.local.dao.AudioDownloadDao
import com.quranapp.audio.data.repository.AudioRepositoryImpl
import com.quranapp.audio.domain.repository.AudioRepository
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

private val Context.audioDataStore: DataStore<Preferences> by preferencesDataStore(name = "audio_prefs")

@Module
@InstallIn(SingletonComponent::class)
abstract class AudioModule {

    @Binds
    @Singleton
    abstract fun bindAudioRepository(impl: AudioRepositoryImpl): AudioRepository

    companion object {

        @Provides
        @Singleton
        fun provideAudioDatabase(@ApplicationContext context: Context): AudioDatabase =
            Room.databaseBuilder(context, AudioDatabase::class.java, AudioDatabase.DATABASE_NAME)
                .fallbackToDestructiveMigration()
                .build()

        @Provides
        @Singleton
        fun provideDownloadDao(db: AudioDatabase): AudioDownloadDao = db.downloadDao()

        @Provides
        @Singleton
        fun provideAudioDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
            context.audioDataStore
    }
}
