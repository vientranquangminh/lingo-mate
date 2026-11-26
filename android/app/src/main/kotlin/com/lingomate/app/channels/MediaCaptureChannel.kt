package com.lingomate.app.channels

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import com.lingomate.app.MediaCaptureService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Asks for MediaProjection consent and streams captured playback audio on `lingomate/media_capture` (+ `/audio`). */
class MediaCaptureChannel(messenger: BinaryMessenger, private val activity: Activity) {
    private val methods = MethodChannel(messenger, NAME)
    private val audio = EventChannel(messenger, "$NAME/audio")
    private var pending: MethodChannel.Result? = null

    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestConsent" -> {
                    pending?.success(false)
                    pending = result
                    val manager = activity.getSystemService(MediaProjectionManager::class.java)
                    activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST)
                }
                "stop" -> {
                    MediaCaptureService.stop(activity.applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        audio.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                MediaCaptureService.sink = events
            }

            override fun onCancel(arguments: Any?) {
                MediaCaptureService.sink = null
            }
        })
    }

    /** Handles the consent screen's answer; returns true when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val granted = resultCode == Activity.RESULT_OK && data != null
        if (granted) {
            MediaCaptureService.start(activity.applicationContext, resultCode, data!!)
        }
        pending?.success(granted)
        pending = null
        return true
    }

    /** Stops handling calls. */
    fun dispose() {
        methods.setMethodCallHandler(null)
        audio.setStreamHandler(null)
    }

    companion object {
        const val NAME = "lingomate/media_capture"
        private const val REQUEST = 4201
    }
}
