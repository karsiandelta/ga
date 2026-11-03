package com.cristian.oyetio

import android.accessibilityservice.AccessibilityService
import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import org.json.JSONObject

/**
 * Pulsa el botón "Enviar" de WhatsApp SOLO justo después de que Oye Tío abra un chat
 * con un mensaje que tú has confirmado. No lee ni guarda nada más.
 */
class WaAccessibility : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (System.currentTimeMillis() > WaAuto.armedUntil) return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString()?.startsWith("com.whatsapp") != true) return
        var btn = findSend(root) ?: return
        while (!btn.isClickable) btn = btn.parent ?: return
        if (!btn.isEnabled) return

        val m = WaAuto.current
        WaAuto.armedUntil = 0L
        if (btn.performAction(AccessibilityNodeInfo.ACTION_CLICK) && m != null) {
            WaAuto.sent.add(m.id)
            Notify.cancel(this, Notify.msgId(m))
            Notify.info(this, "WhatsApp enviado a ${m.name}", m.text)
            main.postDelayed({ performGlobalAction(GLOBAL_ACTION_HOME) }, 900)
        }
    }

    private fun findSend(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            for (id in listOf("send", "send_container")) {
                root.findAccessibilityNodeInfosByViewId("$pkg:id/$id")
                    ?.firstOrNull { it.isVisibleToUser }
                    ?.let { return it }
            }
        }
        // Por si WhatsApp cambia el identificador: busca el botón por su descripción
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        var guard = 0
        while (stack.isNotEmpty() && guard++ < 1500) {
            val n = stack.removeLast()
            val d = n.contentDescription?.toString()?.trim()?.lowercase()
            if ((d == "enviar" || d == "send") && n.isVisibleToUser) return n
            for (i in 0 until n.childCount) n.getChild(i)?.let { stack.add(it) }
        }
        return null
    }

    override fun onInterrupt() {}
}

/** Pantalla invisible que abre WhatsApp al tocar una notificación. */
class SendActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val m = intent?.getStringExtra("msg")?.let { runCatching { Msg.fromJson(JSONObject(it)) }.getOrNull() }
        if (m != null) {
            Messenger.removeFromQueue(this, m.id)
            if (!Messenger.openWhatsApp(this, m)) {
                Toast.makeText(this, "No he podido abrir WhatsApp", Toast.LENGTH_LONG).show()
            }
        }
        finish()
    }
}
