package com.lingomate.app.channels

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Opens system settings screens on the `lingomate/system_settings` channel. */
class SystemSettingsChannel(messenger: BinaryMessenger, private val context: Context) {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installTtsVoice" -> result.success(open(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)))
                else -> result.notImplemented()
            }
        }
    }

    /** Starts [intent] as a new task; returns false when no app handles it. */
    private fun open(intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        try {
            context.startActivity(Intent("com.android.settings.TTS_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    /** Stops handling calls. */
    fun dispose() = channel.setMethodCallHandler(null)

    companion object {
        const val NAME = "lingomate/system_settings"
    }
}
