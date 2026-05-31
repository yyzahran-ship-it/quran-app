package com.quran.audio.di

import android.content.Context
import androidx.room.Room
import com.quran.audio.data.local.AudioDatabase
import com.quran.audio.data.local.dao.DownloadDao
import com.quran.audio.data.local.dao.ReciterDao
import com.quran.audio.data.local.dao.TimingDao
import com.quran.audio.data.remote.AudioApiService
import com.quran.audio.data.repository.AudioRepositoryImpl
import com.quran.audio.data.repository.DownloadRepositoryImpl
import com.quran.audio.domain.repository.AudioRepository
import com.quran.audio.domain.repository.DownloadRepository
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.io.File
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

private const val QURAN_API_BASE_URL = "https://api.quran.com/api/v4/"

@Module
@InstallIn(SingletonComponent::class)
abstract class AudioBindingsModule {

    @Binds
    @Singleton
    abstract fun bindAudioRepository(impl: AudioRepositoryImpl): AudioRepository

    @Binds
    @Singleton
    abstract fun bindDownloadRepository(impl: DownloadRepositoryImpl): DownloadRepository
}

@Module
@InstallIn(SingletonComponent::class)
object AudioModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .addInterceptor(
                HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.BASIC
                },
            )
            .build()

    @Provides
    @Singleton
    fun provideMoshi(): Moshi =
        Moshi.Builder()
            .addLast(KotlinJsonAdapterFactory())
            .build()

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient, moshi: Moshi): Retrofit =
        Retrofit.Builder()
            .baseUrl(QURAN_API_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()

    @Provides
    @Singleton
    fun provideAudioApiService(retrofit: Retrofit): AudioApiService =
        retrofit.create(AudioApiService::class.java)

    @Provides
    @Singleton
    fun provideAudioDatabase(@ApplicationContext context: Context): AudioDatabase =
        Room.databaseBuilder(context, AudioDatabase::class.java, AudioDatabase.DATABASE_NAME)
            .fallbackToDestructiveMigration()
            .build()

    @Provides fun provideReciterDao(db: AudioDatabase): ReciterDao = db.reciterDao()
    @Provides fun provideDownloadDao(db: AudioDatabase): DownloadDao = db.downloadDao()
    @Provides fun provideTimingDao(db: AudioDatabase): TimingDao = db.timingDao()

    @Provides
    @Singleton
    fun provideDownloadDirectory(@ApplicationContext context: Context): File =
        File(context.filesDir, "quran_audio")
}
