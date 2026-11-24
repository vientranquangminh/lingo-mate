package com.lingomate.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.net.Uri
import android.provider.Settings
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import android.content.Intent

/** Floating caption bubble drawn over other apps (Meeting mode, AC-04.4/AC-04.5). */
class CaptionOverlay(private val context: Context) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private var container: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var lines: List<String> = emptyList()
    private var expanded = false

    /** Whether the app may draw over other apps. */
    fun canDraw(): Boolean = Settings.canDrawOverlays(context)

    /** Opens the system screen that grants the overlay permission. */
    fun openSettings() {
        context.startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /** Shows the bubble at its last position; returns false without permission. */
    @SuppressLint("ClickableViewAccessibility")
    fun show(): Boolean {
        if (!canDraw()) return false
        if (container != null) return true
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(context, R.color.black_a54))
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
        }
        val lp = WindowManager.LayoutParams(
            dp(280),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(KEY_X, dp(16))
            y = prefs.getInt(KEY_Y, dp(120))
        }
        layout.setOnTouchListener(DragListener(layout, lp))
        windowManager.addView(layout, lp)
        container = layout
        params = lp
        render()
        return true
    }

    /** Replaces the caption lines. */
    fun update(newLines: List<String>) {
        lines = newLines
        render()
    }

    /** Removes the bubble. */
    fun hide() {
        container?.let { windowManager.removeView(it) }
        container = null
        params = null
    }

    /** Draws the last 3 lines, or 8 when expanded. */
    private fun render() {
        val layout = container ?: return
        layout.removeAllViews()
        val visible = lines.takeLast(if (expanded) 8 else 3)
        for (line in visible) {
            layout.addView(
                TextView(context).apply {
                    text = line
                    setTextColor(ContextCompat.getColor(context, R.color.white))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                },
            )
        }
    }

    /** Converts dp to pixels. */
    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

    /** Drags the bubble, expands it on tap and saves a line on long-press. */
    private inner class DragListener(
        private val view: LinearLayout,
        private val lp: WindowManager.LayoutParams,
    ) : android.view.View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private val gestures = GestureDetector(
            context,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onSingleTapUp(e: MotionEvent): Boolean {
                    expanded = !expanded
                    render()
                    return true
                }

                override fun onLongPress(e: MotionEvent) {
                    lines.lastOrNull()?.let { BackgroundEvents.emit("longPress", it) }
                }
            },
        )

        override fun onTouch(v: android.view.View, event: MotionEvent): Boolean {
            gestures.onTouchEvent(event)
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = lp.x
                    startY = lp.y
                    touchX = event.rawX
                    touchY = event.rawY
                }
                MotionEvent.ACTION_MOVE -> {
                    lp.x = startX + (event.rawX - touchX).toInt()
                    lp.y = startY + (event.rawY - touchY).toInt()
                    windowManager.updateViewLayout(view, lp)
                }
                MotionEvent.ACTION_UP -> {
                    prefs.edit().putInt(KEY_X, lp.x).putInt(KEY_Y, lp.y).apply()
                }
            }
            return true
        }
    }

    companion object {
        private const val PREFS = "caption_overlay"
        private const val KEY_X = "x"
        private const val KEY_Y = "y"
    }
}
