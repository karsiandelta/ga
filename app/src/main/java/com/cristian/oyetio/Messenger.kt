package com.cristian.oyetio

import android.Manifest
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.telephony.SmsManager
import java.text.Normalizer
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.min

/** Comparte estado entre la app y el servicio de accesibilidad que pulsa "Enviar" en WhatsApp. */
object WaAuto {
    @Volatile var armedUntil = 0L
    @Volatile var current: Msg? = null
    val sent = HashSet<Int>()
    val opened = HashMap<Int, Long>()

    fun arm(m: Msg) {
        current = m
        armedUntil = System.currentTimeMillis() + 25_000
    }
}

/** Busca contactos, envía SMS, abre WhatsApp y gestiona la cola de mensajes. */
object Messenger {
    private val ES = Locale("es", "ES")
    private val main = Handler(Looper.getMainLooper())

    // ---------- Contactos ----------

    private fun norm(s: String): String =
        Normalizer.normalize(s.lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .replace(Regex("[^a-z0-9 ]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()

    /** Devuelve (nombre, teléfono) o null. Lanza SecurityException si no hay permiso de contactos. */
    fun findContact(c: Context, spoken: String): Pair<String, String>? {
        val digits = spoken.filter { it.isDigit() }
        if (digits.length >= 9) return spoken.trim() to digits

        if (c.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            throw SecurityException("sin permiso de contactos")
        }
        val target = norm(spoken).split(" ")
            .filter { it.isNotBlank() && it !in setOf("a", "mi", "el", "la", "al", "de") }
            .joinToString(" ")
        if (target.isBlank()) return null

        var best: Triple<String, String, Int>? = null
        c.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            ),
            null, null, null
        )?.use { cur ->
            while (cur.moveToNext()) {
                val name = cur.getString(0) ?: continue
                val num = cur.getString(1) ?: continue
                var score = score(norm(name), target)
                if (score <= 0) continue
                val d = num.filter { it.isDigit() }.takeLast(9)
                if (d.startsWith("6") || d.startsWith("7")) score += 3 // prefiere móviles
                if (best == null || score > best!!.third) best = Triple(name, num, score)
            }
        }
        return best?.takeIf { it.third >= 40 }?.let { it.first to it.second }
    }

    private fun score(name: String, target: String): Int {
        if (name.isBlank()) return 0
        if (name == target) return 100
        if (name.startsWith("$target ") ) return 85
        val nt = name.split(" ")
        val tt = target.split(" ")
        if (tt.all { t -> nt.any { it == t } }) return 75
        if (name.contains(target)) return 60
        if (target.contains(name) && name.length >= 3) return 50
        if (tt.all { t -> nt.any { lev(it, t) <= (if (t.length > 5) 2 else 1) } }) return 45
        return 0
    }

    private fun lev(a: String, b: String): Int {
        val dp = IntArray(b.length + 1) { it }
        for (i in 1..a.length) {
            var prev = dp[0]
            dp[0] = i
            for (j in 1..b.length) {
                val tmp = dp[j]
                dp[j] = min(min(dp[j] + 1, dp[j - 1] + 1), prev + if (a[i - 1] == b[j - 1]) 0 else 1)
                prev = tmp
            }
        }
        return dp[b.length]
    }

    /** Número en formato internacional sin "+" (España por defecto). */
    fun intl(num: String): String {
        val d = num.filter { it.isDigit() }
        if (num.trim().startsWith("+")) return d
        if (d.startsWith("00")) return d.drop(2)
        if (d.length == 9 && d[0] in "6789") return "34$d"
        return d
    }

    // ---------- Textos ----------

    fun describeWhen(at: Long): String {
        if (at <= System.currentTimeMillis() + 60_000) return "ahora"
        val time = SimpleDateFormat("H:mm", ES).format(Date(at))
        val a = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        val b = Calendar.getInstance().apply { timeInMillis = at; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        val days = ((b.timeInMillis - a.timeInMillis) / 86_400_000L).toInt()
        val hora = if (time.startsWith("1:")) "a la $time" else "a las $time"
        return when (days) {
            0 -> "hoy $hora"
            1 -> "mañana $hora"
            else -> SimpleDateFormat("EEEE d 'de' MMMM", ES).format(Date(at)) + " $hora"
        }
    }

    fun confirmQuestion(m: Msg): String =
        if (m.app == "llamada") "¿Llamo a ${m.name}?"
        else if (m.at > System.currentTimeMillis() + 60_000)
            "¿Programo un ${m.appLabel} para ${m.name}, ${describeWhen(m.at)}, que diga: ${m.text}?"
        else
            "¿Envío un ${m.appLabel} a ${m.name} que diga: ${m.text}?"

    // ---------- Confirmación ----------

    fun confirmPending(c: Context): String {
        val m = Prefs.pending(c) ?: return "No hay ningún mensaje pendiente."
        Prefs.setPending(c, null)
        Notify.cancel(c, Notify.ID_CONFIRM)
        return execute(c, m)
    }

    fun cancelPending(c: Context) {
        Prefs.setPending(c, null)
        Notify.cancel(c, Notify.ID_CONFIRM)
    }

    fun execute(c: Context, m: Msg): String =
        if (m.app == "llamada") Phone.call(c, m.phone)
        else if (m.at > System.currentTimeMillis() + 60_000) {
            Scheduler.add(c, m)
            if (m.app == "recordatorio") "Te lo recordaré ${describeWhen(m.at)}."
            else "Programado: ${m.appLabel} para ${m.name} ${describeWhen(m.at)}."
        } else deliverNow(c, m)

    // ---------- Envío ----------

    fun whatsappPackage(c: Context): String? =
        listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull {
            try { c.packageManager.getPackageInfo(it, 0); true } catch (e: Exception) { false }
        }

    fun deliverNow(c: Context, m: Msg): String {
        if (m.app == "llamada") return Phone.call(c, m.phone)
        if (m.app == "recordatorio") {
            Notify.reminder(c, m.text)
            if (ListenService.running) {
                try {
                    c.startService(
                        Intent(c, ListenService::class.java)
                            .setAction(ListenService.ACTION_SAY)
                            .putExtra(ListenService.EXTRA_TEXT, "Recordatorio: ${m.text}")
                    )
                } catch (_: Exception) {}
            }
            return "Recordatorio: ${m.text}"
        }
        if (m.app == "sms") {
            return try {
                sendSms(c, m)
                Notify.info(c, "SMS enviado a ${m.name}", m.text)
                "SMS enviado a ${m.name}."
            } catch (e: Exception) {
                val r = "No he podido enviar el SMS: ${e.message ?: "error"}"
                Notify.info(c, "SMS no enviado", r)
                r
            }
        }
        if (whatsappPackage(c) == null) return "No tienes WhatsApp instalado."
        val km = c.getSystemService(KeyguardManager::class.java)
        return if (km.isKeyguardLocked) {
            val q = Prefs.getList(c, "unlockQueue")
            q.removeAll { it.id == m.id }
            q.add(m)
            Prefs.putList(c, "unlockQueue", q)
            Notify.tapToSend(c, m, "WhatsApp para ${m.name} listo", "Se enviará al desbloquear el móvil. Toca para enviarlo ya.")
            "Lo enviaré en cuanto desbloquees el móvil."
        } else {
            if (openWhatsApp(c, m)) "Enviando WhatsApp a ${m.name}." else "No he podido abrir WhatsApp."
        }
    }

    private fun sendSms(c: Context, m: Msg) {
        if (c.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            throw SecurityException("falta el permiso de SMS")
        }
        val sm: SmsManager = if (Build.VERSION.SDK_INT >= 31) c.getSystemService(SmsManager::class.java)
        else legacySms()
        val to = if (m.phone.trim().startsWith("+")) m.phone.trim() else "+" + intl(m.phone)
        val parts = sm.divideMessage(m.text)
        sm.sendMultipartTextMessage(to, null, parts, null, null)
    }

    @Suppress("DEPRECATION")
    private fun legacySms(): SmsManager = SmsManager.getDefault()

    /** Abre el chat de WhatsApp con el texto escrito; el servicio de accesibilidad pulsa "Enviar". */
    fun openWhatsApp(c: Context, m: Msg): Boolean {
        if (m.id in WaAuto.sent) return true
        val now = System.currentTimeMillis()
        val prev = WaAuto.opened[m.id]
        if (prev != null && now - prev < 8_000) return true
        val pkg = whatsappPackage(c) ?: return false
        WaAuto.opened[m.id] = now
        WaAuto.arm(m)
        val uri = Uri.parse("https://api.whatsapp.com/send?phone=${intl(m.phone)}&text=${Uri.encode(m.text)}")
        val i = Intent(Intent.ACTION_VIEW, uri).setPackage(pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            c.startActivity(i)
            Notify.tapToSend(c, m, "Enviando WhatsApp a ${m.name}", "Si no se ha enviado, toca aquí.")
            true
        } catch (e: Exception) {
            Notify.tapToSend(c, m, "WhatsApp para ${m.name}", "Toca para enviarlo.")
            false
        }
    }

    fun removeFromQueue(c: Context, id: Int) {
        val q = Prefs.getList(c, "unlockQueue")
        if (q.removeAll { it.id == id }) Prefs.putList(c, "unlockQueue", q)
    }

    /** Envía los WhatsApp que esperaban a que desbloquearas (uno cada 8 s). */
    fun flushQueue(c: Context) {
        val km = c.getSystemService(KeyguardManager::class.java)
        if (km.isKeyguardLocked) return
        val q = Prefs.getList(c, "unlockQueue")
        if (q.isEmpty()) return
        Prefs.putList(c, "unlockQueue", emptyList())
        val app = c.applicationContext
        q.forEachIndexed { i, m -> main.postDelayed({ openWhatsApp(app, m) }, i * 8_000L) }
    }
}
