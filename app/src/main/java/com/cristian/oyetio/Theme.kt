package com.cristian.oyetio

import android.app.Activity
import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.os.Build
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/** Estilo neón futurista: colores, tipografías y piezas reutilizables. */
object Neon {
    const val BG = 0xFF04060C.toInt()
    const val BG2 = 0xFF0A1226.toInt()
    const val CYAN = 0xFF00E5FF.toInt()
    const val MAGENTA = 0xFFFF2BD6.toInt()
    const val VIOLET = 0xFF8A5CFF.toInt()
    const val AMBER = 0xFFFFC23D.toInt()
    const val GREEN = 0xFF2BFFA3.toInt()
    const val RED = 0xFFFF4D6D.toInt()
    const val TEXT = 0xFFE6F3FF.toInt()
    const val DIM = 0xFF7F93B5.toInt()

    val MONO: Typeface = Typeface.MONOSPACE
    val COND: Typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)

    fun dp(c: Context, v: Float): Float = v * c.resources.displayMetrics.density
    fun px(c: Context, v: Number): Int = (v.toFloat() * c.resources.displayMetrics.density).toInt()
    fun a(color: Int, alpha: Int): Int = (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)

    fun glass(c: Context, accent: Int = CYAN, radius: Float = 18f, fillAlpha: Int = 150): GradientDrawable =
        GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(a(0xFF13213F.toInt(), fillAlpha), a(0xFF070C1A.toInt(), fillAlpha))
        ).apply {
            cornerRadius = dp(c, radius)
            setStroke(px(c, 1), a(accent, 90))
        }

    fun pillBg(c: Context, color: Int, filled: Boolean): Drawable {
        fun make(pressed: Boolean) = GradientDrawable().apply {
            cornerRadius = dp(c, 30f)
            setColor(a(color, when {
                filled && pressed -> 255
                filled -> 225
                pressed -> 80
                else -> 24
            }))
            setStroke(px(c, 1.5f), a(color, if (filled) 255 else 210))
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_pressed), make(true))
            addState(intArrayOf(), make(false))
        }
    }

    fun text(
        c: Context, s: CharSequence = "", size: Float = 15f, color: Int = TEXT,
        tf: Typeface = Typeface.DEFAULT, spacing: Float = 0f
    ): TextView = TextView(c).apply {
        text = s
        textSize = size
        setTextColor(color)
        typeface = tf
        letterSpacing = spacing
    }

    fun glow(tv: TextView, color: Int, radius: Float = 12f): TextView {
        tv.setShadowLayer(dp(tv.context, radius), 0f, 0f, color)
        return tv
    }

    fun button(c: Context, label: String, color: Int = CYAN, filled: Boolean = false, onClick: () -> Unit): TextView =
        text(c, label.uppercase(), 13f, if (filled) BG else color, COND, 0.16f).apply {
            gravity = Gravity.CENTER
            background = pillBg(c, color, filled)
            setPadding(px(c, 14), px(c, 13), px(c, 14), px(c, 13))
            isClickable = true
            isFocusable = true
            if (!filled) setShadowLayer(dp(c, 8f), 0f, 0f, a(color, 200))
            setOnClickListener { onClick() }
        }

    fun restyleButton(b: TextView, label: String, color: Int, filled: Boolean) {
        b.text = label.uppercase()
        b.background = pillBg(b.context, color, filled)
        b.setTextColor(if (filled) BG else color)
        if (filled) b.setShadowLayer(0f, 0f, 0f, 0) else b.setShadowLayer(dp(b.context, 8f), 0f, 0f, a(color, 200))
    }

    fun field(c: Context, value: String, hint: String, password: Boolean = false, multiline: Boolean = false): EditText =
        EditText(c).apply {
            setText(value)
            this.hint = hint
            setTextColor(TEXT)
            setHintTextColor(a(DIM, 170))
            textSize = 15f
            typeface = MONO
            background = glass(c, VIOLET, 12f, 210)
            setPadding(px(c, 14), px(c, 12), px(c, 14), px(c, 12))
            inputType = when {
                password -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                multiline -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                else -> InputType.TYPE_CLASS_TEXT
            }
        }

    /** Tarjeta de cristal con título. Se añaden vistas directamente a la tarjeta devuelta. */
    fun card(c: Context, title: String, accent: Int = CYAN): LinearLayout {
        val card = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            background = glass(c, accent)
            setPadding(px(c, 18), px(c, 16), px(c, 18), px(c, 18))
        }
        val head = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val dot = View(c).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(accent)
            }
        }
        head.addView(dot, LinearLayout.LayoutParams(px(c, 8), px(c, 8)).apply { rightMargin = px(c, 10) })
        head.addView(glow(text(c, title.uppercase(), 12f, accent, COND, 0.25f), accent, 6f))
        val line = View(c).apply {
            background = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(a(accent, 120), 0))
        }
        head.addView(line, LinearLayout.LayoutParams(0, px(c, 1), 1f).apply { leftMargin = px(c, 12) })
        card.addView(head, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = px(c, 12) })
        return card
    }

    fun lp(c: Context, w: Int = -1, h: Int = -2, top: Int = 0, bottom: Int = 0, weight: Float = 0f) =
        LinearLayout.LayoutParams(w, h, weight).apply {
            topMargin = px(c, top)
            bottomMargin = px(c, bottom)
        }

    @Suppress("DEPRECATION")
    fun styleWindow(act: Activity) {
        act.window.statusBarColor = BG
        act.window.navigationBarColor = BG
    }

    /** Respeta la barra de estado y la de navegación (Android 15 dibuja de borde a borde). */
    @Suppress("DEPRECATION")
    fun insets(root: View, target: View, l: Int, t: Int, r: Int, b: Int) {
        root.setOnApplyWindowInsetsListener { _, ins ->
            val top: Int
            val bottom: Int
            if (Build.VERSION.SDK_INT >= 30) {
                val s = ins.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                top = s.top
                bottom = s.bottom
            } else {
                top = ins.systemWindowInsetTop
                bottom = ins.systemWindowInsetBottom
            }
            target.setPadding(l, t + top, r, b + bottom)
            ins
        }
    }
}

/** Fondo oscuro con rejilla y brillos de neón. */
class GridBackground(private val c: Context) : Drawable() {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)

    override fun draw(canvas: Canvas) {
        val b = bounds
        val w = b.width().toFloat()
        val h = b.height().toFloat()
        if (w <= 0 || h <= 0) return
        p.shader = LinearGradient(0f, 0f, 0f, h, Neon.BG2, Neon.BG, Shader.TileMode.CLAMP)
        canvas.drawRect(b, p)
        p.shader = RadialGradient(w * 0.5f, h * 0.1f, w * 0.95f, Neon.a(Neon.VIOLET, 70), 0, Shader.TileMode.CLAMP)
        canvas.drawRect(b, p)
        p.shader = RadialGradient(w * 0.95f, h * 0.85f, w * 0.8f, Neon.a(Neon.CYAN, 35), 0, Shader.TileMode.CLAMP)
        canvas.drawRect(b, p)
        p.shader = null
        p.color = Neon.a(Neon.CYAN, 14)
        p.strokeWidth = 1f
        val step = Neon.dp(c, 28f)
        var x = 0f
        while (x < w) { canvas.drawLine(x, 0f, x, h, p); x += step }
        var y = 0f
        while (y < h) { canvas.drawLine(0f, y, w, y, p); y += step }
    }

    override fun setAlpha(alpha: Int) {}
    override fun setColorFilter(colorFilter: ColorFilter?) {}
    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.OPAQUE
}
