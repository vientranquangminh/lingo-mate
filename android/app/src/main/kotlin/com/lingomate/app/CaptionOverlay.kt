package com.lingomate.app

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.SpannableString
import android.text.Spanned
import android.text.TextUtils
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import kotlin.math.abs

/** One caption in the bubble: what was said, its translation and its speaker (0 when not told apart). */
data class OverlayLine(
    val original: String,
    val translation: String,
    val speaker: Int = 0,
    val speakerLabel: String = "",
)

/** Floating caption bubble drawn over other apps: drag by its header, minimise to a pill, expand to scroll back, stop with a confirming second tap (S-08, AC-04.4/AC-04.5/AC-04.8). */
class CaptionOverlay(private val context: Context) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
    private var root: FrameLayout? = null
    private var card: LinearLayout? = null
    private var pill: ImageView? = null
    private var engineView: TextView? = null
    private var expandView: ImageView? = null
    private var stopView: TextView? = null
    private var scroll: ScrollView? = null
    private var body: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var lines: List<OverlayLine> = emptyList()
    private var shownLast: OverlayLine? = null
    private var engineLabel = ""
    private var engineKind = ""
    private var expanded = prefs.getBoolean(KEY_EXPANDED, false)
    private var minimized = prefs.getBoolean(KEY_MINIMIZED, false)
    private var confirmingStop = false
    private val endConfirm = Runnable {
        confirmingStop = false
        renderStop()
    }

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
    fun show(): Boolean {
        if (!canDraw()) return false
        if (root != null) return true
        val frame = FrameLayout(context)
        val cardView = buildCard()
        val pillView = buildPill()
        frame.addView(cardView)
        frame.addView(pillView)
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(KEY_X, dp(16))
            y = prefs.getInt(KEY_Y, dp(120))
        }
        windowManager.addView(frame, lp)
        root = frame
        card = cardView
        pill = pillView
        params = lp
        applyMode()
        render()
        frame.post { settle(animate = false) }
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
        handler.removeCallbacks(endConfirm)
        root?.let { windowManager.removeView(it) }
        root = null
        card = null
        pill = null
        engineView = null
        expandView = null
        stopView = null
        scroll = null
        body = null
        params = null
        shownLast = null
        confirmingStop = false
    }

    /** Builds the full bubble: header with engine, minimise, expand and stop, then the scrollable lines. */
    @SuppressLint("ClickableViewAccessibility")
    private fun buildCard(): LinearLayout {
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(R.color.blue_kuroi_black_a95, dp(16).toFloat())
            setPadding(dp(12), dp(4), dp(4), dp(12))
            layoutParams = FrameLayout.LayoutParams(dp(WIDTH_DP), FrameLayout.LayoutParams.WRAP_CONTENT)
        }
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val engine = text(12f, R.color.orange_bit_of_sugar).apply {
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        val minimize = iconButton(R.drawable.ic_overlay_minimize, R.color.orange_bit_of_sugar, R.string.overlay_minimize) {
            setMinimized(true)
        }
        val expand = iconButton(R.drawable.ic_overlay_expand, R.color.orange_bit_of_sugar, R.string.overlay_expand) {
            expanded = !expanded
            prefs.edit().putBoolean(KEY_EXPANDED, expanded).apply()
            render()
            root?.post { settle(animate = true) }
        }
        val stop = text(13f, R.color.red_forbidden_fruit).apply {
            gravity = Gravity.CENTER
            minWidth = dp(TOUCH_DP)
            minHeight = dp(TOUCH_DP)
            setPadding(dp(8), 0, dp(8), 0)
            setOnClickListener { onStopTapped() }
        }
        header.addView(engine, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(minimize)
        header.addView(expand)
        header.addView(stop)
        header.setOnTouchListener(DragListener(onTap = null))
        val lineList = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 0, dp(8), 0)
        }
        val scrollView = object : ScrollView(context) {
            override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
                val limit = (context.resources.displayMetrics.heightPixels * MAX_HEIGHT_SHARE).toInt()
                super.onMeasure(widthMeasureSpec, MeasureSpec.makeMeasureSpec(limit, MeasureSpec.AT_MOST))
            }
        }.apply {
            isVerticalScrollBarEnabled = true
            addView(lineList)
        }
        layout.addView(header)
        layout.addView(scrollView)
        engineView = engine
        expandView = expand
        stopView = stop
        scroll = scrollView
        body = lineList
        return layout
    }

    /** Builds the minimised pill that restores the bubble on tap and can be dragged. */
    @SuppressLint("ClickableViewAccessibility")
    private fun buildPill(): ImageView = ImageView(context).apply {
        setImageResource(R.drawable.ic_overlay_captions)
        imageTintList = ColorStateList.valueOf(color(R.color.orange_bit_of_sugar))
        background = rounded(R.color.blue_kuroi_black_a95, dp(PILL_DP).toFloat())
        val pad = dp(14)
        setPadding(pad, pad, pad, pad)
        contentDescription = context.getString(R.string.overlay_restore)
        layoutParams = FrameLayout.LayoutParams(dp(PILL_DP), dp(PILL_DP))
        setOnTouchListener(DragListener(onTap = { setMinimized(false) }))
    }

    /** Switches between the pill and the full bubble and remembers the choice. */
    private fun setMinimized(value: Boolean) {
        minimized = value
        prefs.edit().putBoolean(KEY_MINIMIZED, value).apply()
        applyMode()
        root?.post { settle(animate = true) }
    }

    /** Shows either the pill or the full bubble. */
    private fun applyMode() {
        card?.visibility = if (minimized) View.GONE else View.VISIBLE
        pill?.visibility = if (minimized) View.VISIBLE else View.GONE
    }

    /** First tap arms stop for a few seconds; a second tap stops translating. */
    private fun onStopTapped() {
        if (confirmingStop) {
            handler.removeCallbacks(endConfirm)
            confirmingStop = false
            BackgroundEvents.emit("stop")
            return
        }
        confirmingStop = true
        renderStop()
        handler.postDelayed(endConfirm, CONFIRM_MS)
    }

    /** Draws the stop control: a square, or the confirmation prompt while armed. */
    private fun renderStop() {
        val stop = stopView ?: return
        if (confirmingStop) {
            stop.text = context.getString(R.string.overlay_stop_confirm)
            stop.background = rounded(R.color.red_rustic, dp(12).toFloat())
            stop.setCompoundDrawablesRelativeWithIntrinsicBounds(0, 0, 0, 0)
        } else {
            stop.text = ""
            stop.background = null
            val icon = ContextCompat.getDrawable(context, R.drawable.ic_overlay_stop)?.mutate()
            icon?.setTint(color(R.color.red_forbidden_fruit))
            stop.setCompoundDrawablesRelativeWithIntrinsicBounds(icon, null, null, null)
        }
        stop.contentDescription = context.getString(
            if (confirmingStop) R.string.overlay_stop_confirm else R.string.overlay_stop,
        )
    }

    /** Draws the header and the lines: the last 2, or all of them in a scrolling list when expanded. */
    private fun render() {
        val lineList = body ?: return
        engineView?.text = SpannableString("● $engineLabel").apply {
            setSpan(ForegroundColorSpan(color(dotColor())), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        expandView?.apply {
            setImageResource(if (expanded) R.drawable.ic_overlay_collapse else R.drawable.ic_overlay_expand)
            contentDescription = context.getString(
                if (expanded) R.string.overlay_collapse else R.string.overlay_expand,
            )
        }
        renderStop()
        lineList.removeAllViews()
        val shown = visibleLines()
        if (shown.isEmpty()) {
            lineList.addView(text(14f, R.color.blue_jacaranda_light).apply {
                text = context.getString(R.string.overlay_waiting)
                setPadding(0, dp(4), 0, 0)
            })
        }
        val offset = lines.size - shown.size
        val newest = shown.lastOrNull()
        val isNew = newest != null && newest != shownLast
        shown.forEachIndexed { i, line ->
            val item = lineItem(line, offset + i)
            lineList.addView(item)
            if (isNew && i == shown.lastIndex && animatorsEnabled()) {
                item.alpha = 0f
                item.translationY = dp(6).toFloat()
                item.animate().alpha(1f).translationY(0f).setDuration(ENTER_MS)
                    .setInterpolator(DecelerateInterpolator()).start()
            }
        }
        shownLast = newest
        scroll?.post { scroll?.fullScroll(View.FOCUS_DOWN) }
    }

    /** Builds one caption: the original small, the translation large or a waiting mark; long-press saves it. */
    private fun lineItem(line: OverlayLine, index: Int): LinearLayout =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(6), 0, dp(2))
            if (line.speaker > 0) {
                val tint = color(SPEAKER_COLORS[(line.speaker - 1) % SPEAKER_COLORS.size])
                setPadding(dp(10), dp(6), 0, dp(2))
                foreground = SpeakerBar(tint, dp(3).toFloat())
                if (line.speakerLabel.isNotEmpty() && line.speaker != previousSpeaker(index)) {
                    addView(text(11f, R.color.orange_bit_of_sugar).apply {
                        text = line.speakerLabel
                        setTextColor(tint)
                    })
                }
            }
            if (line.original.isNotEmpty()) {
                addView(text(12f, R.color.blue_jacaranda_light).apply { text = line.original })
            }
            val pending = line.translation.isEmpty()
            addView(
                text(16f, if (pending) R.color.blue_mysterious_night else R.color.orange_bit_of_sugar).apply {
                    text = if (pending) "…" else line.translation
                },
            )
            if (!pending) {
                setOnLongClickListener {
                    BackgroundEvents.emit("longPress", line.translation, index)
                    Toast.makeText(context, R.string.overlay_saved, Toast.LENGTH_SHORT).show()
                    true
                }
            }
        }

    /** The speaker of the line before [index] in [lines], or 0 at the start. */
    private fun previousSpeaker(index: Int): Int = lines.getOrNull(index - 1)?.speaker ?: 0

    /** The lines on screen: the last 2, or all when expanded. */
    private fun visibleLines(): List<OverlayLine> = if (expanded) lines else lines.takeLast(COLLAPSED_LINES)

    /** Keeps the bubble on screen and snaps it to the nearest side edge. */
    private fun settle(animate: Boolean) {
        val view = root ?: return
        val lp = params ?: return
        val metrics = context.resources.displayMetrics
        val margin = dp(8)
        val maxX = (metrics.widthPixels - view.width - margin).coerceAtLeast(margin)
        val maxY = (metrics.heightPixels - view.height - margin).coerceAtLeast(margin)
        val targetX = if (lp.x + view.width / 2 < metrics.widthPixels / 2) margin else maxX
        val targetY = lp.y.coerceIn(margin, maxY)
        if (!animate || !animatorsEnabled()) {
            moveTo(targetX, targetY)
            return
        }
        val startX = lp.x
        val startY = lp.y
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = SNAP_MS
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                val t = it.animatedValue as Float
                moveTo(
                    (startX + (targetX - startX) * t).toInt(),
                    (startY + (targetY - startY) * t).toInt(),
                )
            }
            start()
        }
    }

    /** Moves the window to ([x], [y]) and remembers the position. */
    private fun moveTo(x: Int, y: Int) {
        val view = root ?: return
        val lp = params ?: return
        lp.x = x
        lp.y = y
        windowManager.updateViewLayout(view, lp)
        prefs.edit().putInt(KEY_X, x).putInt(KEY_Y, y).apply()
    }

    /** Whether the system lets animations run (they are off when the user removed them). */
    private fun animatorsEnabled(): Boolean = ValueAnimator.areAnimatorsEnabled()

    /** The colour of the engine dot. */
    private fun dotColor(): Int = when (engineKind) {
        "live" -> R.color.red_forbidden_fruit
        "offline" -> R.color.blue_ephemeral
        else -> R.color.cyan_exquisite_turquoise
    }

    /** Builds a 48 dp icon button tinted with [colorRes]. */
    private fun iconButton(icon: Int, colorRes: Int, label: Int, onClick: () -> Unit): ImageView =
        ImageView(context).apply {
            setImageResource(icon)
            imageTintList = ColorStateList.valueOf(color(colorRes))
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
            contentDescription = context.getString(label)
            layoutParams = LinearLayout.LayoutParams(dp(TOUCH_DP), dp(TOUCH_DP))
            setOnClickListener { onClick() }
        }

    /** Builds a text view of [sizeSp] in [colorRes]. */
    private fun text(sizeSp: Float, colorRes: Int): TextView = TextView(context).apply {
        setTextColor(color(colorRes))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }

    /** Returns a rounded background in [colorRes]. */
    private fun rounded(colorRes: Int, radius: Float): GradientDrawable = GradientDrawable().apply {
        setColor(color(colorRes))
        cornerRadius = radius
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

    /** Drags the window once the finger moves past the touch slop; a tap without movement calls [onTap]. */
    private inner class DragListener(private val onTap: (() -> Unit)?) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var dragging = false

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(v: View, event: MotionEvent): Boolean {
            val lp = params ?: return false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = lp.x
                    startY = lp.y
                    touchX = event.rawX
                    touchY = event.rawY
                    dragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (!dragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        dragging = true
                    }
                    if (dragging) {
                        lp.x = startX + dx.toInt()
                        lp.y = startY + dy.toInt()
                        root?.let { windowManager.updateViewLayout(it, lp) }
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) {
                        settle(animate = true)
                    } else {
                        onTap?.invoke()
                        if (onTap != null) v.performClick()
                    }
                }
                MotionEvent.ACTION_CANCEL -> if (dragging) settle(animate = true)
            }
            return true
        }
    }

    companion object {
        private const val PREFS = "caption_overlay"
        private const val KEY_X = "x"
        private const val KEY_Y = "y"
        private const val KEY_EXPANDED = "expanded"
        private const val KEY_MINIMIZED = "minimized"
        private const val WIDTH_DP = 300
        private const val PILL_DP = 52
        private const val TOUCH_DP = 44
        private const val COLLAPSED_LINES = 2
        private const val MAX_HEIGHT_SHARE = 0.45
        private const val CONFIRM_MS = 3000L
        private const val ENTER_MS = 220L
        private const val SNAP_MS = 220L
        private val SPEAKER_COLORS = intArrayOf(
            R.color.cyan_exquisite_turquoise,
            R.color.blue_ephemeral,
            R.color.orange_not_yo_cheese,
            R.color.red_forbidden_fruit,
            R.color.green_shivering,
            R.color.red_georgia_peach,
        )
    }

    /** Draws a coloured bar down the start edge of a line, marking its speaker. */
    private class SpeakerBar(color: Int, private val width: Float) : android.graphics.drawable.Drawable() {
        private val paint = android.graphics.Paint().apply { this.color = color }

        override fun draw(canvas: android.graphics.Canvas) {
            val b = bounds
            canvas.drawRect(b.left.toFloat(), b.top.toFloat() + width, b.left + width, b.bottom.toFloat(), paint)
        }

        override fun setAlpha(alpha: Int) {
            paint.alpha = alpha
        }

        override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
            paint.colorFilter = colorFilter
        }

        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
    }
}
