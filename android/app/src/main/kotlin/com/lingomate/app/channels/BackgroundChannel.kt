package com.lingomate.app.channels

import android.content.Context
import com.lingomate.app.BackgroundEvents
import com.lingomate.app.CaptionOverlay
import com.lingomate.app.TranslationForegroundService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Exposes the foreground service and the caption overlay to Dart. */
class BackgroundChannel(messenger: BinaryMessenger, private val context: Context) {
    private val overlay = CaptionOverlay(context)

    init {
        MethodChannel(messenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    TranslationForegroundService.start(context)
                    result.success(null)
                }
                "stopService" -> {
                    TranslationForegroundService.stop(context)
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(overlay.canDraw())
                "openOverlaySettings" -> {
                    overlay.openSettings()
                    result.success(null)
                }
                "showOverlay" -> result.success(overlay.show())
                "updateOverlay" -> {
                    overlay.update(call.argument<List<String>>("lines") ?: emptyList())
                    result.success(null)
                }
                "hideOverlay" -> {
                    overlay.hide()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    BackgroundEvents.sink = { events.success(it) }
                }

                override fun onCancel(arguments: Any?) {
                    BackgroundEvents.sink = null
                }
            },
        )
    }

    /** Removes the overlay and the event sink when the engine goes away. */
    fun dispose() {
        overlay.hide()
        BackgroundEvents.sink = null
    }

    companion object {
        const val METHODS = "lingomate/background"
        const val EVENTS = "lingomate/background/events"
    }
}
