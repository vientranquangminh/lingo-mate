package com.lingomate.app.channels

import com.lingomate.app.PcmPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Exposes [PcmPlayer] to Dart on the `lingomate/pcm_player` channel. */
class PcmPlayerChannel(messenger: BinaryMessenger) {
    private val player = PcmPlayer()

    init {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    player.start(call.argument<Int>("sampleRate") ?: 24000)
                    result.success(null)
                }
                "write" -> {
                    call.argument<ByteArray>("bytes")?.let(player::write)
                    result.success(null)
                }
                "stop" -> {
                    player.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Releases the player when the engine goes away. */
    fun dispose() = player.stop()

    companion object {
        const val NAME = "lingomate/pcm_player"
    }
}
