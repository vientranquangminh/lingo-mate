package com.lingomate.app

import com.lingomate.app.channels.PcmPlayerChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Hosts Flutter and registers the app's platform channels. */
class MainActivity : FlutterActivity() {
    private var pcmPlayer: PcmPlayerChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pcmPlayer = PcmPlayerChannel(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pcmPlayer?.dispose()
        pcmPlayer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
