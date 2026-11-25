package com.lingomate.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

/** The home screen widget: Start conversation and up to four favourite quick phrases (F-23). */
class HomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        HomeWidget.render(context, manager, ids)
    }
}

/** Stores the favourites the app sends and draws the widget from them. */
object HomeWidget {
    private const val PREFS = "home_widget"
    private const val KEY_FAVORITES = "favorites"
    private val phraseIds = intArrayOf(R.id.phrase_1, R.id.phrase_2, R.id.phrase_3, R.id.phrase_4)

    /** Saves [favoritesJson] (`[{key, label}]`) and redraws every widget. */
    fun update(context: Context, favoritesJson: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_FAVORITES, favoritesJson).apply()
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
        render(context, manager, ids)
    }

    /** Draws the widgets [ids]. */
    fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
        if (ids.isEmpty()) return
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_FAVORITES, "[]") ?: "[]"
        val favorites = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
        val views = RemoteViews(context.packageName, R.layout.home_widget)
        views.setOnClickPendingIntent(R.id.conversation, open(context, "conversation", 0))
        val count = minOf(favorites.length(), phraseIds.size)
        for (i in phraseIds.indices) {
            if (i < count) {
                val item = favorites.getJSONObject(i)
                views.setViewVisibility(phraseIds[i], View.VISIBLE)
                views.setTextViewText(phraseIds[i], item.optString("label"))
                views.setOnClickPendingIntent(
                    phraseIds[i],
                    open(context, "quick?key=" + Uri.encode(item.optString("key")), i + 1),
                )
            } else {
                views.setViewVisibility(phraseIds[i], View.GONE)
            }
        }
        views.setViewVisibility(R.id.empty, if (count == 0) View.VISIBLE else View.GONE)
        manager.updateAppWidget(ids, views)
    }

    /** A tap that opens `lingomate://open/[path]` in the app. */
    private fun open(context: Context, path: String, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            Intent(Intent.ACTION_VIEW, Uri.parse("lingomate://open/$path"))
                .setClass(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
