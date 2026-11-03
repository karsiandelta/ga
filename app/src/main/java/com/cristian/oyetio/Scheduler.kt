package com.cristian.oyetio

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Mensajes programados con alarmas del sistema (funcionan aunque la app esté cerrada). */
object Scheduler {
    private const val KEY = "scheduled"

    fun add(c: Context, m: Msg) {
        val list = Prefs.getList(c, KEY)
        list.removeAll { it.id == m.id }
        list.add(m)
        list.sortBy { it.at }
        Prefs.putList(c, KEY, list)
        set(c, m)
    }

    fun remove(c: Context, id: Int) {
        val list = Prefs.getList(c, KEY)
        if (list.removeAll { it.id == id }) Prefs.putList(c, KEY, list)
        c.getSystemService(AlarmManager::class.java).cancel(pi(c, id))
    }

    fun take(c: Context, id: Int): Msg? {
        val list = Prefs.getList(c, KEY)
        val m = list.firstOrNull { it.id == id } ?: return null
        list.remove(m)
        Prefs.putList(c, KEY, list)
        return m
    }

    fun rescheduleAll(c: Context) {
        Prefs.getList(c, KEY).forEach { set(c, it) }
    }

    private fun pi(c: Context, id: Int) = PendingIntent.getBroadcast(
        c, id,
        Intent(c, AlarmReceiver::class.java).setAction("com.cristian.oyetio.ALARM").putExtra("id", id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    private fun set(c: Context, m: Msg) {
        val am = c.getSystemService(AlarmManager::class.java)
        val at = maxOf(m.at, System.currentTimeMillis() + 2_000)
        try {
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi(c, m.id))
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi(c, m.id))
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi(c, m.id))
        }
    }
}

/** Llega la hora de un mensaje programado. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        Notify.ensure(c)
        val id = i.getIntExtra("id", -1)
        val m = Scheduler.take(c, id) ?: return
        Messenger.deliverNow(c, m)
    }
}

/** Tras reiniciar el móvil o actualizar la app, vuelve a poner las alarmas. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        Scheduler.rescheduleAll(c)
    }
}

/** Botones "Enviar" / "Cancelar" de la notificación de confirmación. */
class ActionReceiver : BroadcastReceiver() {
    companion object {
        const val SEND = "com.cristian.oyetio.SEND_PENDING"
        const val CANCEL = "com.cristian.oyetio.CANCEL_PENDING"
    }

    override fun onReceive(c: Context, i: Intent) {
        Notify.ensure(c)
        when (i.action) {
            SEND -> Notify.info(c, "Oye Tío", Messenger.confirmPending(c))
            CANCEL -> {
                Messenger.cancelPending(c)
                Notify.info(c, "Oye Tío", "Mensaje cancelado.")
            }
        }
    }
}
