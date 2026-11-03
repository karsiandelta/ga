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
 * Cerebro de la app (Google Gemini):
 * 1) route(): entiende la orden → buscar en internet, responder directamente o enviar/programar un mensaje.
 * 2) answer(): busca en internet (gratis, DuckDuckGo) y resume para la pantalla de bloqueo.
 */
object GeminiClient {

    /** Modelos con plan gratuito, por si alguno está saturado o deja de existir. */
    private val FALLBACK_MODELS = listOf("gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite")
    private val ES = Locale("es", "ES")

    private class ApiError(val code: Int, msg: String) : IOException(msg)

    sealed class Route {
        data class Search(val queries: List<String>) : Route()
        data class Answer(val text: String) : Route()
        data class Message(val app: String, val contact: String, val text: String, val at: Long) : Route()
    }

    private fun models(model: String) = (listOf(model) + FALLBACK_MODELS).distinct()

    // ---------- 1) Entender la orden ----------

    fun route(apiKey: String, model: String, question: String): Route {
        if (apiKey.isBlank()) throw IOException("Falta la clave de API. Abre la app y pégala en Ajustes.")
        val nowHuman = SimpleDateFormat("EEEE d 'de' MMMM 'de' yyyy, HH:mm", ES).format(Date())
        val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).format(Date())
        val sys = """
            Eres el cerebro de "Oye Tío", un asistente de voz en español de España.
            Ahora es $nowHuman (formato ISO: $nowIso).
            La orden viene de un dictado por voz y puede tener palabras mal reconocidas o sin tildes: interpreta lo que quiso decir.
            Devuelve SOLO un objeto JSON con UNA de estas formas:

            1) Enviar o programar un mensaje ("mándale", "escríbele", "dile a", "envía un WhatsApp", "SMS a", "recuérdale a"...):
            {"tipo":"mensaje","app":"whatsapp","contacto":"nombre tal como lo dijo","texto":"el mensaje","cuando":""}
               - "app": "sms" solo si dice SMS o mensaje de texto; en cualquier otro caso "whatsapp".
               - "texto": el mensaje bien escrito, con tildes, mayúscula inicial y puntuación, tal como lo enviaría el usuario en primera persona.
                 Ejemplo: "dile a mamá que llego a las 8" → "Llego a las 8."
               - "cuando": "" si es para ahora; si dice una fecha u hora, "YYYY-MM-DDTHH:MM" calculado desde la fecha actual
                 ("mañana a las 9" → mañana 09:00; "a las 5 de la tarde" → hoy 17:00, o mañana si ya ha pasado; "dentro de 2 horas" → ahora + 2 h).

            2) Preguntas que necesitan información actual de internet (horarios, precios, noticias, tiempo, resultados, tiendas, eventos...):
            {"tipo":"buscar","busquedas":["búsqueda 1","búsqueda 2"]}
               - 1 o 2 búsquedas web cortas en español. Para viajes, una de horarios y otra de precios.

            3) Cosas que puedes responder bien sin internet (cálculos, definiciones, consejos generales, la hora o la fecha):
            {"tipo":"responder","texto":"respuesta corta, sin markdown, máximo 8 líneas, primera línea como título"}
        """.trimIndent()
        val raw = withModels(models(model)) { m -> call(apiKey, m, sys, question, grounded = false, json = true) }
        return parseRoute(raw, question)
    }

    private fun parseRoute(raw: String, question: String): Route = try {
        val s = raw.trim()
        val o = JSONObject(s.substring(s.indexOf('{'), s.lastIndexOf('}') + 1))
        when (o.optString("tipo").lowercase(Locale.ROOT)) {
            "mensaje" -> {
                val contact = o.optString("contacto").trim()
                val text = o.optString("texto").trim()
                if (contact.isEmpty() || text.isEmpty()) Route.Search(listOf(question))
                else Route.Message(
                    if (o.optString("app").lowercase(Locale.ROOT).contains("sms")) "sms" else "whatsapp",
                    contact, text, parseWhen(o.optString("cuando"))
                )
            }
            "responder" -> o.optString("texto").trim().let {
                if (it.isEmpty()) Route.Search(listOf(question)) else Route.Answer(clean(it))
            }
            else -> {
                val arr = o.optJSONArray("busquedas")
                val qs = (0 until (arr?.length() ?: 0))
                    .map { arr!!.optString(it).trim() }
                    .filter { it.isNotEmpty() }
                    .take(2)
                Route.Search(qs.ifEmpty { listOf(question) })
            }
        }
    } catch (e: Exception) {
        Route.Search(listOf(question))
    }

    private fun parseWhen(s: String): Long {
        val t = s.trim()
        if (t.isEmpty()) return 0L
        for (f in listOf("yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm")) {
            val d = try {
                SimpleDateFormat(f, Locale.US).apply { isLenient = false }.parse(t)
            } catch (e: Exception) { null }
            if (d != null) return d.time
        }
        return 0L
    }

    // ---------- 2) Buscar y responder ----------

    fun answer(apiKey: String, model: String, question: String, queries: List<String>, googleSearch: Boolean): String {
        if (googleSearch) {
            return clean(withModels(models(model)) { m -> call(apiKey, m, answerPrompt(), question, grounded = true, json = false) })
        }
        val prompt = "PETICIÓN DEL USUARIO (dictada por voz): $question\n\n${webContext(queries)}"
        return clean(withModels(models(model)) { m -> call(apiKey, m, answerPrompt(), prompt, grounded = false, json = false) })
    }

    private fun webContext(queries: List<String>): String {
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

    private fun answerPrompt(): String {
        val now = SimpleDateFormat("EEEE d 'de' MMMM 'de' yyyy, HH:mm", ES).format(Date())
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

    // ---------- Llamada a la API ----------

    /**
     * Prueba los modelos en orden. Si uno está saturado (5xx) reintenta una vez y pasa al siguiente;
     * también salta los que no existen (404) o han agotado su cupo (429).
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

    private fun call(apiKey: String, model: String, system: String, user: String, grounded: Boolean, json: Boolean): String {
        val body = JSONObject().apply {
            put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", system))))
            put("contents", JSONArray().put(
                JSONObject().put("role", "user")
                    .put("parts", JSONArray().put(JSONObject().put("text", user)))
            ))
            if (grounded) put("tools", JSONArray().put(JSONObject().put("google_search", JSONObject())))
            if (json) put("generationConfig", JSONObject().put("responseMimeType", "application/json"))
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
                    429 -> if (grounded)
                        "La búsqueda de Google de Gemini no entra en el plan gratis. Desactiva esa opción en Ajustes."
                    else "Has hecho demasiadas consultas seguidas o has llegado al límite gratis de hoy. Prueba en un rato."
                    500, 502, 503, 504 -> "Los servidores de Google están saturados ahora mismo. Prueba en un par de minutos."
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
            return sb.toString()
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
