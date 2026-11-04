package com.cristian.oyetio

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Acceso a notificaciones. Sirve para dos cosas:
 * - controlar Spotify (y cualquier reproductor) aunque el móvil esté bloqueado,
 * - leerte los últimos mensajes que te han llegado cuando se lo pides.
 * Lo guarda solo en memoria (los últimos 40) y nunca lo envía a ningún sitio salvo que se lo pidas.
 */
class NotifListener : NotificationListenerService() {

    data class Item(val pkg: String, val title: String, val text: String, val time: Long)

    companion object {
        private val recent = ArrayDeque<Item>()
        @Volatile var connected = false

        fun latest(filter: (Item) -> Boolean, max: Int): List<Item> = synchronized(recent) {
            recent.filter(filter).sortedByDescending { it.time }.distinctBy { it.title + "|" + it.text }.take(max)
        }
    }

    override fun onListenerConnected() { connected = true }
    override fun onListenerDisconnected() { connected = false }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val s = sbn ?: return
        if (s.packageName == packageName || s.isOngoing) return
        val n = s.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val ex = n.extras ?: return
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString()?.trim().orEmpty()
        if (title.isEmpty() && text.isEmpty()) return
        synchronized(recent) {
            recent.addLast(Item(s.packageName, title, text, s.postTime))
            while (recent.size > 40) recent.removeFirst()
        }
    }
}
