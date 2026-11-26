package com.lingomate.app

import android.annotation.SuppressLint
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.flutter.plugin.common.EventChannel

/** Captures audio other apps play (media, games) through MediaProjection and streams it as 16 kHz PCM16 (F-21). */
class MediaCaptureService : Service() {
    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var reader: Thread? = null
    @Volatile private var reading = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        val code = intent?.getIntExtra(EXTRA_CODE, Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(EXTRA_DATA)
        }
        if (code != Activity.RESULT_OK || data == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val manager = getSystemService(MediaProjectionManager::class.java)
        val projection = manager.getMediaProjection(code, data)
        if (projection == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        this.projection = projection
        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                stopSelf()
            }
        }, Handler(Looper.getMainLooper()))
        startReading(projection)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        reading = false
        reader?.join(500)
        record?.release()
        record = null
        projection?.stop()
        projection = null
        super.onDestroy()
    }

    /** Shows the "Translating media" notification and enters the foreground as a media projection service. */
    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_translation),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(
            this,
            10,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            flags,
        )
        val stop = PendingIntent.getService(this, 11, stopIntent(this), flags)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_lingomate)
            .setContentTitle(getString(R.string.notification_translating_media))
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(0, getString(R.string.notification_action_stop), stop)
            .build()
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
        )
    }

    /** Opens playback capture for media, games and unknown usages and forwards 100 ms chunks to Dart. */
    @SuppressLint("MissingPermission")
    private fun startReading(projection: MediaProjection) {
        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
            .build()
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val record = AudioRecord.Builder()
            .setAudioFormat(format)
            .setBufferSizeInBytes(maxOf(minBuffer, CHUNK_BYTES * 4))
            .setAudioPlaybackCaptureConfig(config)
            .build()
        this.record = record
        record.startRecording()
        reading = true
        val main = Handler(Looper.getMainLooper())
        reader = Thread {
            val buffer = ByteArray(CHUNK_BYTES)
            while (reading) {
                val read = record.read(buffer, 0, buffer.size)
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    main.post { sink?.success(chunk) }
                }
            }
            record.stop()
        }.also { it.start() }
    }

    companion object {
        private const val CHANNEL_ID = "translation"
        private const val NOTIFICATION_ID = 1002
        private const val SAMPLE_RATE = 16000
        private const val CHUNK_BYTES = 3200
        private const val ACTION_STOP = "com.lingomate.app.STOP_MEDIA_CAPTURE"
        private const val EXTRA_CODE = "code"
        private const val EXTRA_DATA = "data"

        /** Where captured chunks go; set while Dart listens. */
        var sink: EventChannel.EventSink? = null

        /** Starts capture with the consent result from MediaProjection. */
        fun start(context: Context, code: Int, data: Intent) {
            context.startForegroundService(
                Intent(context, MediaCaptureService::class.java)
                    .putExtra(EXTRA_CODE, code)
                    .putExtra(EXTRA_DATA, data),
            )
        }

        /** The intent that stops capture. */
        fun stopIntent(context: Context): Intent =
            Intent(context, MediaCaptureService::class.java).setAction(ACTION_STOP)

        /** Stops capture. */
        fun stop(context: Context) {
            context.stopService(Intent(context, MediaCaptureService::class.java))
        }
    }
}
