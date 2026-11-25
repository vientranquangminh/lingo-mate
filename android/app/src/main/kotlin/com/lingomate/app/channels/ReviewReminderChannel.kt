package com.lingomate.app.channels

import android.content.Context
import com.lingomate.app.ReviewReminder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Schedules and cancels the daily review reminder on the `lingomate/review_reminder` channel. */
class ReviewReminderChannel(messenger: BinaryMessenger, private val context: Context) {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val at = call.argument<Number>("atMillis")?.toLong()
                    val title = call.argument<String>("title")
                    if (at == null || title == null) {
                        result.error("bad_args", "atMillis and title are required", null)
                    } else {
                        ReviewReminder.schedule(context, at, title, call.argument<String>("body") ?: "")
                        result.success(null)
                    }
                }
                "cancel" -> {
                    ReviewReminder.cancel(context)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Stops handling calls. */
    fun dispose() = channel.setMethodCallHandler(null)

    companion object {
        const val NAME = "lingomate/review_reminder"
    }
}
