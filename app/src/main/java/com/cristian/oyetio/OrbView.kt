package com.cristian.oyetio

import android.animation.ArgbEvaluator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.view.View
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/** Núcleo animado: anillos que giran y barras que bailan con tu voz. */
class OrbView(c: Context) : View(c) {

    var levelProvider: () -> Float = { 0f }
    var colorProvider: () -> Int = { Neon.CYAN }
    var fastProvider: () -> Boolean = { false }

    private var color = Neon.CYAN
    private var lv = 0f
    private var t = 0f
    private var last = 0L
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val arc = RectF()
    private val eval = ArgbEvaluator()
    private val dash = DashPathEffect(floatArrayOf(Neon.dp(c, 3f), Neon.dp(c, 7f)), 0f)

    private fun d(v: Float) = Neon.dp(context, v)

    override fun onDraw(cv: Canvas) {
        val now = SystemClock.uptimeMillis()
        val dt = if (last == 0L) 0.016f else ((now - last) / 1000f).coerceAtMost(0.1f)
        last = now

        color = eval.evaluate((dt * 4f).coerceAtMost(1f), color, colorProvider()) as Int
        val target = levelProvider().coerceIn(0f, 1f)
        lv += (target - lv) * (dt * 10f).coerceAtMost(1f)
        t += dt * (if (fastProvider()) 3.2f else 1f)

        val w = width.toFloat()
        val h = height.toFloat()
        val cx = w / 2f
        val cy = h / 2f
        val r = min(w, h) / 2f * 0.58f

        // Halo
        p.style = Paint.Style.FILL
        p.shader = RadialGradient(
            cx, cy, r * 1.75f,
            intArrayOf(Neon.a(color, (70 + lv * 120).toInt()), Neon.a(color, 22), 0),
            floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP
        )
        cv.drawCircle(cx, cy, r * 1.75f, p)
        p.shader = null

        // Barras de voz
        p.style = Paint.Style.STROKE
        p.strokeCap = Paint.Cap.ROUND
        p.strokeWidth = d(2f)
        val n = 90
        val twoPi = (2 * PI).toFloat()
        for (i in 0 until n) {
            val ang = i * twoPi / n + t * 0.25f
            val wob = 0.5f + 0.5f * sin(t * 3f + i * 0.55f) * cos(t * 1.3f + i * 0.21f)
            val len = r * (0.04f + wob * (0.05f + lv * 0.6f))
            val r0 = r * 1.08f
            val ca = cos(ang)
            val sa = sin(ang)
            p.color = Neon.a(color, (80 + wob * 160).toInt())
            cv.drawLine(cx + ca * r0, cy + sa * r0, cx + ca * (r0 + len), cy + sa * (r0 + len), p)
        }

        // Anillo discontinuo
        p.strokeWidth = d(1f)
        p.color = Neon.a(color, 80)
        p.pathEffect = dash
        cv.save()
        cv.rotate(-t * 8f, cx, cy)
        cv.drawCircle(cx, cy, r * 1.55f, p)
        cv.restore()
        p.pathEffect = null

        // Arcos que giran
        arc(cv, cx, cy, r * 0.98f, t * 90f, 80f, d(3f), 255)
        arc(cv, cx, cy, r * 0.98f, t * 90f + 180f, 40f, d(3f), 200)
        arc(cv, cx, cy, r * 0.86f, -t * 140f, 120f, d(1.5f), 190)
        arc(cv, cx, cy, r * 0.74f, t * 60f + 90f, 50f, d(5f), 140)

        // Núcleo
        p.style = Paint.Style.FILL
        val cr = r * 0.5f * (1f + lv * 0.35f)
        p.shader = RadialGradient(
            cx, cy, cr,
            intArrayOf(Color.WHITE, Neon.a(color, 230), Neon.a(color, 0)),
            floatArrayOf(0f, 0.35f, 1f), Shader.TileMode.CLAMP
        )
        cv.drawCircle(cx, cy, cr, p)
        p.shader = null

        postInvalidateOnAnimation()
    }

    private fun arc(cv: Canvas, cx: Float, cy: Float, rr: Float, start: Float, sweep: Float, sw: Float, alpha: Int) {
        arc.set(cx - rr, cy - rr, cx + rr, cy + rr)
        p.style = Paint.Style.STROKE
        p.strokeWidth = sw
        p.color = Neon.a(color, alpha)
        p.setShadowLayer(d(6f), 0f, 0f, color)
        cv.drawArc(arc, start, sweep, false, p)
        p.clearShadowLayer()
    }
}
