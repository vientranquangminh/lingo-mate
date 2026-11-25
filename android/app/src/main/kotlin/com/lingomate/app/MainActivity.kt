package com.lingomate.app

import android.view.WindowManager
import com.lingomate.app.channels.BackgroundChannel
import com.lingomate.app.channels.PcmPlayerChannel
import com.lingomate.app.channels.SystemSettingsChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Hosts Flutter and registers the app's platform channels. */
class MainActivity : FlutterActivity() {
    private var pcmPlayer: PcmPlayerChannel? = null
    private var background: BackgroundChannel? = null
    private var systemSettings: SystemSettingsChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        pcmPlayer = PcmPlayerChannel(messenger)
        background = BackgroundChannel(messenger, applicationContext)
        systemSettings = SystemSettingsChannel(messenger, applicationContext) { on ->
            runOnUiThread {
                if (on) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pcmPlayer?.dispose()
        pcmPlayer = null
        background?.dispose()
        background = null
        systemSettings?.dispose()
        systemSettings = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
