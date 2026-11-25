package com.lingomate.app.channels

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Opens system settings screens and the share sheet, and keeps the screen on, on the `lingomate/system_settings` channel. */
class SystemSettingsChannel(
    messenger: BinaryMessenger,
    private val context: Context,
    private val keepScreenOn: (Boolean) -> Unit,
) {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installTtsVoice" -> result.success(
                    open(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))
                        || open(Intent("com.android.settings.TTS_SETTINGS")),
                )
                "openAppSettings" -> result.success(
                    open(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.fromParts("package", context.packageName, null)),
                    ),
                )
                "shareText" -> {
                    val send = Intent(Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                    call.argument<String>("subject")?.let { send.putExtra(Intent.EXTRA_SUBJECT, it) }
                    result.success(open(Intent.createChooser(send, null)))
                }
                "keepScreenOn" -> {
                    keepScreenOn(call.argument<Boolean>("on") == true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Starts [intent] as a new task; returns false when no app handles it. */
    private fun open(intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    /** Stops handling calls. */
    fun dispose() = channel.setMethodCallHandler(null)

    companion object {
        const val NAME = "lingomate/system_settings"
    }
}
