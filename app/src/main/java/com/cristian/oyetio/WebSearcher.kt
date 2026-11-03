package com.cristian.oyetio

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder

/** Búsqueda web gratuita (DuckDuckGo) y lectura del texto de las primeras páginas. */
object WebSearcher {

    data class Result(val title: String, val url: String, val snippet: String)

    private const val UA =
        "Mozilla/5.0 (Linux; Android 15; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36"

    fun search(query: String, max: Int = 6): List<Result> {
        val html = get("https://html.duckduckgo.com/html/?kl=es-es&q=" + URLEncoder.encode(query, "UTF-8"), 300_000)
            ?: return emptyList()
        val links = Regex("""<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>""", RegexOption.DOT_MATCHES_ALL)
            .findAll(html).toList()
        val snippets = Regex("""class="result__snippet"[^>]*>(.*?)</a>""", RegexOption.DOT_MATCHES_ALL)
            .findAll(html).map { strip(it.groupValues[1]) }.toList()

        val out = mutableListOf<Result>()
        for ((i, m) in links.withIndex()) {
            val url = realUrl(m.groupValues[1]) ?: continue
            if ("duckduckgo.com" in url) continue // anuncios
            out += Result(strip(m.groupValues[2]), url, snippets.getOrElse(i) { "" })
            if (out.size >= max) break
        }
        return out
    }

    /** Texto legible de una página (sin scripts ni etiquetas), recortado. */
    fun pageText(url: String, maxChars: Int = 3500): String {
        val html = get(url, 600_000) ?: return ""
        val body = html
            .replace(Regex("(?is)<(script|style|noscript|svg|header|footer|nav)[^>]*>.*?</\\1>"), " ")
        return strip(body).take(maxChars)
    }

    private fun realUrl(href: String): String? {
        val h = href.replace("&amp;", "&")
        val uddg = Regex("[?&]uddg=([^&]+)").find(h)?.groupValues?.get(1)
        val u = if (uddg != null) URLDecoder.decode(uddg, "UTF-8") else if (h.startsWith("//")) "https:$h" else h
        return u.takeIf { it.startsWith("http") }
    }

    private fun strip(s: String): String =
        s.replace(Regex("(?s)<[^>]+>"), " ")
            .replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", "\"")
            .replace("&#x27;", "'").replace("&#39;", "'").replace("&lt;", "<").replace("&gt;", ">")
            .replace("&euro;", "€")
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun get(url: String, maxBytes: Int): String? = try {
        val c = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 8_000
            readTimeout = 10_000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", UA)
            setRequestProperty("Accept-Language", "es-ES,es;q=0.9")
        }
        try {
            if (c.responseCode !in 200..299) null
            else c.inputStream.use { input ->
                val buf = java.io.ByteArrayOutputStream()
                val chunk = ByteArray(16 * 1024)
                while (buf.size() < maxBytes) {
                    val n = input.read(chunk)
                    if (n < 0) break
                    buf.write(chunk, 0, n)
                }
                buf.toString("UTF-8")
            }
        } finally {
            c.disconnect()
        }
    } catch (e: Exception) {
        null
    }
}
