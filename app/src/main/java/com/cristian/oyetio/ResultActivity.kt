package com.cristian.oyetio

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Toast

/** Pantalla que aparece encima del bloqueo (sin desbloquear) con la respuesta o la confirmación. */
class ResultActivity : Activity() {

    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_CONFIRM = "confirm"
    }

    private lateinit var body: LinearLayout
    private lateinit var bar: LinearLayout
    private var orbColor = Neon.CYAN

    private fun px(v: Number) = Neon.px(this, v)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        Neon.styleWindow(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GridBackground(this@ResultActivity)
        }
        val orb = OrbView(this).apply {
            colorProvider = { orbColor }
            levelProvider = {
                if (ListenService.state == ListenService.State.SPEAKING) ListenService.level.coerceAtLeast(0.3f) else 0.12f
            }
        }
        root.addView(orb, LinearLayout.LayoutParams(-1, px(150)))

        body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(22), 0, px(22), px(16))
        }
        val scroll = ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            addView(body)
        }
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))

        bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(px(22), px(10), px(22), px(10))
        }
        root.addView(bar, LinearLayout.LayoutParams(-1, -2))
        Neon.insets(root, root, 0, px(8), 0, px(12))
        setContentView(root)
        render()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) setIntent(intent)
        render()
    }

    private fun render() {
        body.removeAllViews()
        bar.removeAllViews()
        val m = Prefs.pending(this)
        if (intent?.getStringExtra(EXTRA_MODE) == MODE_CONFIRM && m != null) renderConfirm(m) else renderAnswer()
    }

    // ---------- Respuesta ----------

    private fun renderAnswer() {
        orbColor = Neon.CYAN
        body.addView(Neon.text(this, "› TRANSMISIÓN RECIBIDA", 11f, Neon.CYAN, Neon.MONO, 0.25f))
        val q = Prefs.lastQuestion(this)
        if (q.isNotBlank()) {
            body.addView(
                Neon.text(this, "“$q”", 14f, Neon.DIM).apply { setTypeface(typeface, Typeface.ITALIC) },
                Neon.lp(this, top = 6)
            )
        }
        val lines = Prefs.lastAnswer(this).lines().map { it.trim() }.filter { it.isNotEmpty() }
        if (lines.isEmpty()) {
            body.addView(Neon.text(this, "Todavía no hay ninguna respuesta.", 18f), Neon.lp(this, top = 16))
        } else {
            body.addView(
                Neon.glow(Neon.text(this, lines[0], 25f, Neon.TEXT, Neon.COND, 0.02f), Neon.CYAN, 10f),
                Neon.lp(this, top = 14)
            )
            body.addView(divider(Neon.CYAN), LinearLayout.LayoutParams(-1, px(1)).apply {
                topMargin = px(12); bottomMargin = px(6)
            })
            lines.drop(1).forEachIndexed { i, l ->
                val row = lineRow(l)
                body.addView(row, Neon.lp(this, top = 8))
                animateIn(row, i)
            }
        }
        bar.addView(Neon.button(this, "▶ Leer", Neon.VIOLET) {
            startForegroundService(Intent(this, ListenService::class.java).setAction(ListenService.ACTION_SPEAK))
        }, LinearLayout.LayoutParams(0, -2, 1f))
        bar.addView(Neon.button(this, "✕ Cerrar", Neon.MAGENTA) {
            Notify.cancel(this, Notify.ID_POPUP)
            finish()
        }, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = px(10) })
    }

    private fun lineRow(l: String): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = Neon.glass(this@ResultActivity, Neon.CYAN, 12f, 110)
            setPadding(0, px(12), px(14), px(12))
        }
        val accent = View(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Neon.CYAN, Neon.VIOLET)
            ).apply { cornerRadius = Neon.dp(this@ResultActivity, 2f) }
        }
        row.addView(accent, LinearLayout.LayoutParams(px(3), -1).apply { leftMargin = px(10); rightMargin = px(12) })
        val tv = Neon.text(this, highlight(l.removePrefix("• ")), 16f, Neon.TEXT).apply { setLineSpacing(0f, 1.15f) }
        row.addView(tv, LinearLayout.LayoutParams(0, -2, 1f))
        return row
    }

    /** Colorea horas, precios y flechas. */
    private fun highlight(s: String): CharSequence {
        val sp = SpannableString(s)
        fun mark(regex: Regex, color: Int, bold: Boolean) {
            regex.findAll(s).forEach { m ->
                sp.setSpan(ForegroundColorSpan(color), m.range.first, m.range.last + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                if (bold) sp.setSpan(StyleSpan(Typeface.BOLD), m.range.first, m.range.last + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
        mark(Regex("\\b\\d{1,2}[:.]\\d{2}\\b"), Neon.CYAN, true)
        mark(Regex("\\d+(?:[.,]\\d{1,2})?\\s?€"), Neon.GREEN, true)
        mark(Regex("→"), Neon.MAGENTA, true)
        mark(Regex("(?i)precio no visto"), Neon.DIM, false)
        return sp
    }

    // ---------- Confirmación de mensaje ----------

    private fun renderConfirm(m: Msg) {
        orbColor = Neon.AMBER
        val scheduled = m.at > System.currentTimeMillis() + 60_000
        body.addView(Neon.text(this, "› CONFIRMAR ${if (scheduled) "PROGRAMACIÓN" else "ENVÍO"}", 11f, Neon.AMBER, Neon.MONO, 0.25f))
        body.addView(
            Neon.glow(Neon.text(this, "${m.appLabel.uppercase()} → ${m.name}", 26f, Neon.TEXT, Neon.COND), Neon.AMBER, 10f),
            Neon.lp(this, top = 12)
        )
        body.addView(
            Neon.text(this, "+${Messenger.intl(m.phone)}  ·  ${Messenger.describeWhen(m.at).uppercase()}", 12f, Neon.DIM, Neon.MONO, 0.08f),
            Neon.lp(this, top = 6)
        )
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = Neon.glass(this@ResultActivity, Neon.AMBER, 16f, 140)
            setPadding(px(18), px(18), px(18), px(18))
            addView(Neon.text(this@ResultActivity, "“${m.text}”", 21f, Neon.TEXT).apply { setLineSpacing(0f, 1.2f) })
        }
        body.addView(card, Neon.lp(this, top = 18))
        animateIn(card, 0)

        bar.addView(Neon.button(this, if (scheduled) "✓ Programar" else "✓ Enviar", Neon.GREEN, filled = true) {
            send(m, scheduled)
        }, LinearLayout.LayoutParams(0, -2, 1f))
        bar.addView(Neon.button(this, "✕ Cancelar", Neon.MAGENTA) {
            Messenger.cancelPending(this)
            Toast.makeText(this, "Cancelado", Toast.LENGTH_SHORT).show()
            finish()
        }, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = px(10) })
    }

    private fun send(m: Msg, scheduled: Boolean) {
        val km = getSystemService(KeyguardManager::class.java)
        if (m.app != "sms" && !scheduled && km.isKeyguardLocked) {
            // WhatsApp necesita el móvil desbloqueado: pide la huella y lo envía
            km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() { done(Messenger.confirmPending(this@ResultActivity)) }
            })
        } else {
            done(Messenger.confirmPending(this))
        }
    }

    private fun done(result: String) {
        Toast.makeText(this, result, Toast.LENGTH_LONG).show()
        Notify.cancel(this, Notify.ID_POPUP)
        finish()
    }

    // ---------- Utilidades ----------

    private fun divider(color: Int) = View(this).apply {
        background = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(color, Neon.a(color, 0)))
    }

    private fun animateIn(v: View, i: Int) {
        v.alpha = 0f
        v.translationY = Neon.dp(this, 16f)
        v.animate().alpha(1f).translationY(0f).setStartDelay(120L + i * 70L).setDuration(380).start()
    }
}
