package com.cristian.oyetio

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** Un mensaje de WhatsApp o SMS (al momento o programado). */
data class Msg(
    val id: Int,
    val app: String,   // "whatsapp" o "sms"
    val name: String,
    val phone: String,
    val text: String,
    val at: Long,      // 0 = ahora
) {
    val appLabel: String get() = if (app == "sms") "SMS" else "WhatsApp"

    fun toJson(): JSONObject = JSONObject()
        .put("id", id).put("app", app).put("name", name)
        .put("phone", phone).put("text", text).put("at", at)

    companion object {
        fun fromJson(o: JSONObject) = Msg(
            o.getInt("id"), o.optString("app", "whatsapp"), o.optString("name"),
            o.optString("phone"), o.optString("text"), o.optLong("at", 0L)
        )
    }
}

/** Ajustes y datos guardados en el teléfono. */
object Prefs {
    const val DEFAULT_MODEL = "gemini-3.8-flash"
    const val DEFAULT_WAKE = "oye tío"

    private fun sp(c: Context): SharedPreferences =
        c.getSharedPreferences("oyetio", Context.MODE_PRIVATE)

    fun apiKey(c: Context) = extractKey(sp(c).getString("apiKey", "")!!)
    fun model(c: Context) = sp(c).getString("model", DEFAULT_MODEL)!!.trim()
        .let { if (it.isEmpty() || it == "gemini-flash-latest") DEFAULT_MODEL else it }
    fun googleSearch(c: Context) = sp(c).getBoolean("google", false)
    fun googleStt(c: Context) = sp(c).getBoolean("gstt", true)
    fun sensitivity(c: Context) = sp(c).getInt("sens", 6).coerceIn(1, 10)
    fun wakeWord(c: Context) = sp(c).getString("wake", DEFAULT_WAKE)!!.trim().ifEmpty { DEFAULT_WAKE }
    fun speakAloud(c: Context) = sp(c).getBoolean("speak", false)
    fun showInstantly(c: Context) = sp(c).getBoolean("instant", false)
    fun lastQuestion(c: Context) = sp(c).getString("lastQ", "")!!
    fun lastAnswer(c: Context) = sp(c).getString("lastA", "")!!
    fun raw(c: Context, key: String) = sp(c).getString(key, "") ?: ""

    /** Saca la clave "AIza…" aunque se pegue con texto de más. Si no hay ninguna, devuelve "". */
    fun extractKey(raw: String): String =
        Regex("AIza[0-9A-Za-z_\\-]{30,}").find(raw)?.value
            ?: raw.trim().takeIf { it.isNotEmpty() && it.none { ch -> ch.isWhitespace() } && it.length in 20..80 }
            ?: ""

    fun save(
        c: Context, apiKey: String, model: String, wake: String, speak: Boolean,
        instant: Boolean, google: Boolean, sens: Int, gstt: Boolean
    ) {
        sp(c).edit()
            .putString("apiKey", extractKey(apiKey))
            .putString("model", model.trim())
            .putString("wake", wake.trim())
            .putBoolean("speak", speak)
            .putBoolean("instant", instant)
            .putBoolean("google", google)
            .putInt("sens", sens.coerceIn(1, 10))
            .putBoolean("gstt", gstt)
            .apply()
    }

    fun saveLast(c: Context, q: String, a: String) {
        sp(c).edit().putString("lastQ", q).putString("lastA", a).apply()
    }

    // ---------- Mensajes ----------

    @Synchronized
    fun getList(c: Context, key: String): MutableList<Msg> {
        val arr = runCatching { JSONArray(raw(c, key).ifBlank { "[]" }) }.getOrDefault(JSONArray())
        return (0 until arr.length()).mapNotNull { i ->
            runCatching { Msg.fromJson(arr.getJSONObject(i)) }.getOrNull()
        }.toMutableList()
    }

    @Synchronized
    fun putList(c: Context, key: String, list: List<Msg>) {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        sp(c).edit().putString(key, arr.toString()).commit()
    }

    fun pending(c: Context): Msg? =
        raw(c, "pending").takeIf { it.isNotBlank() }?.let { runCatching { Msg.fromJson(JSONObject(it)) }.getOrNull() }

    fun setPending(c: Context, m: Msg?) {
        sp(c).edit().putString("pending", m?.toJson()?.toString() ?: "").commit()
    }
}
