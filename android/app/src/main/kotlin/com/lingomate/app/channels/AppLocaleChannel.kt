package com.lingomate.app.channels

import android.app.LocaleManager
import android.content.Context
import android.os.Build
import android.os.LocaleList
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Reads and sets the per-app language of Android 13+ (system Settings → App languages) on the `lingomate/app_locale` channel. */
class AppLocaleChannel(messenger: BinaryMessenger, private val context: Context) {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                result.success(null)
                return@setMethodCallHandler
            }
            val manager = context.getSystemService(LocaleManager::class.java)
            when (call.method) {
                "get" -> {
                    val locales = manager.applicationLocales
                    result.success(if (locales.isEmpty) "" else locales[0].toLanguageTag())
                }
                "set" -> {
                    val tag = call.argument<String>("tag").orEmpty()
                    manager.applicationLocales =
                        if (tag.isEmpty()) LocaleList.getEmptyLocaleList() else LocaleList.forLanguageTags(tag)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Stops handling calls. */
    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val NAME = "lingomate/app_locale"
    }
}
