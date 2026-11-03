package com.cristian.oyetio

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import org.json.JSONArray
import org.json.JSONObject
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.text.Normalizer
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Servicio que escucha siempre (también con la pantalla bloqueada).
 *
 * Oído en dos fases:
 *  1. "Oye tío" se detecta en el móvil, sin internet, con un reconocedor limitado a esas palabras
 *     (mucho más fiable a distancia que reconocer cualquier frase).
 *  2. La orden se escucha con el reconocedor de Google (más preciso). Si lo dices todo seguido,
 *     o Google no está disponible, se usa el reconocedor sin internet.
 */
class ListenService : Service(), TextToSpeech.OnInitListener {

    enum class State(val label: String) {
        OFF("APAGADO"), STARTING("INICIANDO"), IDLE("EN ESPERA"), LISTENING("ESCUCHANDO"),
        THINKING("PROCESANDO"), SPEAKING("HABLANDO"), CONFIRM("CONFIRMACIÓN")
    }

    private enum class Phase { OFF, WAKE, CAPTURE }

    companion object {
        const val ACTION_STOP = "com.cristian.oyetio.STOP"
        const val ACTION_ASK = "com.cristian.oyetio.ASK"
        const val ACTION_SPEAK = "com.cristian.oyetio.SPEAK"
        const val ACTION_RELOAD = "com.cristian.oyetio.RELOAD"
        const val EXTRA_TEXT = "text"

        @Volatile var running = false
        @Volatile var state = State.OFF
        @Volatile var status = "Parado"
        @Volatile var level = 0f

        private val YES = setOf(
            "si", "vale", "envia", "envialo", "mandalo", "manda", "adelante", "ok", "okay", "claro",
            "correcto", "programa", "programalo", "venga", "dale", "perfecto", "exacto", "afirmativo", "enviar"
        )
        private val NO = setOf("no", "cancela", "cancelar", "cancelalo", "para", "espera", "nada", "olvidalo", "borra", "negativo")
        private val WAKE_FIRST = setOf("oye", "olle", "oie", "oy", "hoy", "oiga", "hey", "ey", "oi")
        private val WAKE_SECOND = setOf("tio", "tia", "dio", "rio", "pio", "mio", "tios")
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val loader = Executors.newSingleThreadExecutor()

    private var model: Model? = null
    @Volatile private var freeRec: Recognizer? = null
    @Volatile private var grammarRec: Recognizer? = null
    private var wakeVariants: List<String> = emptyList()
    private var vocab: Set<String>? = null
    private var loading = false

    private var mic: MicLoop? = null
    @Volatile private var phase = Phase.OFF
    @Volatile private var lastPartial = ""
    @Volatile private var resetRecs = false

    private var captureHandler: ((String) -> Unit)? = null
    private var captureTimeout: Runnable? = null
    private var google: SpeechRecognizer? = null

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val ttsDone = HashMap<String, () -> Unit>()
    private var ttsCounter = 0
    private var tone: ToneGenerator? = null

    private var pocket: PocketDetector? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var busy = false
    private var foreground = false

    private val unlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            main.postDelayed({ Messenger.flushQueue(this@ListenService) }, 900)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        Notify.ensure(this)
        tts = TextToSpeech(this, this)
        tone = try { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 70) } catch (e: Exception) { null }
        val f = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(unlockReceiver, f, Context.RECEIVER_EXPORTED)
        else registerReceiver(unlockReceiver, f)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_RELOAD -> reloadEngine()
            ACTION_ASK -> {
                ensureEngine()
                intent.getStringExtra(EXTRA_TEXT)?.takeIf { it.isNotBlank() }?.let { handleCommand(it) }
            }
            ACTION_SPEAK -> {
                ensureEngine()
                speak(Prefs.lastAnswer(this)) { startWake() }
            }
            else -> ensureEngine()
        }
        return START_STICKY
    }

    // =============== Motor de voz ===============

    private fun ensureEngine() {
        if (model != null) {
            if (!busy && phase == Phase.OFF && captureHandler == null && google == null && state != State.SPEAKING) startWake()
            return
        }
        if (loading) return
        loading = true
        setState(State.STARTING, "Preparando el oído…")
        loader.execute {
            try {
                LibVosk.setLogLevel(LogLevel.WARNINGS)
                val dir = ModelInstaller.ensure(this)
                val m = Model(dir.absolutePath)
                val v = loadVocab(dir)
                main.post {
                    model = m
                    vocab = v
                    loading = false
                    buildRecognizers()
                    if (!busy) startWake()
                }
            } catch (e: Exception) {
                main.post {
                    loading = false
                    setState(State.IDLE, "Error al preparar el oído: ${e.message}")
                }
            }
        }
    }

    private fun reloadEngine() {
        if (model == null) { ensureEngine(); return }
        finishCapture()
        stopMic()
        buildRecognizers()
        if (!busy) startWake()
    }

    private fun loadVocab(dir: File): Set<String>? {
        val f = listOf(File(dir, "graph/words.txt"), File(dir, "words.txt")).firstOrNull { it.exists() } ?: return null
        val set = HashSet<String>(150_000)
        f.bufferedReader().useLines { lines ->
            lines.forEach { l ->
                val sp = l.indexOf(' ')
                if (sp > 0) set.add(l.substring(0, sp))
            }
        }
        return set
    }

    /** Solo se llama con el micrófono parado. */
    private fun buildRecognizers() {
        val m = model ?: return
        freeRec?.close()
        grammarRec?.close()
        freeRec = Recognizer(m, 16000f)
        val wake = Prefs.wakeWord(this)
        val phrases = wakeGrammar(wake)
        grammarRec = phrases?.let {
            runCatching { Recognizer(m, 16000f, JSONArray(it + "[unk]").toString()) }.getOrNull()
        }
        wakeVariants = ((phrases ?: emptyList()) + listOf(wake, wake.replace("oye", "hoy"), wake.replace("tío", "tía")))
            .map { normalize(it) }
            .filter { it.isNotBlank() }
            .distinct()
    }

    /** Frases posibles de la palabra de activación que existen en el vocabulario del modelo. */
    private fun wakeGrammar(wake: String): List<String>? {
        val v = vocab ?: return null
        val words = wake.lowercase(Locale.ROOT).split(Regex("\\s+")).filter { it.isNotBlank() }
        if (words.isEmpty() || words.size > 4) return null
        val options = words.map { w ->
            val cands = linkedSetOf(w, stripAccents(w))
            when (stripAccents(w)) {
                "oye" -> cands.add("oiga")
                "tio" -> cands.addAll(listOf("tío", "tía", "tio", "tia"))
            }
            val ok = cands.filter { it in v }
            if (ok.isEmpty()) return null
            ok
        }
        var combos = listOf("")
        for (opts in options) combos = combos.flatMap { pre -> opts.map { (pre + " " + it).trim() } }
        return combos.take(16)
    }

    // =============== Micrófono ===============

    private fun startMic() {
        if (mic != null) return
        mic = MicLoop(Prefs.sensitivity(this), ::onAudio) { err -> main.post { onMicError(err) } }.also { it.start() }
    }

    private fun stopMic() {
        val m = mic
        mic = null
        phase = Phase.OFF
        m?.stop()
        level = 0f
    }

    private fun onMicError(err: String) {
        stopMic()
        setState(State.IDLE, "Micrófono: $err. Reintentando…")
        main.postDelayed({
            if (running && !busy && captureHandler == null && google == null && state != State.SPEAKING) startWake()
        }, 3000)
    }

    /** Se ejecuta en el hilo del micrófono, 10 veces por segundo. */
    private fun onAudio(buf: ShortArray, n: Int) {
        level = mic?.level ?: 0f
        val free = freeRec ?: return
        if (resetRecs) {
            resetRecs = false
            free.reset()
            grammarRec?.reset()
            lastPartial = ""
        }
        when (phase) {
            Phase.WAKE -> {
                val freeFinal = free.acceptWaveForm(buf, n)
                val freeText = if (freeFinal) textOf(free.result, "text") else textOf(free.partialResult, "partial")
                val g = grammarRec
                val hit = if (g != null) {
                    val gt = if (g.acceptWaveForm(buf, n)) textOf(g.result, "text") else textOf(g.partialResult, "partial")
                    isWake(gt)
                } else isWake(freeText)

                if (hit) {
                    g?.reset()
                    phase = Phase.CAPTURE
                    if (freeFinal) {
                        lastPartial = ""
                        val cmd = stripWake(freeText)
                        main.post { onWake(cmd.takeIf { wordCount(it) >= 2 }) }
                    } else {
                        lastPartial = freeText
                        main.post { onWake(null) }
                    }
                } else if (freeFinal) {
                    lastPartial = ""
                }
            }
            Phase.CAPTURE -> {
                if (free.acceptWaveForm(buf, n)) {
                    val t = textOf(free.result, "text")
                    lastPartial = ""
                    if (t.isNotBlank()) main.post { captureHandler?.invoke(t) }
                } else {
                    lastPartial = textOf(free.partialResult, "partial")
                }
            }
            Phase.OFF -> {}
        }
    }

    private fun textOf(json: String, key: String): String =
        runCatching { JSONObject(json).optString(key) }.getOrDefault("").replace("[unk]", "").trim()

    private fun isWake(text: String): Boolean {
        val n = normalize(text)
        if (n.isBlank()) return false
        return wakeVariants.any { v -> Regex("(^|\\s)" + Regex.escape(v) + "(\\s|$)").containsMatchIn(n) }
    }

    // =============== Flujo de escucha ===============

    private fun startWake() {
        if (model == null || busy) return
        finishCapture()
        phase = Phase.WAKE
        resetRecs = true
        setState(State.IDLE, "Di «${Prefs.wakeWord(this)}»")
        startMic()
    }

    private fun onWake(inline: String?) {
        if (busy || phase != Phase.CAPTURE) return
        signal()
        if (inline != null) {
            stopMic()
            handleCommand(inline)
            return
        }
        setState(State.LISTENING, "Te escucho…")
        startCaptureHandler(
            handler = { text ->
                val c = stripWake(text)
                if (wordCount(c) >= 1) {
                    finishCapture()
                    stopMic()
                    handleCommand(c)
                }
            },
            timeoutMs = 12_000,
            onTimeout = {
                val c = stripWake(lastPartial)
                finishCapture()
                if (wordCount(c) >= 2) {
                    stopMic()
                    handleCommand(c)
                } else {
                    startWake()
                    status = "No te he oído. Di «${Prefs.wakeWord(this)}» otra vez"
                }
            }
        )
        // ¿Sigue hablando (lo dijo todo seguido)? → reconocedor sin internet. Si no → Google, más preciso.
        main.postDelayed({
            if (captureHandler == null || state != State.LISTENING || google != null) return@postDelayed
            val talking = SystemClock.elapsedRealtime() - (mic?.lastVoiceAt ?: 0L) < 300
            if (!talking && googleAvailable()) {
                stopMic()
                startGoogle()
            }
        }, 650)
    }

    private fun startCaptureHandler(handler: (String) -> Unit, timeoutMs: Long, onTimeout: () -> Unit) {
        captureHandler = handler
        captureTimeout?.let { main.removeCallbacks(it) }
        val r = Runnable { if (captureHandler != null) onTimeout() }
        captureTimeout = r
        main.postDelayed(r, timeoutMs)
    }

    private fun finishCapture() {
        captureHandler = null
        captureTimeout?.let { main.removeCallbacks(it) }
        captureTimeout = null
        stopGoogle()
    }

    /** Quita "oye tío" (y fallos típicos del dictado) del principio de la frase. */
    private fun stripWake(text: String): String {
        val toks = text.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        val n = toks.map { normalize(it).trim(',', '.', '!', '?', '¡', '¿') }
        val ww = normalize(Prefs.wakeWord(this)).split(" ").filter { it.isNotBlank() }
        val cut = when {
            ww.isNotEmpty() && n.size >= ww.size && n.subList(0, ww.size) == ww -> ww.size
            n.size >= 2 && n[0] in WAKE_FIRST && n[1] in WAKE_SECOND -> 2
            n.isNotEmpty() && n[0] in WAKE_SECOND -> 1
            else -> 0
        }
        return toks.drop(cut).joinToString(" ").trim(' ', ',', '.')
    }

    private fun wordCount(s: String) = s.split(Regex("\\s+")).count { it.isNotBlank() }

    private fun normalize(s: String): String =
        stripAccents(s.lowercase(Locale.ROOT)).replace(Regex("\\s+"), " ").trim()

    private fun stripAccents(s: String): String =
        Normalizer.normalize(s, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")

    // =============== Reconocedor de Google ===============

    private fun googleAvailable() = Prefs.googleStt(this) && SpeechRecognizer.isRecognitionAvailable(this)

    private fun startGoogle() {
        stopGoogle()
        val sr = try { SpeechRecognizer.createSpeechRecognizer(this) } catch (e: Exception) { null }
        if (sr == null) { fallbackToVosk(); return }
        google = sr
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) { level = ((rmsdB + 2f) / 12f).coerceIn(0f, 1f) }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) { onGoogleError(error) }
            override fun onResults(results: Bundle?) {
                val best = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                stopGoogle()
                if (best.isBlank()) onGoogleError(SpeechRecognizer.ERROR_NO_MATCH)
                else captureHandler?.invoke(best)
            }
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-ES")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1800L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
        }
        try {
            sr.startListening(i)
        } catch (e: Exception) {
            fallbackToVosk()
        }
    }

    private fun stopGoogle() {
        val g = google ?: return
        google = null
        try { g.cancel() } catch (_: Exception) {}
        try { g.destroy() } catch (_: Exception) {}
    }

    private fun onGoogleError(code: Int) {
        stopGoogle()
        if (captureHandler == null) return
        if (code == SpeechRecognizer.ERROR_NO_MATCH || code == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
            captureTimeout?.run()
        } else {
            fallbackToVosk()
        }
    }

    private fun fallbackToVosk() {
        stopGoogle()
        phase = Phase.CAPTURE
        resetRecs = true
        startMic()
    }

    // =============== Órdenes ===============

    private fun handleCommand(question: String) {
        if (busy) return
        finishCapture()
        stopMic()
        busy = true
        pocket?.stop()
        setState(State.THINKING, "Procesando: $question")
        Notify.result(this, "Procesando…", question, popup = false, ongoing = true)

        val key = Prefs.apiKey(this)
        val model = Prefs.model(this)
        val googleSearch = Prefs.googleSearch(this)
        worker.execute {
            var message: GeminiClient.Route.Message? = null
            val text: String = try {
                when (val r = GeminiClient.route(key, model, question)) {
                    is GeminiClient.Route.Answer -> r.text
                    is GeminiClient.Route.Search -> GeminiClient.answer(key, model, question, r.queries, googleSearch)
                    is GeminiClient.Route.Message -> { message = r; "" }
                }
            } catch (e: Exception) {
                "No he podido hacerlo.\n${e.message ?: "Sin conexión"}"
            }
            val msg = message
            main.post {
                busy = false
                if (msg != null) prepareMessage(question, msg) else deliver(question, text)
            }
        }
    }

    private fun deliver(question: String, answer: String) {
        Prefs.saveLast(this, question, answer)
        Notify.result(this, answer.lineSequence().firstOrNull() ?: "Respuesta", answer, popup = false, ongoing = false)
        vibrate(longArrayOf(0, 120, 100, 120))

        if (Prefs.showInstantly(this)) {
            showOnScreen()
        } else {
            acquireWakeLock()
            pocket = PocketDetector(this) {
                showOnScreen()
                releaseWakeLock()
            }.also { it.start() }
        }
        if (Prefs.speakAloud(this)) speak(answer) { startWake() } else startWake()
    }

    private fun showOnScreen() {
        val a = Prefs.lastAnswer(this)
        Notify.result(this, a.lineSequence().firstOrNull() ?: "Respuesta", a, popup = true, ongoing = false)
    }

    // =============== Mensajes ===============

    private fun prepareMessage(question: String, r: GeminiClient.Route.Message) {
        val contact = try {
            Messenger.findContact(this, r.contact)
        } catch (e: SecurityException) {
            deliver(question, "Necesito permiso de contactos.\nAbre Oye Tío y toca «Micrófono, contactos, SMS y avisos».")
            return
        }
        if (contact == null) {
            deliver(question, "No encuentro a «${r.contact}» en tus contactos.\nPrueba con el nombre tal como lo tienes guardado.")
            return
        }
        val m = Msg(
            id = (System.currentTimeMillis() % 1_000_000_000L).toInt(),
            app = r.app, name = contact.first, phone = contact.second, text = r.text, at = r.at
        )
        val ask = Messenger.confirmQuestion(m)
        Prefs.setPending(this, m)
        Prefs.saveLast(this, question, "Pendiente de confirmar\n$ask")
        Notify.confirm(this, m, popup = Prefs.showInstantly(this))
        vibrate(longArrayOf(0, 80, 80, 80))
        setState(State.CONFIRM, "¿Lo envío? Di «sí» o «no»")
        speak(ask) { listenConfirm() }
    }

    private fun listenConfirm() {
        if (Prefs.pending(this) == null) { startWake(); return }
        setState(State.CONFIRM, "¿Lo envío? Di «sí» o «no»")
        signal()
        startCaptureHandler(
            handler = { t ->
                finishCapture()
                stopMic()
                answerConfirm(t)
            },
            timeoutMs = 8_000,
            onTimeout = {
                finishCapture()
                stopMic()
                startWake()
                status = "Confirma el mensaje en la notificación"
            }
        )
        if (googleAvailable()) {
            stopMic()
            startGoogle()
        } else {
            fallbackToVosk()
        }
    }

    private fun answerConfirm(t: String) {
        val words = normalize(t).split(" ").map { it.trim(',', '.', '!', '?') }.filter { it.isNotBlank() }
        val first = words.firstOrNull() ?: ""
        val yes = first in YES || (words.any { it in YES } && words.none { it in NO })
        val no = first in NO || (words.any { it in NO } && words.none { it in YES })
        when {
            Prefs.pending(this) == null -> startWake()
            yes -> {
                val r = Messenger.confirmPending(this)
                Prefs.saveLast(this, Prefs.lastQuestion(this), r)
                speak(r) { startWake() }
            }
            no -> {
                Messenger.cancelPending(this)
                Prefs.saveLast(this, Prefs.lastQuestion(this), "Mensaje cancelado.")
                speak("Cancelado.") { startWake() }
            }
            else -> speak("No te he entendido. Confírmalo en la notificación.") { startWake() }
        }
    }

    // =============== Voz ===============

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        tts?.setLanguage(Locale("es", "ES"))
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) { main.post { utteranceId?.let { ttsDone.remove(it)?.invoke() } } }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) { main.post { utteranceId?.let { ttsDone.remove(it)?.invoke() } } }
        })
        ttsReady = true
    }

    private fun speak(text: String, then: () -> Unit) {
        val t = tts
        if (!ttsReady || t == null || text.isBlank()) { then(); return }
        stopMic() // que no se escuche a sí mismo
        setState(State.SPEAKING, status)
        ttsDone.clear()
        val id = "u${ttsCounter++}"
        ttsDone[id] = then
        val clean = text.replace("→", " a ").replace("·", ", ").replace("€", " euros")
            .replace("“", "").replace("”", "").replace("•", "")
        t.speak(clean, TextToSpeech.QUEUE_FLUSH, null, id)
        // Seguridad: si el motor de voz no avisa al terminar, seguimos igualmente
        main.postDelayed({ ttsDone.remove(id)?.invoke() }, 5_000L + clean.length * 90L)
    }

    private fun signal() {
        vibrate(longArrayOf(0, 60))
        try { tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 120) } catch (_: Exception) {}
    }

    // =============== Utilidades ===============

    private fun goForeground() {
        if (foreground) return
        val n = Notify.service(this, status)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(Notify.ID_SERVICE, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(Notify.ID_SERVICE, n)
        }
        foreground = true
    }

    private fun setState(s: State, text: String) {
        state = s
        status = text
        if (foreground) {
            getSystemService(android.app.NotificationManager::class.java).notify(Notify.ID_SERVICE, Notify.service(this, text))
        }
    }

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
        state = State.OFF
        status = "Parado"
        level = 0f
        try { unregisterReceiver(unlockReceiver) } catch (_: Exception) {}
        finishCapture()
        stopMic()
        pocket?.stop()
        releaseWakeLock()
        freeRec?.close()
        grammarRec?.close()
        model?.close()
        tts?.shutdown()
        tone?.release()
        worker.shutdownNow()
        loader.shutdownNow()
        super.onDestroy()
    }
}
