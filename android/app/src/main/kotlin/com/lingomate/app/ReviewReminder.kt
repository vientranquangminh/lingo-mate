package com.lingomate.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

/** Stores, schedules and shows the daily review reminder. */
object ReviewReminder {
    private const val PREFS = "review_reminder"
    private const val KEY_AT = "at"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val CHANNEL_ID = "review"
    private const val NOTIFICATION_ID = 2001
    private const val DAY_MS = 24L * 60 * 60 * 1000

    /** Saves the reminder and sets an alarm for [atMillis]. */
    fun schedule(context: Context, atMillis: Long, title: String, body: String) {
        prefs(context).edit()
            .putLong(KEY_AT, atMillis)
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .apply()
        setAlarm(context, atMillis)
    }

    /** Forgets the reminder and removes its alarm. */
    fun cancel(context: Context) {
        prefs(context).edit().clear().apply()
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context))
    }

    /** Sets the saved alarm again, moved forward by whole days when its time has passed. */
    fun restore(context: Context) {
        val at = prefs(context).getLong(KEY_AT, 0L)
        if (at == 0L) return
        val now = System.currentTimeMillis()
        val next = if (at > now) at else at + ((now - at) / DAY_MS + 1) * DAY_MS
        prefs(context).edit().putLong(KEY_AT, next).apply()
        setAlarm(context, next)
    }

    /** Shows the notification and schedules the same time tomorrow. */
    fun fire(context: Context) {
        val prefs = prefs(context)
        val title = prefs.getString(KEY_TITLE, null) ?: return
        val body = prefs.getString(KEY_BODY, "") ?: ""
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_channel_review),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            NOTIFICATION_ID,
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_lingomate)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
        restore(context)
    }

    /** Sets an inexact, doze-friendly alarm at [atMillis]. */
    private fun setAlarm(context: Context, atMillis: Long) {
        context.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, alarmIntent(context))
    }

    /** The broadcast the alarm sends. */
    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, ReviewReminderReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** The reminder's own preferences file. */
    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** Shows the review reminder when its alarm goes off and sets it again after a reboot. */
class ReviewReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                ReviewReminder.restore(context)
            else -> ReviewReminder.fire(context)
        }
    }
}
