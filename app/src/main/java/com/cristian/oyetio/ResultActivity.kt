package com.cristian.oyetio

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Pantalla grande que aparece encima del bloqueo con la respuesta. No desbloquea el móvil. */
class ResultActivity : Activity() {

    private lateinit var question: TextView
    private lateinit var answer: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val dp = resources.displayMetrics.density
        val pad = (20 * dp).toInt()

        question = TextView(this).apply {
            setTextColor(Color.parseColor("#B0B0B0"))
            textSize = 15f
        }
        answer = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 21f
            setLineSpacing(6 * dp, 1f)
            setTextIsSelectable(true)
        }
        val title = TextView(this).apply {
            text = "Oye Tío"
            setTextColor(Color.parseColor("#FF8A5C"))
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            addView(title)
            addView(question, LinearLayout.LayoutParams(-1, -2).apply { topMargin = (6 * dp).toInt() })
            addView(answer, LinearLayout.LayoutParams(-1, -2).apply { topMargin = (18 * dp).toInt() })
        }
        val scroll = ScrollView(this).apply { addView(content) }

        val speak = Button(this).apply {
            text = "Leer en voz alta"
            setOnClickListener {
                startForegroundService(
                    Intent(this@ResultActivity, ListenService::class.java).setAction(ListenService.ACTION_SPEAK)
                )
            }
        }
        val close = Button(this).apply {
            text = "Cerrar"
            setOnClickListener {
                getSystemService(NotificationManager::class.java).cancel(ListenService.ID_POPUP)
                finish()
            }
        }
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(pad, 0, pad, pad * 2)
            addView(speak, LinearLayout.LayoutParams(0, -2, 1f))
            addView(close, LinearLayout.LayoutParams(0, -2, 1f))
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#121212"))
            fitsSystemWindows = true
            addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
            addView(buttons, LinearLayout.LayoutParams(-1, -2))
        }
        setContentView(root)
        fill()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        fill()
    }

    private fun fill() {
        question.text = "“" + Prefs.lastQuestion(this) + "”"
        answer.text = Prefs.lastAnswer(this).ifBlank { "Todavía no hay ninguna respuesta." }
    }
}
