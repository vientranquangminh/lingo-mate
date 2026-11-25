package com.lingomate.app

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings tile that starts Meeting captions in the app, or stops them while they run (F-23). */
class MeetingTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let {
            it.state = if (TranslationForegroundService.running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            it.label = getString(R.string.tile_meeting)
            it.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        if (TranslationForegroundService.running) {
            startService(TranslationForegroundService.stopIntent(this))
            return
        }
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("lingomate://open/meeting?start=1"))
            .setClass(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    companion object {
        /** Asks the system to refresh the tile's state. */
        fun refresh(context: Context) {
            requestListeningState(context, ComponentName(context, MeetingTileService::class.java))
        }
    }
}
