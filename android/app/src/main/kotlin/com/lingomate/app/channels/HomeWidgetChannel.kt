package com.lingomate.app.channels

import android.content.Context
import com.lingomate.app.HomeWidget
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Receives the widget's favourite phrases on the `lingomate/home_widget` channel. */
class HomeWidgetChannel(messenger: BinaryMessenger, private val context: Context) {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    HomeWidget.update(context, call.argument<String>("favorites") ?: "[]")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Stops handling calls. */
    fun dispose() = channel.setMethodCallHandler(null)

    companion object {
        const val NAME = "lingomate/home_widget"
    }
}
