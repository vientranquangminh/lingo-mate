package com.lingomate.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/** Microphone foreground service that keeps capture alive with the screen off or the app in the background. */
class TranslationForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        MeetingTileService.refresh(this)
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                BackgroundEvents.emit("stop")
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                startInForeground()
                running = true
                MeetingTileService.refresh(this)
            }
        }
        return START_NOT_STICKY
    }

    /** Shows the persistent notification and enters the foreground as a microphone service. */
    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_translation),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), type)
    }

    /** Builds the "Translating meeting" notification with Stop and Open actions. */
    private fun buildNotification(): Notification {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            flags,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, TranslationForegroundService::class.java).setAction(ACTION_STOP),
            flags,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_lingomate)
            .setContentTitle(getString(R.string.notification_translating_meeting))
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(0, getString(R.string.notification_action_stop), stop)
            .addAction(0, getString(R.string.notification_action_open), open)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "translation"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_STOP = "com.lingomate.app.STOP_TRANSLATION"

        /** Whether the service is running, for the Quick Settings tile. */
        @Volatile
        var running = false
            private set

        /** The intent that stops captioning as the notification's Stop does. */
        fun stopIntent(context: Context): Intent =
            Intent(context, TranslationForegroundService::class.java).setAction(ACTION_STOP)

        /** Starts the service; call while the app is in the foreground. */
        fun start(context: Context) {
            context.startForegroundService(Intent(context, TranslationForegroundService::class.java))
        }

        /** Stops the service and removes its notification. */
        fun stop(context: Context) {
            context.stopService(Intent(context, TranslationForegroundService::class.java))
        }
    }
}
