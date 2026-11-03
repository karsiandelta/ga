package com.cristian.oyetio

import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Pregunta a Gemini con búsqueda de Google activada y devuelve texto listo para leer. */
object GeminiClient {

    fun ask(apiKey: String, model: String, question: String): String {
        if (apiKey.isBlank()) throw IOException("Falta la clave de API. Ábre la app y pégala.")

        val now = SimpleDateFormat("EEEE d 'de' MMMM 'de' yyyy, HH:mm", Locale("es", "ES")).format(Date())
        val system = """
            Eres "Oye Tío", un asistente de voz. Ahora es $now y el usuario está en España.
            La petición viene de un dictado por voz: puede tener palabras mal reconocidas y sin tildes; interpreta lo que quiso decir.
            Busca siempre en Google la información actual antes de responder.
            El usuario leerá la respuesta de un vistazo en la pantalla de bloqueo del móvil, así que:
            - Escribe en español, sin markdown, sin asteriscos, sin almohadillas, sin enlaces.
            - Primera línea: un título corto de lo que has buscado.
            - Después, una línea por opción, ordenadas por hora o por relevancia.
            - Para trenes, autobuses o vuelos: "HH:MM → HH:MM · duración · compañía · desde X €". Si no encuentras el precio, pon "precio no visto".
            - Máximo 12 líneas. Al final, si hace falta, una línea de aviso muy corta (por ejemplo, que los precios cambian).
            - Nunca inventes horarios ni precios; si no los encuentras, dilo.
        """.trimIndent()

        val body = JSONObject().apply {
            put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", system))))
            put("contents", JSONArray().put(
                JSONObject().put("role", "user")
                    .put("parts", JSONArray().put(JSONObject().put("text", question)))
            ))
            put("tools", JSONArray().put(JSONObject().put("google_search", JSONObject())))
        }

        val safeModel = URLEncoder.encode(model, "UTF-8")
        val url = URL("https://generativelanguage.googleapis.com/v1beta/models/$safeModel:generateContent")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20_000
            readTimeout = 90_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("x-goog-api-key", apiKey)
        }
        try {
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""

            if (code !in 200..299) {
                val msg = runCatching { JSONObject(raw).getJSONObject("error").getString("message") }
                    .getOrDefault(raw.take(300))
                val hint = when (code) {
                    400, 403 -> "\nRevisa que la clave de API esté bien copiada."
                    404 -> "\nEl modelo \"$model\" no existe. Cambia el modelo en la app."
                    429 -> "\nHas llegado al límite gratuito de hoy. Prueba más tarde."
                    else -> ""
                }
                throw IOException("Error $code: $msg$hint")
            }

            val candidates = JSONObject(raw).optJSONArray("candidates")
                ?: throw IOException("Respuesta vacía de la IA.")
            val parts = candidates.getJSONObject(0).optJSONObject("content")?.optJSONArray("parts")
                ?: throw IOException("La IA no ha devuelto texto.")
            val sb = StringBuilder()
            for (i in 0 until parts.length()) {
                sb.append(parts.getJSONObject(i).optString("text", ""))
            }
            return clean(sb.toString())
        } finally {
            conn.disconnect()
        }
    }

    /** Quita restos de markdown por si acaso. */
    private fun clean(s: String): String =
        s.replace("**", "")
            .replace(Regex("(?m)^#+\\s*"), "")
            .replace(Regex("(?m)^\\s*[*\\-]\\s+"), "• ")
            .replace(Regex("\\n{3,}"), "\n\n")
            .trim()
}
