package com.lingomate.app

import com.lingomate.app.channels.BackgroundChannel
import com.lingomate.app.channels.PcmPlayerChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Hosts Flutter and registers the app's platform channels. */
class MainActivity : FlutterActivity() {
    private var pcmPlayer: PcmPlayerChannel? = null
    private var background: BackgroundChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        pcmPlayer = PcmPlayerChannel(messenger)
        background = BackgroundChannel(messenger, applicationContext)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pcmPlayer?.dispose()
        pcmPlayer = null
        background?.dispose()
        background = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
