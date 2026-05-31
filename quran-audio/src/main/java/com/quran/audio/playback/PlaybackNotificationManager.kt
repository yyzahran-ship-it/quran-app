package com.quran.audio.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media3.common.Player
import androidx.media3.session.MediaSession
import androidx.media3.ui.PlayerNotificationManager
import javax.inject.Inject

class PlaybackNotificationManager @Inject constructor(
    private val context: Context,
    private val mediaSession: MediaSession,
) {
    private var notificationManager: PlayerNotificationManager? = null

    companion object {
        private const val CHANNEL_ID = "quran_audio_playback"
        const val NOTIFICATION_ID = 1001
    }

    fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Quran Audio Playback",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Controls for Quran audio playback"
                setShowBadge(false)
            }
            context.getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    fun startNotification(service: AudioPlaybackService) {
        notificationManager = PlayerNotificationManager.Builder(
            context,
            NOTIFICATION_ID,
            CHANNEL_ID,
        )
            .setMediaDescriptionAdapter(QuranMediaDescriptionAdapter(context, mediaSession))
            .setNotificationListener(object : PlayerNotificationManager.NotificationListener {
                override fun onNotificationPosted(
                    notificationId: Int,
                    notification: Notification,
                    ongoing: Boolean,
                ) {
                    service.startForeground(notificationId, notification)
                }

                override fun onNotificationCancelled(notificationId: Int, dismissedByUser: Boolean) {
                    service.stopSelf()
                }
            })
            .build()
            .also { mgr ->
                mgr.setMediaSessionToken(mediaSession.sessionCompatToken)
                mgr.setPlayer(mediaSession.player)
                mgr.setUseStopAction(true)
                mgr.setUseFastForwardAction(false)
                mgr.setUseRewindAction(false)
                mgr.setUseNextActionInCompactView(true)
                mgr.setUsePreviousActionInCompactView(true)
            }
    }

    fun stopNotification() {
        notificationManager?.setPlayer(null)
        notificationManager = null
    }

    // ── MediaDescriptionAdapter ────────────────────────────────────────────────

    private class QuranMediaDescriptionAdapter(
        private val context: Context,
        private val mediaSession: MediaSession,
    ) : PlayerNotificationManager.MediaDescriptionAdapter {

        override fun getCurrentContentTitle(player: Player): CharSequence =
            player.currentMediaItem?.mediaMetadata?.title ?: "Quran"

        override fun createCurrentContentIntent(player: Player) = null

        override fun getCurrentContentText(player: Player): CharSequence? =
            player.currentMediaItem?.mediaMetadata?.artist

        override fun getCurrentLargeIcon(
            player: Player,
            callback: PlayerNotificationManager.BitmapCallback,
        ) = null
    }
}
