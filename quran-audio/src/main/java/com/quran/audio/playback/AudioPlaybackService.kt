package com.quran.audio.playback

import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.quran.audio.domain.model.PlaybackEvent
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Background service managing ExoPlayer and the media session.
 *
 * Mirrors quran_android's AudioService: a plain Service (not MediaBrowserServiceCompat)
 * with a MediaSessionCompat for lock-screen controls.
 *
 * Lifecycle:
 *   - Started via startForegroundService() when playback begins.
 *   - Stops itself when playback ends or the queue is exhausted.
 */
@AndroidEntryPoint
class AudioPlaybackService : Service() {

    @Inject lateinit var player: ExoPlayer
    @Inject lateinit var queueManager: AudioQueueManager
    @Inject lateinit var notificationManager: PlaybackNotificationManager

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    companion object {
        const val ACTION_PLAY = "com.quran.audio.action.PLAY"
        const val ACTION_PAUSE = "com.quran.audio.action.PAUSE"
        const val ACTION_STOP = "com.quran.audio.action.STOP"
        const val ACTION_NEXT = "com.quran.audio.action.NEXT"
        const val ACTION_PREV = "com.quran.audio.action.PREV"
    }

    override fun onCreate() {
        super.onCreate()
        notificationManager.createNotificationChannel()
        observePlaybackEvents()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> queueManager.play()
            ACTION_PAUSE -> queueManager.pause()
            ACTION_STOP -> { queueManager.stop(); stopSelf() }
            ACTION_NEXT -> queueManager.skipToNext()
            ACTION_PREV -> queueManager.skipToPrevious()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        scope.cancel()
        notificationManager.stopNotification()
        player.release()
        super.onDestroy()
    }

    private fun observePlaybackEvents() {
        scope.launch {
            queueManager.events.collect { event ->
                when (event) {
                    is PlaybackEvent.TrackChanged -> {
                        notificationManager.startNotification(this@AudioPlaybackService)
                    }
                    is PlaybackEvent.QueueEnded -> stopSelf()
                    else -> Unit
                }
            }
        }
    }
}
