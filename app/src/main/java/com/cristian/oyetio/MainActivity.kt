package com.cristian.oyetio

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {

    private lateinit var stateText: TextView
    private lateinit var statusText: TextView
    private lateinit var toggle: TextView
    private lateinit var keyField: EditText
    private lateinit var wakeField: EditText
    private lateinit var modelField: EditText
    private lateinit var sens: SeekBar
    private lateinit var sensLabel: TextView
    private lateinit var swStt: Switch
    private lateinit var swSpeak: Switch
    private lateinit var swInstant: Switch
    private lateinit var swGoogle: Switch
    private lateinit var askField: EditText
    private lateinit var lastText: TextView
    private lateinit var msgBox: LinearLayout
    private lateinit var permBox: LinearLayout
    private var msgSig = "#"
    private var permSig = "#"
    private var lastSig = "#"
    private var toggleOn: Boolean? = null
    private val handler = Handler(Looper.getMainLooper())
    private var startAfterPermission: Intent? = null

    private val refresher = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 500)
        }
    }

    private fun px(v: Number) = Neon.px(this, v)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Neon.styleWindow(this)

        val root = ScrollView(this).apply {
            background = GridBackground(this@MainActivity)
            isFillViewport = true
        }
        val col = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(col, FrameLayout.LayoutParams(-1, -2))
        Neon.insets(root, col, px(18), px(14), px(18), px(32))

        // ---- Cabecera ----
        val head = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        head.addView(
            Neon.glow(Neon.text(this, "OYE TÍO", 26f, Neon.TEXT, Neon.COND, 0.3f), Neon.CYAN, 14f),
            LinearLayout.LayoutParams(0, -2, 1f)
        )
        head.addView(Neon.text(this, "v2.1\nNEURAL·LINK", 9f, Neon.DIM, Neon.MONO, 0.2f).apply { gravity = Gravity.END })
        col.addView(head)

        // ---- Núcleo ----
        val orb = OrbView(this).apply {
            levelProvider = { if (ListenService.running) ListenService.level else 0f }
            colorProvider = { stateColor() }
            fastProvider = {
                ListenService.state == ListenService.State.THINKING || ListenService.state == ListenService.State.STARTING
            }
            setOnClickListener { toggleListening() }
        }
        col.addView(orb, LinearLayout.LayoutParams(-1, px(290)))
        stateText = Neon.text(this, "", 13f, Neon.CYAN, Neon.COND, 0.35f).apply { gravity = Gravity.CENTER }
        col.addView(stateText, Neon.lp(this))
        statusText = Neon.text(this, "", 13f, Neon.DIM, Neon.MONO).apply { gravity = Gravity.CENTER }
        col.addView(statusText, Neon.lp(this, top = 6))
        toggle = Neon.button(this, "Activar", Neon.CYAN, filled = true) { toggleListening() }
        col.addView(toggle, Neon.lp(this, top = 18).apply { leftMargin = px(50); rightMargin = px(50) })
        col.addView(
            Neon.text(
                this,
                "Di «oye tío», espera la vibración y habla.\n" +
                    "Mensajes: «oye tío, dile a mamá por WhatsApp que llego a las 8» · " +
                    "«programa un WhatsApp para mañana a las 9 a Juan: feliz cumpleaños» · «manda un SMS a Ana…»\n" +
                    "Más: «pon Bad Bunny en Spotify» · «pausa» · «sube el volumen» · «enciende la linterna» · " +
                    "«alarma a las 7» · «temporizador de 10 minutos» · «recuérdame mañana a las 9 llamar al médico» · " +
                    "«llama a mamá» · «abre Instagram» · «llévame a Alicante» · «lee mis WhatsApp» · «cuánta batería tengo»",
                12f, Neon.DIM
            ).apply {
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.25f)
            },
            Neon.lp(this, top = 14, bottom = 8)
        )

        // ---- Orden escrita ----
        val ask = Neon.card(this, "Orden manual", Neon.VIOLET)
        askField = Neon.field(this, "trenes Albacete Alicante hoy precios y horas", "Escribe lo que dirías…", multiline = true)
        ask.addView(askField, Neon.lp(this))
        ask.addView(Neon.button(this, "Ejecutar ›", Neon.VIOLET) { sendTyped() }, Neon.lp(this, top = 10))
        col.addView(ask, Neon.lp(this, top = 16))

        // ---- Última respuesta ----
        val last = Neon.card(this, "Última transmisión", Neon.CYAN)
        lastText = Neon.text(this, "—", 14f, Neon.TEXT).apply {
            setLineSpacing(0f, 1.25f)
            setTextIsSelectable(true)
        }
        last.addView(lastText)
        last.addView(Neon.button(this, "Ver en grande", Neon.CYAN) {
            startActivity(Intent(this, ResultActivity::class.java))
        }, Neon.lp(this, top = 12))
        col.addView(last, Neon.lp(this, top = 14))

        // ---- Mensajes ----
        val msgs = Neon.card(this, "Mensajes", Neon.AMBER)
        msgBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        msgs.addView(msgBox)
        col.addView(msgs, Neon.lp(this, top = 14))

        // ---- Sistema / permisos ----
        val perms = Neon.card(this, "Sistema", Neon.GREEN)
        permBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        perms.addView(permBox)
        col.addView(perms, Neon.lp(this, top = 14))

        // ---- Ajustes ----
        val set = Neon.card(this, "Ajustes", Neon.MAGENTA)
        set.addView(label("Clave de API de Gemini"))
        keyField = Neon.field(this, Prefs.apiKey(this), "Pega tu clave (AIza…)", password = true)
        set.addView(keyField, Neon.lp(this, top = 6))
        set.addView(Neon.button(this, "Conseguir clave gratis", Neon.MAGENTA) {
            openUrl("https://aistudio.google.com/apikey")
        }, Neon.lp(this, top = 8))

        set.addView(label("Palabra de activación"), Neon.lp(this, top = 16))
        wakeField = Neon.field(this, Prefs.wakeWord(this), "oye tío")
        set.addView(wakeField, Neon.lp(this, top = 6))

        sensLabel = label("")
        set.addView(sensLabel, Neon.lp(this, top = 16))
        sens = SeekBar(this).apply {
            max = 9
            progress = Prefs.sensitivity(this@MainActivity) - 1
            progressTintList = ColorStateList.valueOf(Neon.MAGENTA)
            thumbTintList = ColorStateList.valueOf(Neon.MAGENTA)
            progressBackgroundTintList = ColorStateList.valueOf(Neon.DIM)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(s: SeekBar?, p: Int, fromUser: Boolean) { updateSensLabel() }
                override fun onStartTrackingTouch(s: SeekBar?) {}
                override fun onStopTrackingTouch(s: SeekBar?) {}
            })
        }
        set.addView(sens, Neon.lp(this, top = 4))

        swStt = sw("Reconocimiento de Google tras «oye tío» (más preciso)", Prefs.googleStt(this))
        swSpeak = sw("Leer las respuestas en voz alta", Prefs.speakAloud(this))
        swInstant = sw("Mostrar al instante (sin esperar a sacarlo del bolsillo)", Prefs.showInstantly(this))
        swGoogle = sw("Búsqueda de Google de Gemini (solo con facturación)", Prefs.googleSearch(this))
        listOf(swStt, swSpeak, swInstant, swGoogle).forEach { set.addView(it, Neon.lp(this, top = 6)) }

        set.addView(label("Modelo de IA (déjalo así salvo que dé error)"), Neon.lp(this, top = 14))
        modelField = Neon.field(this, Prefs.model(this), Prefs.DEFAULT_MODEL)
        set.addView(modelField, Neon.lp(this, top = 6))

        set.addView(Neon.button(this, "Guardar", Neon.MAGENTA, filled = true) {
            save()
            Toast.makeText(this, "Guardado", Toast.LENGTH_SHORT).show()
        }, Neon.lp(this, top = 16))
        col.addView(set, Neon.lp(this, top = 14))

        col.addView(
            Neon.text(this, "OYE TÍO · SISTEMA DE VOZ AUTÓNOMO", 10f, Neon.a(Neon.DIM, 140), Neon.MONO, 0.3f)
                .apply { gravity = Gravity.CENTER },
            Neon.lp(this, top = 24)
        )

        setContentView(root)
        updateSensLabel()
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresher)
        Messenger.flushQueue(this)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(refresher)
    }

    // ---------- Piezas ----------

    private fun label(t: String) = Neon.text(this, t.uppercase(), 11f, Neon.DIM, Neon.MONO, 0.15f)

    private fun sw(text: String, checked: Boolean) = Switch(this).apply {
        this.text = text
        isChecked = checked
        setTextColor(Neon.TEXT)
        textSize = 14f
        val states = arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf())
        thumbTintList = ColorStateList(states, intArrayOf(Neon.CYAN, Neon.DIM))
        trackTintList = ColorStateList(states, intArrayOf(Neon.a(Neon.CYAN, 120), Neon.a(Neon.DIM, 80)))
        setPadding(0, px(6), 0, px(6))
    }

    private fun updateSensLabel() {
        val v = sens.progress + 1
        val desc = when {
            v <= 3 -> "cerca"
            v <= 6 -> "normal"
            v <= 8 -> "habitación"
            else -> "máxima"
        }
        sensLabel.text = "SENSIBILIDAD A DISTANCIA · $v/10 · ${desc.uppercase()}"
    }

    private fun stateColor(): Int {
        if (!ListenService.running) return Neon.DIM
        return when (ListenService.state) {
            ListenService.State.OFF -> Neon.DIM
            ListenService.State.STARTING -> Neon.VIOLET
            ListenService.State.IDLE -> Neon.CYAN
            ListenService.State.LISTENING -> Neon.MAGENTA
            ListenService.State.THINKING -> Neon.AMBER
            ListenService.State.SPEAKING -> Neon.VIOLET
            ListenService.State.CONFIRM -> Neon.GREEN
        }
    }

    // ---------- Refresco ----------

    private fun refresh() {
        val running = ListenService.running
        val c = stateColor()
        stateText.text = "◉  " + (if (running) ListenService.state.label else "APAGADO")
        stateText.setTextColor(c)
        stateText.setShadowLayer(Neon.dp(this, 8f), 0f, 0f, c)
        statusText.text = if (running) ListenService.status else "Toca el núcleo para activar"
        if (toggleOn != running) {
            toggleOn = running
            if (running) Neon.restyleButton(toggle, "Desactivar", Neon.MAGENTA, false)
            else Neon.restyleButton(toggle, "Activar", Neon.CYAN, true)
        }

        val q = Prefs.lastQuestion(this)
        val a = Prefs.lastAnswer(this)
        val ls = q + "\u0000" + a
        if (ls != lastSig) {
            lastSig = ls
            lastText.text = if (q.isBlank()) "—" else "“$q”\n\n$a"
        }

        val sig = Prefs.raw(this, "scheduled") + "|" + Prefs.raw(this, "unlockQueue") + "|" + Prefs.raw(this, "pending")
        if (sig != msgSig) {
            msgSig = sig
            buildMessages()
        }

        val perms = permissions()
        val psig = perms.joinToString { "${it.ok}" }
        if (psig != permSig) {
            permSig = psig
            buildPerms(perms)
        }
    }

    // ---------- Mensajes ----------

    private fun buildMessages() {
        msgBox.removeAllViews()
        var count = 0
        Prefs.pending(this)?.let { m ->
            count++
            msgBox.addView(msgRow(m, "PENDIENTE DE CONFIRMAR", Neon.GREEN, listOf(
                Triple<String, Int, () -> Unit>("Enviar", Neon.GREEN, { toast(Messenger.confirmPending(this)) }),
                Triple<String, Int, () -> Unit>("Cancelar", Neon.MAGENTA, { Messenger.cancelPending(this) })
            )), Neon.lp(this, bottom = 10))
        }
        Prefs.getList(this, "unlockQueue").forEach { m ->
            count++
            msgBox.addView(msgRow(m, "ESPERANDO DESBLOQUEO", Neon.CYAN, listOf(
                Triple<String, Int, () -> Unit>("Enviar ya", Neon.CYAN, { Messenger.flushQueue(this) }),
                Triple<String, Int, () -> Unit>("Quitar", Neon.MAGENTA, { Messenger.removeFromQueue(this, m.id) })
            )), Neon.lp(this, bottom = 10))
        }
        Prefs.getList(this, "scheduled").forEach { m ->
            count++
            msgBox.addView(msgRow(m, "PROGRAMADO · " + Messenger.describeWhen(m.at).uppercase(), Neon.AMBER, listOf(
                Triple<String, Int, () -> Unit>("Cancelar", Neon.MAGENTA, { Scheduler.remove(this, m.id) })
            )), Neon.lp(this, bottom = 10))
        }
        if (count == 0) {
            msgBox.addView(Neon.text(this, "Sin mensajes. Pídeselo por voz:\n«oye tío, mándale un WhatsApp a Laura que ya voy»", 13f, Neon.DIM)
                .apply { setLineSpacing(0f, 1.2f) })
        }
    }

    private fun msgRow(m: Msg, tag: String, color: Int, actions: List<Triple<String, Int, () -> Unit>>): View {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = Neon.glass(this@MainActivity, color, 12f, 120)
            setPadding(px(14), px(12), px(14), px(12))
        }
        box.addView(Neon.text(this, tag, 10f, color, Neon.MONO, 0.15f))
        box.addView(Neon.text(this, "${m.appLabel.uppercase()}${if (m.name.isNotBlank()) " → ${m.name}" else ""}", 16f, Neon.TEXT, Neon.COND, 0.04f), Neon.lp(this, top = 4))
        if (m.text.isNotBlank()) box.addView(Neon.text(this, "“${m.text}”", 14f, Neon.DIM), Neon.lp(this, top = 2))
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        actions.forEachIndexed { i, (label, c, fn) ->
            row.addView(Neon.button(this, label, c) { fn() }, LinearLayout.LayoutParams(0, -2, 1f).apply {
                if (i > 0) leftMargin = px(8)
            })
        }
        box.addView(row, Neon.lp(this, top = 10))
        return box
    }

    // ---------- Permisos ----------

    private data class Perm(val name: String, val desc: String, val ok: Boolean?, val fix: () -> Unit)

    private fun basicPerms(): List<String> {
        val l = mutableListOf(
            Manifest.permission.RECORD_AUDIO, Manifest.permission.READ_CONTACTS,
            Manifest.permission.SEND_SMS, Manifest.permission.CALL_PHONE
        )
        if (Build.VERSION.SDK_INT >= 33) l += Manifest.permission.POST_NOTIFICATIONS
        return l
    }

    private fun permissions(): List<Perm> {
        val list = mutableListOf<Perm>()
        list += Perm(
            "Micrófono, contactos, SMS, llamadas y avisos", "Imprescindible",
            basicPerms().all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
        ) { requestBasicPermissions() }
        if (Build.VERSION.SDK_INT >= 34) {
            list += Perm(
                "Pantalla completa", "Enciende la pantalla con la respuesta",
                getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
            ) { tryStart(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))) }
        }
        list += Perm(
            "Batería sin restricciones", "Para que no se duerma con el móvil bloqueado",
            getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
        ) { openBatterySetting() }
        list += Perm(
            "Mostrar sobre otras apps", "Para abrir WhatsApp desde segundo plano",
            Settings.canDrawOverlays(this)
        ) { tryStart(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))) }
        list += Perm(
            "Acceso a notificaciones", "Controlar Spotify bloqueado y leerte tus mensajes",
            Phone.listenerEnabled(this)
        ) {
            toast("Activa «Oye Tío». Si sale «Ajuste restringido»: Ajustes › Apps › Oye Tío › ⋮ › Permitir ajustes restringidos.")
            tryStart(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
        list += Perm(
            "Envío automático de WhatsApp", "Accesibilidad: pulsa «Enviar» por ti",
            accessibilityOn()
        ) { openAccessibility() }
        if (Build.VERSION.SDK_INT >= 31) {
            list += Perm(
                "Alarmas exactas", "Mensajes programados a su hora",
                getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
            ) { tryStart(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))) }
        }
        list += Perm("Xiaomi · Inicio automático", "Actívalo para Oye Tío", null) { openXiaomiAutostart() }
        list += Perm(
            "Xiaomi · Otros permisos",
            "«Mostrar en pantalla de bloqueo» y «Abrir ventanas nuevas en segundo plano»", null
        ) { openXiaomiPerms() }
        return list
    }

    private fun buildPerms(perms: List<Perm>) {
        permBox.removeAllViews()
        perms.forEach { p ->
            val color = when (p.ok) {
                true -> Neon.GREEN
                false -> Neon.RED
                null -> Neon.AMBER
            }
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, px(9), 0, px(9))
                isClickable = true
                setOnClickListener { p.fix() }
            }
            val dot = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(color)
                }
            }
            row.addView(dot, LinearLayout.LayoutParams(px(10), px(10)).apply { rightMargin = px(12) })
            val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            texts.addView(Neon.text(this, p.name, 14f, Neon.TEXT))
            texts.addView(Neon.text(this, p.desc, 11f, Neon.DIM))
            row.addView(texts, LinearLayout.LayoutParams(0, -2, 1f))
            row.addView(Neon.text(this, if (p.ok == true) "OK" else "AJUSTAR ›", 11f, color, Neon.COND, 0.15f))
            permBox.addView(row)
        }
    }

    private fun accessibilityOn(): Boolean {
        val s = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return s.contains("$packageName/")
    }

    private fun openAccessibility() {
        Toast.makeText(
            this,
            "Activa «Oye Tío». Si sale «Ajuste restringido»: Ajustes › Apps › Oye Tío › ⋮ › Permitir ajustes restringidos, y vuelve aquí.",
            Toast.LENGTH_LONG
        ).show()
        tryStart(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun requestBasicPermissions() {
        requestPermissions(basicPerms().toTypedArray(), 1)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val pending = startAfterPermission
        startAfterPermission = null
        if (pending != null && checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            startForegroundService(pending)
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
            toast("Activa «Inicio automático» para Oye Tío")
            return
        }
    }

    private fun openXiaomiPerms() {
        val miui = Intent("miui.intent.action.APP_PERM_EDITOR")
            .setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
            .putExtra("extra_pkgname", packageName)
        if (!tryStart(miui)) tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        toast("Activa «Mostrar en pantalla de bloqueo» y «Abrir ventanas nuevas en segundo plano»")
    }

    // ---------- Acciones ----------

    private fun toggleListening() {
        if (ListenService.running) {
            startService(Intent(this, ListenService::class.java).setAction(ListenService.ACTION_STOP))
        } else {
            save()
            if (Prefs.apiKey(this).isBlank()) {
                toast("Primero pega la clave de API en Ajustes")
                return
            }
            startListen(Intent(this, ListenService::class.java))
        }
    }

    private fun sendTyped() {
        save()
        val q = askField.text.toString().trim()
        if (q.isEmpty()) return
        startListen(Intent(this, ListenService::class.java).setAction(ListenService.ACTION_ASK).putExtra(ListenService.EXTRA_TEXT, q))
        toast("Procesando… bloquea el móvil si quieres probar el aviso")
    }

    private fun save() {
        val pasted = keyField.text.toString()
        Prefs.save(
            this, pasted, modelField.text.toString(), wakeField.text.toString(),
            swSpeak.isChecked, swInstant.isChecked, swGoogle.isChecked, sens.progress + 1, swStt.isChecked
        )
        val key = Prefs.apiKey(this)
        if (key != pasted.trim()) keyField.setText(key)
        if (pasted.isNotBlank() && key.isBlank()) {
            toast("Eso no es una clave. En Google AI Studio pulsa «Create API key» y copia el código que empieza por AIza")
        }
        if (ListenService.running) {
            startService(Intent(this, ListenService::class.java).setAction(ListenService.ACTION_RELOAD))
        }
    }

    private fun startListen(intent: Intent) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            startAfterPermission = intent
            requestBasicPermissions()
            return
        }
        startForegroundService(intent)
    }

    private fun tryStart(i: Intent): Boolean = try {
        startActivity(i); true
    } catch (e: Exception) {
        false
    }

    private fun openUrl(url: String) {
        tryStart(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    private fun toast(t: String) = Toast.makeText(this, t, Toast.LENGTH_LONG).show()
}
