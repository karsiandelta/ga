package com.cristian.oyetio

import android.Manifest
import android.app.KeyguardManager
import android.app.PendingIntent
import android.app.SearchManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.BatteryManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.KeyEvent
import org.json.JSONObject
import java.text.Normalizer
import java.util.Locale

/** Acciones sobre el móvil: música, volumen, linterna, alarmas, apps, mapas, mensajes, batería, llamadas. */
object Phone {
    const val SPOTIFY = "com.spotify.music"
    private val main = Handler(Looper.getMainLooper())

    /** Resultado de una acción: texto para la pantalla y si conviene decirlo en voz alta. */
    data class Result(val text: String, val speak: Boolean = false)

    fun run(c: Context, o: JSONObject): Result = try {
        when (o.optString("tipo")) {
            "musica" -> Result(music(c, o))
            "volumen" -> Result(volume(c, o))
            "linterna" -> Result(torch(c, o.optBoolean("encender", true)))
            "alarma" -> Result(alarm(c, o))
            "temporizador" -> Result(timer(c, o))
            "abrir_app" -> Result(openApp(c, o.optString("app")))
            "navegar" -> Result(navigate(c, o.optString("destino")))
            "notificaciones" -> Result(readNotifications(c, o.optString("app")), speak = true)
            "bateria" -> Result(battery(c), speak = true)
            else -> Result("No sé hacer eso todavía.")
        }
    } catch (e: Exception) {
        Result("No he podido hacerlo: ${e.message ?: "error"}")
    }

    // ---------- Música ----------

    private fun sessions(c: Context): List<MediaController> = try {
        c.getSystemService(MediaSessionManager::class.java)
            .getActiveSessions(ComponentName(c, NotifListener::class.java))
    } catch (e: Exception) {
        emptyList()
    }

    private fun spotifySession(c: Context) = sessions(c).firstOrNull { it.packageName == SPOTIFY }

    private fun player(c: Context): MediaController? {
        val s = sessions(c)
        return s.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: s.firstOrNull { it.packageName == SPOTIFY }
            ?: s.firstOrNull()
    }

    private fun key(c: Context, code: Int) {
        val am = c.getSystemService(AudioManager::class.java)
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
    }

    private fun music(c: Context, o: JSONObject): String {
        val p = player(c)
        return when (o.optString("orden", "reproducir")) {
            "pausa" -> { p?.transportControls?.pause() ?: key(c, KeyEvent.KEYCODE_MEDIA_PAUSE); "Música en pausa." }
            "seguir" -> { p?.transportControls?.play() ?: key(c, KeyEvent.KEYCODE_MEDIA_PLAY); "Sigo con la música." }
            "siguiente" -> { p?.transportControls?.skipToNext() ?: key(c, KeyEvent.KEYCODE_MEDIA_NEXT); "Siguiente canción." }
            "anterior" -> { p?.transportControls?.skipToPrevious() ?: key(c, KeyEvent.KEYCODE_MEDIA_PREVIOUS); "Canción anterior." }
            "que_suena" -> nowPlaying(c)
            else -> playSearch(c, o)
        }
    }

    private fun nowPlaying(c: Context): String {
        val m = player(c)?.metadata ?: return "Ahora mismo no suena nada."
        val title = m.getString(android.media.MediaMetadata.METADATA_KEY_TITLE).orEmpty()
        val artist = m.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST).orEmpty()
        return if (title.isBlank()) "No sé qué está sonando." else "Suena $title${if (artist.isNotBlank()) ", de $artist" else ""}."
    }

    private fun playSearch(c: Context, o: JSONObject): String {
        val q = o.optString("busqueda").trim()
        if (q.isBlank()) {
            player(c)?.transportControls?.play() ?: key(c, KeyEvent.KEYCODE_MEDIA_PLAY)
            return "Pongo la música."
        }
        val artist = o.optString("artista").trim()
        val title = o.optString("titulo").trim()
        val extras = Bundle().apply {
            putString(SearchManager.QUERY, q)
            when (o.optString("enfoque")) {
                "artista" -> {
                    putString(MediaStore.EXTRA_MEDIA_FOCUS, MediaStore.Audio.Artists.ENTRY_CONTENT_TYPE)
                    putString(MediaStore.EXTRA_MEDIA_ARTIST, artist.ifBlank { q })
                }
                "cancion" -> {
                    putString(MediaStore.EXTRA_MEDIA_FOCUS, MediaStore.Audio.Media.ENTRY_CONTENT_TYPE)
                    putString(MediaStore.EXTRA_MEDIA_TITLE, title.ifBlank { q })
                    if (artist.isNotBlank()) putString(MediaStore.EXTRA_MEDIA_ARTIST, artist)
                }
                "album" -> {
                    putString(MediaStore.EXTRA_MEDIA_FOCUS, MediaStore.Audio.Albums.ENTRY_CONTENT_TYPE)
                    putString(MediaStore.EXTRA_MEDIA_ALBUM, title.ifBlank { q })
                    if (artist.isNotBlank()) putString(MediaStore.EXTRA_MEDIA_ARTIST, artist)
                }
                "lista" -> {
                    putString(MediaStore.EXTRA_MEDIA_FOCUS, MediaStore.Audio.Playlists.ENTRY_CONTENT_TYPE)
                    putString(MediaStore.EXTRA_MEDIA_PLAYLIST, title.ifBlank { q })
                }
            }
        }

        // 1) Spotify ya abierto: le pedimos que lo ponga (funciona con el móvil bloqueado)
        spotifySession(c)?.let {
            it.transportControls.playFromSearch(q, extras)
            return "Poniendo «$q» en Spotify."
        }
        // 2) Spotify cerrado: lo abrimos con la búsqueda y, por si no arranca solo, se lo repetimos a los 5 s
        val installed = isInstalled(c, SPOTIFY)
        val i = Intent(MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH).putExtras(extras).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (installed) i.setPackage(SPOTIFY)
        try {
            c.startActivity(i)
        } catch (e: Exception) {
            return if (installed) "No he podido abrir Spotify." else "No tienes Spotify instalado."
        }
        val app = c.applicationContext
        for (delay in listOf(4_000L, 8_000L)) {
            main.postDelayed({
                spotifySession(app)?.let { s ->
                    if (s.playbackState?.state != PlaybackState.STATE_PLAYING) s.transportControls.playFromSearch(q, extras)
                }
            }, delay)
        }
        val hint = if (!NotifListener.connected) "\nActiva «Acceso a notificaciones» en Sistema para controlarlo con el móvil bloqueado." else ""
        return "Poniendo «$q» en Spotify.$hint"
    }

    // ---------- Volumen ----------

    private fun volume(c: Context, o: JSONObject): String {
        val am = c.getSystemService(AudioManager::class.java)
        val s = AudioManager.STREAM_MUSIC
        val max = am.getStreamMaxVolume(s)
        when (o.optString("orden")) {
            "subir" -> repeat(2) { am.adjustStreamVolume(s, AudioManager.ADJUST_RAISE, 0) }
            "bajar" -> repeat(2) { am.adjustStreamVolume(s, AudioManager.ADJUST_LOWER, 0) }
            "silencio" -> { am.adjustStreamVolume(s, AudioManager.ADJUST_MUTE, 0); return "Sonido silenciado." }
            "maximo" -> am.setStreamVolume(s, max, 0)
            else -> {
                val pct = o.optInt("nivel", 50).coerceIn(0, 100)
                am.adjustStreamVolume(s, AudioManager.ADJUST_UNMUTE, 0)
                am.setStreamVolume(s, Math.round(pct / 100f * max), 0)
            }
        }
        val now = Math.round(am.getStreamVolume(s) * 100f / max)
        return "Volumen al $now %."
    }

    // ---------- Linterna ----------

    private fun torch(c: Context, on: Boolean): String {
        val cm = c.getSystemService(CameraManager::class.java)
        val id = cm.cameraIdList.firstOrNull {
            cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } ?: return "Tu móvil no tiene linterna."
        cm.setTorchMode(id, on)
        return if (on) "Linterna encendida." else "Linterna apagada."
    }

    // ---------- Alarmas y temporizadores ----------

    private fun alarm(c: Context, o: JSONObject): String {
        val parts = o.optString("hora").split(":")
        val h = parts.getOrNull(0)?.trim()?.toIntOrNull() ?: return "¿A qué hora pongo la alarma?"
        val m = parts.getOrNull(1)?.trim()?.toIntOrNull() ?: 0
        val label = o.optString("texto").ifBlank { "Oye Tío" }
        val i = Intent(AlarmClock.ACTION_SET_ALARM)
            .putExtra(AlarmClock.EXTRA_HOUR, h)
            .putExtra(AlarmClock.EXTRA_MINUTES, m)
            .putExtra(AlarmClock.EXTRA_MESSAGE, label)
            .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            c.startActivity(i)
            "Alarma puesta a las %d:%02d.".format(h, m)
        } catch (e: Exception) {
            "No he podido poner la alarma."
        }
    }

    private fun timer(c: Context, o: JSONObject): String {
        val secs = o.optInt("segundos", 0)
        if (secs <= 0) return "¿De cuánto tiempo pongo el temporizador?"
        val label = o.optString("texto").ifBlank { "Oye Tío" }
        val i = Intent(AlarmClock.ACTION_SET_TIMER)
            .putExtra(AlarmClock.EXTRA_LENGTH, secs)
            .putExtra(AlarmClock.EXTRA_MESSAGE, label)
            .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val txt = durationText(secs)
        return try {
            c.startActivity(i)
            "Temporizador de $txt en marcha."
        } catch (e: Exception) {
            // Sin app de reloj compatible: lo hacemos nosotros como recordatorio
            Scheduler.add(c, Msg((System.currentTimeMillis() % 1_000_000_000L).toInt(), "recordatorio", "", "", "Se acabó el temporizador de $txt.", System.currentTimeMillis() + secs * 1000L))
            "Te aviso dentro de $txt."
        }
    }

    private fun durationText(secs: Int): String {
        val h = secs / 3600
        val m = (secs % 3600) / 60
        val s = secs % 60
        return listOfNotNull(
            if (h > 0) "$h ${if (h == 1) "hora" else "horas"}" else null,
            if (m > 0) "$m ${if (m == 1) "minuto" else "minutos"}" else null,
            if (s > 0) "$s ${if (s == 1) "segundo" else "segundos"}" else null,
        ).joinToString(" y ")
    }

    // ---------- Apps y mapas ----------

    private fun norm(s: String) = Normalizer.normalize(s.lowercase(Locale.ROOT), Normalizer.Form.NFD)
        .replace(Regex("\\p{Mn}+"), "").replace(Regex("[^a-z0-9]"), "")

    private fun openApp(c: Context, name: String): String {
        if (name.isBlank()) return "¿Qué app abro?"
        val pm = c.packageManager
        val apps = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
        val target = norm(name)
        val best = apps.map { it to norm(it.loadLabel(pm).toString()) }
            .filter { (_, label) -> label.isNotEmpty() }
            .maxByOrNull { (_, label) ->
                when {
                    label == target -> 100
                    label.startsWith(target) -> 80
                    label.contains(target) -> 60
                    target.contains(label) && label.length >= 3 -> 40
                    else -> 0
                }
            }
            ?.takeIf { (_, label) -> label == target || label.contains(target) || (target.contains(label) && label.length >= 3) }
            ?: return "No encuentro la app «$name»."
        val info = best.first.activityInfo
        val label = best.first.loadLabel(pm).toString()
        val launch = pm.getLaunchIntentForPackage(info.packageName)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ?: return "No puedo abrir $label."
        return launchOrAsk(c, launch, label, "Abriendo $label.")
    }

    private fun navigate(c: Context, dest: String): String {
        if (dest.isBlank()) return "¿Adónde quieres ir?"
        val maps = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=" + Uri.encode(dest)))
            .setPackage("com.google.android.apps.maps").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val i = if (isInstalled(c, "com.google.android.apps.maps")) maps
        else Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(dest))).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return launchOrAsk(c, i, "Mapas", "Ruta a $dest.")
    }

    /** Las apps no se pueden ver con el móvil bloqueado: si lo está, deja un aviso para abrirla al desbloquear. */
    private fun launchOrAsk(c: Context, i: Intent, label: String, ok: String): String {
        val locked = c.getSystemService(KeyguardManager::class.java).isKeyguardLocked
        if (locked) {
            val pi = PendingIntent.getActivity(c, 20 + (label.hashCode() and 0xFF), i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            Notify.action(c, "Abrir $label", "Toca para abrirlo (te pedirá desbloquear).", pi)
            return "Desbloquea el móvil y toca el aviso para abrir $label."
        }
        return try {
            c.startActivity(i); ok
        } catch (e: Exception) {
            "No he podido abrir $label."
        }
    }

    // ---------- Notificaciones y batería ----------

    private fun readNotifications(c: Context, app: String): String {
        if (!listenerEnabled(c)) return "Necesito «Acceso a notificaciones». Ábreme y actívalo en Sistema."
        val a = app.lowercase(Locale.ROOT)
        val filter: (NotifListener.Item) -> Boolean = when {
            a.contains("whatsapp") -> { it -> it.pkg.startsWith("com.whatsapp") }
            a.contains("telegram") -> { it -> it.pkg.contains("telegram") }
            a.contains("sms") || a.contains("mensaje") -> { it -> it.pkg.contains("messaging") || it.pkg.contains("mms") }
            a.contains("correo") || a.contains("gmail") || a.contains("email") -> { it -> it.pkg.contains("gm") || it.pkg.contains("mail") }
            else -> { _ -> true }
        }
        val items = NotifListener.latest(filter, 8)
        if (items.isEmpty()) return "No tienes mensajes nuevos${if (a.isNotBlank() && a != "todas") " de $app" else ""}."
        val pm = c.packageManager
        val head = if (items.size == 1) "Tienes un mensaje" else "Últimos ${items.size} avisos"
        return head + "\n" + items.joinToString("\n") { i ->
            val src = runCatching { pm.getApplicationLabel(pm.getApplicationInfo(i.pkg, 0)).toString() }.getOrDefault("")
            "${i.title}${if (src.isNotBlank() && a.isBlank()) " ($src)" else ""}: ${i.text.take(160)}"
        }
    }

    private fun battery(c: Context): String {
        val bm = c.getSystemService(BatteryManager::class.java)
        val pct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val charging = bm.isCharging
        return "Tienes un $pct % de batería${if (charging) ", y está cargando" else ""}."
    }

    // ---------- Llamadas ----------

    fun call(c: Context, phone: String): String {
        if (c.checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            return "Necesito permiso para llamar. Ábreme y toca «Micrófono, contactos, SMS, llamadas y avisos»."
        }
        val number = if (phone.trim().startsWith("+")) phone.trim() else "+" + Messenger.intl(phone)
        return try {
            c.getSystemService(TelecomManager::class.java).placeCall(Uri.fromParts("tel", number, null), Bundle())
            "Llamando."
        } catch (e: Exception) {
            "No he podido llamar: ${e.message ?: "error"}"
        }
    }

    // ---------- Utilidades ----------

    fun isInstalled(c: Context, pkg: String) =
        try { c.packageManager.getPackageInfo(pkg, 0); true } catch (e: Exception) { false }

    fun listenerEnabled(c: Context): Boolean {
        val s = Settings.Secure.getString(c.contentResolver, "enabled_notification_listeners") ?: return false
        return s.contains(c.packageName + "/")
    }
}
