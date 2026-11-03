package com.cristian.oyetio

import android.content.Context
import android.content.SharedPreferences

/** Ajustes guardados en el teléfono. */
object Prefs {
    const val DEFAULT_MODEL = "gemini-3.8-flash"
    const val DEFAULT_WAKE = "oye tío"

    private fun sp(c: Context): SharedPreferences =
        c.getSharedPreferences("oyetio", Context.MODE_PRIVATE)

    fun apiKey(c: Context) = extractKey(sp(c).getString("apiKey", "")!!)
    fun model(c: Context) = sp(c).getString("model", DEFAULT_MODEL)!!.trim()
        .let { if (it.isEmpty() || it == "gemini-flash-latest") DEFAULT_MODEL else it }
    fun googleSearch(c: Context) = sp(c).getBoolean("google", false)
    fun wakeWord(c: Context) = sp(c).getString("wake", DEFAULT_WAKE)!!.trim().ifEmpty { DEFAULT_WAKE }
    fun speakAloud(c: Context) = sp(c).getBoolean("speak", false)
    fun showInstantly(c: Context) = sp(c).getBoolean("instant", false)
    fun lastQuestion(c: Context) = sp(c).getString("lastQ", "")!!
    fun lastAnswer(c: Context) = sp(c).getString("lastA", "")!!

    /** Saca la clave "AIza…" aunque se pegue con texto de más. Si no hay ninguna, devuelve "". */
    fun extractKey(raw: String): String =
        Regex("AIza[0-9A-Za-z_\\-]{30,}").find(raw)?.value
            ?: raw.trim().takeIf { it.isNotEmpty() && it.none { ch -> ch.isWhitespace() } && it.length in 20..80 }
            ?: ""

    fun save(c: Context, apiKey: String, model: String, wake: String, speak: Boolean, instant: Boolean, google: Boolean) {
        sp(c).edit()
            .putString("apiKey", extractKey(apiKey))
            .putString("model", model.trim())
            .putString("wake", wake.trim())
            .putBoolean("speak", speak)
            .putBoolean("instant", instant)
            .putBoolean("google", google)
            .apply()
    }

    fun saveLast(c: Context, q: String, a: String) {
        sp(c).edit().putString("lastQ", q).putString("lastA", a).apply()
    }
}
