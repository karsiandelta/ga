package com.cristian.oyetio

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.text.InputType
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {

    private lateinit var status: TextView
    private lateinit var keyField: EditText
    private lateinit var modelField: EditText
    private lateinit var wakeField: EditText
    private lateinit var speakBox: CheckBox
    private lateinit var instantBox: CheckBox
    private lateinit var testField: EditText
    private lateinit var lastText: TextView
    private lateinit var checks: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var startAfterPermission: Intent? = null

    private val refresher = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val dp = resources.displayMetrics.density
        val pad = (16 * dp).toInt()

        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad * 2)
        }
        fun header(t: String) = TextView(this).apply {
            text = t
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#FF8A5C"))
            setPadding(0, (22 * dp).toInt(), 0, (6 * dp).toInt())
        }
        fun label(t: String) = TextView(this).apply {
            text = t
            textSize = 13f
            setTextColor(Color.parseColor("#B0B0B0"))
            setPadding(0, (10 * dp).toInt(), 0, 0)
        }
        fun button(t: String, onClick: () -> Unit) = Button(this).apply {
            text = t
            isAllCaps = false
            setOnClickListener { onClick() }
        }

        col.addView(TextView(this).apply {
            text = "Oye Tío"
            textSize = 30f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
        })
        status = TextView(this).apply { textSize = 15f; setTextColor(Color.WHITE); setPadding(0, (4 * dp).toInt(), 0, 0) }
        col.addView(status)

        col.addView(button("▶  Guardar y empezar a escuchar") { saveAndStart() })
        col.addView(button("■  Parar") {
            startService(Intent(this, ListenService::class.java).setAction(ListenService.ACTION_STOP))
        })

        // --- Ajustes ---
        col.addView(header("Ajustes"))
        col.addView(label("Clave de API de Google Gemini (gratis)"))
        keyField = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            hint = "Pega aquí tu clave"
            setText(Prefs.apiKey(this@MainActivity))
        }
        col.addView(keyField)
        col.addView(button("Conseguir clave gratis (Google AI Studio)") {
            openUrl("https://aistudio.google.com/apikey")
        })
        col.addView(label("Palabra para activarla"))
        wakeField = EditText(this).apply { setText(Prefs.wakeWord(this@MainActivity)) }
        col.addView(wakeField)
        col.addView(label("Modelo de IA (déjalo así salvo que dé error)"))
        modelField = EditText(this).apply { setText(Prefs.model(this@MainActivity)) }
        col.addView(modelField)
        speakBox = CheckBox(this).apply {
            text = "Leer la respuesta en voz alta"
            isChecked = Prefs.speakAloud(this@MainActivity)
        }
        instantBox = CheckBox(this).apply {
            text = "Mostrar al instante (no esperar a sacarlo del bolsillo)"
            isChecked = Prefs.showInstantly(this@MainActivity)
        }
        col.addView(speakBox)
        col.addView(instantBox)

        // --- Permisos ---
        col.addView(header("Para que funcione con el móvil bloqueado"))
        checks = TextView(this).apply { textSize = 14f; setTextColor(Color.WHITE) }
        col.addView(checks)
        col.addView(button("1. Micrófono y notificaciones") { requestBasicPermissions() })
        col.addView(button("2. Mostrar en pantalla completa") { openFullScreenSetting() })
        col.addView(button("3. Batería sin restricciones") { openBatterySetting() })
        col.addView(button("4. Inicio automático (Xiaomi)") { openXiaomiAutostart() })
        col.addView(button("5. Ajustes de la app (notificaciones en bloqueo)") {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        })

        // --- Prueba ---
        col.addView(header("Probar sin hablar"))
        testField = EditText(this).apply { setText("trenes Albacete Alicante hoy precios y horas") }
        col.addView(testField)
        col.addView(button("Enviar pregunta") {
            save()
            val q = testField.text.toString().trim()
            if (q.isNotEmpty()) startListen(Intent(this, ListenService::class.java)
                .setAction(ListenService.ACTION_ASK).putExtra(ListenService.EXTRA_TEXT, q))
            Toast.makeText(this, "Buscando… bloquea el móvil si quieres probar el aviso", Toast.LENGTH_LONG).show()
        })

        col.addView(header("Última respuesta"))
        lastText = TextView(this).apply { textSize = 15f; setTextColor(Color.WHITE); setTextIsSelectable(true) }
        col.addView(lastText)
        col.addView(button("Ver en grande") { startActivity(Intent(this, ResultActivity::class.java)) })

        val scroll = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#121212"))
            fitsSystemWindows = true
            addView(col)
        }
        setContentView(scroll)
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresher)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(refresher)
    }

    private fun refresh() {
        status.text = if (ListenService.running) ListenService.status else "Parado"
        val q = Prefs.lastQuestion(this)
        lastText.text = if (q.isBlank()) "—" else "“$q”\n\n${Prefs.lastAnswer(this)}"

        fun mark(ok: Boolean, t: String) = (if (ok) "✅ " else "❌ ") + t
        val mic = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val notif = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val full = Build.VERSION.SDK_INT < 34 ||
            getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        val battery = getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
        checks.text = listOf(
            mark(mic, "Micrófono"),
            mark(notif, "Notificaciones"),
            mark(full, "Pantalla completa"),
            mark(battery, "Batería sin restricciones"),
            "ℹ️ Inicio automático: compruébalo a mano (botón 4)",
            if (Prefs.apiKey(this).isBlank()) "❌ Falta la clave de API" else "✅ Clave de API",
        ).joinToString("\n")
    }

    private fun save() {
        val pasted = keyField.text.toString()
        Prefs.save(
            this, pasted, modelField.text.toString(), wakeField.text.toString(),
            speakBox.isChecked, instantBox.isChecked
        )
        val key = Prefs.apiKey(this)
        if (key != pasted.trim()) keyField.setText(key) // deja solo la clave limpia
        if (pasted.isNotBlank() && key.isBlank()) {
            Toast.makeText(
                this,
                "Eso no es una clave. En Google AI Studio pulsa \"Create API key\" y copia el código que empieza por AIza",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    private fun saveAndStart() {
        save()
        if (Prefs.apiKey(this).isBlank()) {
            Toast.makeText(this, "Primero pega la clave de API", Toast.LENGTH_LONG).show()
            return
        }
        startListen(Intent(this, ListenService::class.java))
    }

    private fun startListen(intent: Intent) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            startAfterPermission = intent
            requestBasicPermissions()
            return
        }
        startForegroundService(intent)
    }

    private fun requestBasicPermissions() {
        val perms = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= 33) perms += Manifest.permission.POST_NOTIFICATIONS
        requestPermissions(perms.toTypedArray(), 1)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val pending = startAfterPermission
        startAfterPermission = null
        if (pending != null &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        ) startForegroundService(pending)
    }

    private fun openFullScreenSetting() {
        if (Build.VERSION.SDK_INT >= 34) {
            tryStart(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
        } else {
            Toast.makeText(this, "En tu versión de Android ya está permitido", Toast.LENGTH_SHORT).show()
        }
    }

    @Suppress("BatteryLife")
    private fun openBatterySetting() {
        tryStart(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
    }

    private fun openXiaomiAutostart() {
        val candidates = listOf(
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
        )
        for (i in candidates) if (tryStart(i)) {
            Toast.makeText(this, "Activa \"Inicio automático\" para Oye Tío", Toast.LENGTH_LONG).show()
            return
        }
    }

    private fun tryStart(i: Intent): Boolean = try {
        startActivity(i); true
    } catch (e: Exception) {
        false
    }

    private fun openUrl(url: String) {
        tryStart(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }
}
