package com.lingomate.app

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.provider.Settings
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat

/** One caption in the bubble: what was said and its translation. */
data class OverlayLine(val original: String, val translation: String)

/** Floating caption bubble drawn over other apps: engine, expand and stop on top, the latest lines below (S-08, AC-04.4/AC-04.5/AC-04.8). */
class CaptionOverlay(private val context: Context) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private var container: LinearLayout? = null
    private var engineView: TextView? = null
    private var expandView: TextView? = null
    private var stopView: TextView? = null
    private var body: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var lines: List<OverlayLine> = emptyList()
    private var engineLabel = ""
    private var engineKind = ""
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
            background = GradientDrawable().apply {
                setColor(color(R.color.blue_kuroi_black_a95))
                cornerRadius = dp(16).toFloat()
            }
            val pad = dp(12)
            setPadding(pad, dp(8), pad, pad)
        }
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val engine = text(12f, R.color.orange_bit_of_sugar)
        val expand = text(18f, R.color.orange_bit_of_sugar).apply {
            text = "⤢"
            setPadding(dp(12), dp(4), dp(12), dp(4))
        }
        val stop = text(18f, R.color.red_forbidden_fruit).apply {
            text = "■"
            contentDescription = context.getString(R.string.overlay_stop)
            setPadding(dp(12), dp(4), dp(4), dp(4))
        }
        header.addView(engine, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(expand)
        header.addView(stop)
        val lineList = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
        layout.addView(header)
        layout.addView(lineList)
        val lp = WindowManager.LayoutParams(
            dp(300),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(KEY_X, dp(16))
            y = prefs.getInt(KEY_Y, dp(120))
        }
        layout.setOnTouchListener(TouchListener(layout, lp))
        windowManager.addView(layout, lp)
        container = layout
        engineView = engine
        expandView = expand
        stopView = stop
        body = lineList
        params = lp
        render()
        return true
    }

    /** Replaces the caption lines and the engine shown in the header. */
    fun update(newLines: List<OverlayLine>, label: String, kind: String) {
        lines = newLines
        engineLabel = label
        engineKind = kind
        render()
    }

    /** Removes the bubble. */
    fun hide() {
        container?.let { windowManager.removeView(it) }
        container = null
        engineView = null
        expandView = null
        stopView = null
        body = null
        params = null
    }

    /** Draws the header and the last 3 lines, or 8 when expanded. */
    private fun render() {
        val lineList = body ?: return
        engineView?.text = SpannableString("● $engineLabel").apply {
            setSpan(ForegroundColorSpan(color(dotColor())), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        expandView?.contentDescription = context.getString(
            if (expanded) R.string.overlay_collapse else R.string.overlay_expand,
        )
        lineList.removeAllViews()
        for (line in visibleLines()) {
            val item = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(0, dp(6), 0, 0)
            }
            if (line.original.isNotEmpty()) {
                item.addView(text(12f, R.color.blue_jacaranda_light).apply { text = line.original })
            }
            item.addView(text(15f, R.color.orange_bit_of_sugar).apply { text = line.translation })
            lineList.addView(item)
        }
    }

    /** The lines on screen: the last 3, or 8 when expanded. */
    private fun visibleLines(): List<OverlayLine> = lines.takeLast(if (expanded) 8 else 3)

    /** The colour of the engine dot. */
    private fun dotColor(): Int = when (engineKind) {
        "live" -> R.color.red_forbidden_fruit
        "offline" -> R.color.blue_ephemeral
        else -> R.color.cyan_exquisite_turquoise
    }

    /** Builds a text view of [sizeSp] in [colorRes]. */
    private fun text(sizeSp: Float, colorRes: Int): TextView = TextView(context).apply {
        setTextColor(color(colorRes))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }

    /** Resolves a colour resource. */
    private fun color(res: Int): Int = ContextCompat.getColor(context, res)

    /** Converts dp to pixels. */
    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

    /** Returns whether ([x], [y]) in [root] coordinates falls inside [view]. */
    private fun hits(root: View, view: View?, x: Float, y: Float): Boolean {
        if (view == null) return false
        val rect = Rect()
        view.getDrawingRect(rect)
        (root as android.view.ViewGroup).offsetDescendantRectToMyCoords(view, rect)
        return rect.contains(x.toInt(), y.toInt())
    }

    /** Drags the bubble; a tap expands, collapses or stops; a long-press saves the line under the finger. */
    private inner class TouchListener(
        private val view: LinearLayout,
        private val lp: WindowManager.LayoutParams,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private val gestures = GestureDetector(
            context,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onSingleTapUp(e: MotionEvent): Boolean {
                    if (hits(view, stopView, e.x, e.y)) {
                        BackgroundEvents.emit("stop")
                    } else {
                        expanded = !expanded
                        render()
                    }
                    return true
                }

                override fun onLongPress(e: MotionEvent) {
                    val lineList = body ?: return
                    val shown = visibleLines()
                    val offset = lines.size - shown.size
                    for (i in 0 until lineList.childCount) {
                        if (hits(view, lineList.getChildAt(i), e.x, e.y)) {
                            val line = shown[i]
                            BackgroundEvents.emit("longPress", line.translation, offset + i)
                            Toast.makeText(context, R.string.overlay_saved, Toast.LENGTH_SHORT).show()
                            return
                        }
                    }
                }
            },
        )

        override fun onTouch(v: View, event: MotionEvent): Boolean {
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
