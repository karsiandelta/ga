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
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Pregunta a Gemini.
 * - Modo gratis: la app busca en internet (DuckDuckGo), lee las primeras páginas y Gemini lo resume.
 * - Modo Google: Gemini busca con Google él mismo (necesita facturación activada en Google AI Studio).
 */
object GeminiClient {

    /** Modelos con plan gratuito, por si alguno deja de existir. */
    private val FALLBACK_MODELS = listOf("gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite")

    private class ApiError(val code: Int, msg: String) : IOException(msg)

    fun ask(apiKey: String, model: String, question: String, googleSearch: Boolean): String {
        if (apiKey.isBlank()) throw IOException("Falta la clave de API. Abre la app y pégala.")
        val models = (listOf(model) + FALLBACK_MODELS).distinct()
        return if (googleSearch) {
            withModels(models) { m -> call(apiKey, m, systemPrompt(), question, grounded = true) }
        } else {
            val context = webContext(apiKey, models, question)
            val prompt = "PETICIÓN DEL USUARIO (dictada por voz): $question\n\n$context"
            withModels(models) { m -> call(apiKey, m, systemPrompt(), prompt, grounded = false) }
        }
    }

    // ---------- Búsqueda gratis ----------

    private fun webContext(apiKey: String, models: List<String>, question: String): String {
        // 1) Gemini convierte lo dictado en 1-2 búsquedas buenas
        val queries = runCatching {
            withModels(models) { m ->
                call(
                    apiKey, m,
                    "Convierte la petición dictada por voz en 1 o 2 búsquedas web cortas en español, " +
                        "una por línea, sin numerar ni comillas. Corrige palabras mal reconocidas. " +
                        "Para viajes incluye una búsqueda de horarios y otra de precios.",
                    question, grounded = false
                )
            }.lines().map { it.trim().trim('-', '•', '"', ' ') }.filter { it.isNotEmpty() }.take(2)
        }.getOrNull().orEmpty().ifEmpty { listOf(question) }

        // 2) Busca y lee las primeras páginas en paralelo
        val results = queries.flatMap { WebSearcher.search(it, 5) }.distinctBy { it.url }.take(8)
        if (results.isEmpty()) return "RESULTADOS DE BÚSQUEDA: no se ha podido buscar en internet ahora mismo."

        val pool = Executors.newFixedThreadPool(3)
        val pages = try {
            val futures = results.take(4).map { r -> pool.submit(Callable { WebSearcher.pageText(r.url) }) }
            futures.map { f -> runCatching { f.get(15, TimeUnit.SECONDS) }.getOrDefault("") }
        } finally {
            pool.shutdownNow()
        }

        val sb = StringBuilder("RESULTADOS DE BÚSQUEDA (de hoy):\n")
        results.forEachIndexed { i, r ->
            sb.append("\n[${i + 1}] ${r.title}\n${r.url}\n${r.snippet}\n")
            val text = pages.getOrNull(i).orEmpty()
            if (text.isNotBlank()) sb.append("Contenido de la página: ").append(text).append("\n")
        }
        return sb.toString()
    }

    // ---------- Llamada a la API ----------

    private fun systemPrompt(): String {
        val now = SimpleDateFormat("EEEE d 'de' MMMM 'de' yyyy, HH:mm", Locale("es", "ES")).format(Date())
        return """
            Eres "Oye Tío", un asistente de voz. Ahora es $now y el usuario está en España.
            La petición viene de un dictado por voz: puede tener palabras mal reconocidas y sin tildes; interpreta lo que quiso decir.
            Usa SOLO la información de los resultados de búsqueda que recibes (o de tu búsqueda de Google si la tienes) para datos actuales.
            El usuario leerá la respuesta de un vistazo en la pantalla de bloqueo del móvil, así que:
            - Escribe en español, sin markdown, sin asteriscos, sin almohadillas, sin enlaces.
            - Primera línea: un título corto de lo que has buscado.
            - Después, una línea por opción, ordenadas por hora o por relevancia.
            - Para trenes, autobuses o vuelos: "HH:MM → HH:MM · duración · compañía · desde X €". Si no encuentras el precio, pon "precio no visto".
            - Máximo 12 líneas. Al final, si hace falta, una línea de aviso muy corta (por ejemplo, que los precios cambian).
            - Nunca inventes horarios ni precios; si no los encuentras en los resultados, dilo claramente.
        """.trimIndent()
    }

    /**
     * Prueba los modelos en orden. Si uno está saturado (503/500) reintenta una vez
     * y luego pasa al siguiente; también salta los que no existen (404) o han agotado su cupo (429).
     */
    private fun withModels(models: List<String>, block: (String) -> String): String {
        var last: Exception? = null
        for (m in models) {
            for (attempt in 0..1) {
                try {
                    return block(m)
                } catch (e: ApiError) {
                    last = e
                    when (e.code) {
                        500, 502, 503, 504 -> if (attempt == 0) Thread.sleep(2_000) else break
                        404, 429 -> break
                        else -> throw e
                    }
                }
            }
        }
        throw last ?: IOException("No hay modelos disponibles.")
    }

    private fun call(apiKey: String, model: String, system: String, user: String, grounded: Boolean): String {
        val body = JSONObject().apply {
            put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", system))))
            put("contents", JSONArray().put(
                JSONObject().put("role", "user")
                    .put("parts", JSONArray().put(JSONObject().put("text", user)))
            ))
            if (grounded) put("tools", JSONArray().put(JSONObject().put("google_search", JSONObject())))
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
                    .getOrDefault(raw.take(300)).take(200)
                val hint = when (code) {
                    400, 403 -> "Revisa que la clave de API esté bien copiada."
                    404 -> "El modelo \"$model\" no existe."
                    500, 502, 503, 504 -> "Los servidores de Google están saturados ahora mismo. Prueba en un par de minutos."
                    429 -> if (grounded)
                        "La búsqueda de Google de Gemini no entra en el plan gratis. Desmarca esa opción en la app."
                    else "Has hecho demasiadas consultas seguidas o has llegado al límite gratis de hoy. Prueba en un rato."
                    else -> ""
                }
                throw ApiError(code, "Error $code: $hint\n($msg)")
            }

            val candidates = JSONObject(raw).optJSONArray("candidates")
                ?: throw IOException("Respuesta vacía de la IA.")
            val parts = candidates.getJSONObject(0).optJSONObject("content")?.optJSONArray("parts")
                ?: throw IOException("La IA no ha devuelto texto.")
            val sb = StringBuilder()
            for (i in 0 until parts.length()) {
                val p = parts.getJSONObject(i)
                if (!p.optBoolean("thought", false)) sb.append(p.optString("text", ""))
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
