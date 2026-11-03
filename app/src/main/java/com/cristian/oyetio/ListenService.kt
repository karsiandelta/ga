package com.cristian.oyetio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import org.json.JSONObject
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.text.Normalizer
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Servicio que escucha siempre (también con la pantalla bloqueada),
 * detecta "oye tío", pregunta a la IA y deja la respuesta en la pantalla de bloqueo.
 */
class ListenService : Service(), RecognitionListener, TextToSpeech.OnInitListener {

    companion object {
        const val ACTION_STOP = "com.cristian.oyetio.STOP"
        const val ACTION_ASK = "com.cristian.oyetio.ASK"
        const val ACTION_SPEAK = "com.cristian.oyetio.SPEAK"
        const val EXTRA_TEXT = "text"

        const val CH_SERVICE = "escucha"
        const val CH_RESULT = "respuestas"
        const val CH_POPUP = "respuestas_pantalla"
        const val ID_SERVICE = 1
        const val ID_RESULT = 2
        const val ID_POPUP = 3

        @Volatile var running = false
        @Volatile var status = "Parado"
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var model: Model? = null
    private var speech: SpeechService? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pocket: PocketDetector? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var waitingCommandUntil = 0L
    private var busy = false
    private var foreground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        createChannels()
        tts = TextToSpeech(this, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_ASK -> {
                goForeground()
                if (speech == null) startRecognizer()
                intent.getStringExtra(EXTRA_TEXT)?.let { if (it.isNotBlank()) handleCommand(it) }
            }
            ACTION_SPEAK -> {
                goForeground()
                if (speech == null) startRecognizer()
                speak(Prefs.lastAnswer(this))
            }
            else -> {
                goForeground()
                if (speech == null) startRecognizer()
            }
        }
        return START_STICKY
    }

    // ---------- Escucha ----------

    private fun startRecognizer() {
        setStatus("Preparando el oído…")
        worker.execute {
            try {
                LibVosk.setLogLevel(LogLevel.WARNINGS)
                val dir = ModelInstaller.ensure(this)
                val m = Model(dir.absolutePath)
                val rec = Recognizer(m, 16000f)
                val s = SpeechService(rec, 16000f)
                main.post {
                    model = m
                    speech = s
                    s.startListening(this)
                    setStatus("Escuchando… di \"${Prefs.wakeWord(this)}\"")
                }
            } catch (e: Exception) {
                main.post { setStatus("Error al arrancar el oído: ${e.message}") }
            }
        }
    }

    override fun onPartialResult(hypothesis: String?) {}

    override fun onResult(hypothesis: String?) {
        val text = runCatching { JSONObject(hypothesis ?: "").optString("text") }.getOrDefault("")
        onUtterance(text)
    }

    override fun onFinalResult(hypothesis: String?) {}

    override fun onError(e: Exception?) {
        setStatus("Error del micrófono: ${e?.message}. Reintentando…")
        main.postDelayed({
            speech?.shutdown(); speech = null
            model?.close(); model = null
            if (running) startRecognizer()
        }, 3000)
    }

    override fun onTimeout() {
        speech?.startListening(this)
    }

    private fun onUtterance(raw: String) {
        val text = normalize(raw)
        if (text.isBlank() || busy) return

        val end = findWakeWordEnd(text)
        val now = System.currentTimeMillis()
        if (end >= 0) {
            val rest = text.substring(end).trim(' ', ',', '.')
            if (rest.split(" ").size >= 2) {
                handleCommand(rest)
            } else {
                // Solo ha dicho "oye tío": espera la orden 10 segundos
                waitingCommandUntil = now + 10_000
                vibrate(longArrayOf(0, 60))
                setStatus("Te escucho…")
            }
        } else if (now < waitingCommandUntil) {
            waitingCommandUntil = 0
            handleCommand(text)
        }
    }

    /** Devuelve dónde acaba la palabra de activación en el texto, o -1. Tolera fallos típicos del dictado. */
    private fun findWakeWordEnd(text: String): Int {
        val wake = normalize(Prefs.wakeWord(this))
        val variants = linkedSetOf(
            wake,
            wake.replace("oye", "olle"),
            wake.replace("oye", "hoy"),
            wake.replace("oye", "oy"),
            wake.replace("oye", "oie"),
            wake.replace("tio", "tia"),
            wake.replace("tio", "dio"),
        )
        for (v in variants) {
            val m = Regex("(^|\\s)" + Regex.escape(v) + "(\\s|$)").find(text)
            if (m != null) return m.range.last + 1
        }
        return -1
    }

    private fun normalize(s: String): String =
        Normalizer.normalize(s.lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .replace(Regex("\\s+"), " ")
            .trim()

    // ---------- Pregunta a la IA ----------

    private fun handleCommand(question: String) {
        if (busy) return
        busy = true
        pocket?.stop()
        vibrate(longArrayOf(0, 60, 80, 60))
        speech?.setPause(true)
        setStatus("Buscando: $question")
        notifyResult("Buscando…", question, popup = false, ongoing = true)

        val key = Prefs.apiKey(this)
        val model = Prefs.model(this)
        worker.execute {
            val answer = try {
                GeminiClient.ask(key, model, question)
            } catch (e: Exception) {
                "No he podido buscarlo.\n${e.message ?: "Sin conexión"}"
            }
            main.post { deliver(question, answer) }
        }
    }

    private fun deliver(question: String, answer: String) {
        busy = false
        Prefs.saveLast(this, question, answer)
        notifyResult(answer.lineSequence().firstOrNull() ?: "Respuesta", answer, popup = false, ongoing = false)
        vibrate(longArrayOf(0, 120, 100, 120))
        setStatus("Escuchando… di \"${Prefs.wakeWord(this)}\"")

        if (Prefs.speakAloud(this)) speak(answer) else speech?.setPause(false)

        if (Prefs.showInstantly(this)) {
            showOnScreen()
        } else {
            acquireWakeLock()
            pocket = PocketDetector(this) {
                showOnScreen()
                releaseWakeLock()
            }.also { it.start() }
        }
    }

    /** Enciende la pantalla y muestra la respuesta encima del bloqueo, sin desbloquear. */
    private fun showOnScreen() {
        val a = Prefs.lastAnswer(this)
        notifyResult(a.lineSequence().firstOrNull() ?: "Respuesta", a, popup = true, ongoing = false)
    }

    // ---------- Voz ----------

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.setLanguage(Locale("es", "ES"))
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) { main.post { if (!busy) speech?.setPause(false) } }
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) { main.post { if (!busy) speech?.setPause(false) } }
            })
            ttsReady = true
        }
    }

    private fun speak(text: String) {
        if (!ttsReady || text.isBlank()) { speech?.setPause(false); return }
        speech?.setPause(true) // que no se escuche a sí mismo
        val clean = text.replace("→", " a ").replace("·", ",").replace("€", " euros")
        tts?.speak(clean, TextToSpeech.QUEUE_FLUSH, null, "respuesta")
    }

    // ---------- Notificaciones ----------

    private fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CH_SERVICE, "Escuchando", NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_RESULT, "Respuestas", NotificationManager.IMPORTANCE_DEFAULT).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_POPUP, "Respuesta en pantalla", NotificationManager.IMPORTANCE_HIGH).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
        )
    }

    private fun goForeground() {
        if (foreground) return
        val n = serviceNotification(status)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(ID_SERVICE, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(ID_SERVICE, n)
        }
        foreground = true
    }

    private fun serviceNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, ListenService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CH_SERVICE)
            .setSmallIcon(R.drawable.ic_mic)
            .setContentTitle("Oye Tío")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(open)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "Parar", stop).build())
            .build()
    }

    private fun setStatus(text: String) {
        status = text
        if (foreground) {
            getSystemService(NotificationManager::class.java).notify(ID_SERVICE, serviceNotification(text))
        }
    }

    private fun notifyResult(title: String, body: String, popup: Boolean, ongoing: Boolean) {
        val nm = getSystemService(NotificationManager::class.java)
        val show = PendingIntent.getActivity(
            this, 2,
            Intent(this, ResultActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = Notification.Builder(this, if (popup) CH_POPUP else CH_RESULT)
            .setSmallIcon(R.drawable.ic_mic)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(show)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .setCategory(Notification.CATEGORY_MESSAGE)

        if (popup) {
            b.setFullScreenIntent(show, true)
            nm.cancel(ID_RESULT)
            nm.notify(ID_POPUP, b.build())
        } else {
            nm.cancel(ID_POPUP)
            nm.notify(ID_RESULT, b.build())
        }
    }

    // ---------- Utilidades ----------

    @Suppress("DEPRECATION")
    private fun vibrate(pattern: LongArray) {
        val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        v.vibrate(VibrationEffect.createWaveform(pattern, -1))
    }

    private fun acquireWakeLock() {
        releaseWakeLock()
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "OyeTio:bolsillo").apply {
            acquire(15 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onDestroy() {
        running = false
        status = "Parado"
        pocket?.stop()
        releaseWakeLock()
        speech?.stop()
        speech?.shutdown()
        model?.close()
        tts?.shutdown()
        worker.shutdownNow()
        super.onDestroy()
    }
}
