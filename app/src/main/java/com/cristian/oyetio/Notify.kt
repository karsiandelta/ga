package com.cristian.oyetio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import kotlin.random.Random

/** Todas las notificaciones de la app. */
object Notify {
    const val CH_SERVICE = "escucha"
    const val CH_RESULT = "respuestas"
    const val CH_POPUP = "respuestas_pantalla"
    const val CH_MSG = "mensajes"

    const val ID_SERVICE = 1
    const val ID_RESULT = 2
    const val ID_POPUP = 3
    const val ID_CONFIRM = 4

    private const val FLAGS = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT

    fun msgId(m: Msg) = 1000 + (m.id and 0xFFFF)

    private fun nm(c: Context) = c.getSystemService(NotificationManager::class.java)

    fun ensure(c: Context) {
        val nm = nm(c)
        nm.createNotificationChannel(
            NotificationChannel(CH_SERVICE, "Escuchando", NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_RESULT, "Respuestas", NotificationManager.IMPORTANCE_DEFAULT).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_POPUP, "Respuesta en pantalla", NotificationManager.IMPORTANCE_HIGH).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_MSG, "Mensajes", NotificationManager.IMPORTANCE_HIGH).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
    }

    private fun base(c: Context, ch: String, title: String, text: String) =
        Notification.Builder(c, ch)
            .setSmallIcon(R.drawable.ic_mic)
            .setColor(Neon.CYAN)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setVisibility(Notification.VISIBILITY_PUBLIC)

    fun service(c: Context, text: String): Notification {
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(
            c, 1, Intent(c, ListenService::class.java).setAction(ListenService.ACTION_STOP), PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(c, CH_SERVICE)
            .setSmallIcon(R.drawable.ic_mic)
            .setColor(Neon.CYAN)
            .setContentTitle("Oye Tío")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(open)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "Parar", stop).build())
            .build()
    }

    fun result(c: Context, title: String, body: String, popup: Boolean, ongoing: Boolean) {
        val show = PendingIntent.getActivity(
            c, 2, Intent(c, ResultActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), FLAGS
        )
        val b = base(c, if (popup) CH_POPUP else CH_RESULT, title, body)
            .setContentIntent(show)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .setCategory(Notification.CATEGORY_MESSAGE)
        val nm = nm(c)
        if (popup) {
            b.setFullScreenIntent(show, true)
            nm.cancel(ID_RESULT)
            nm.notify(ID_POPUP, b.build())
        } else {
            nm.cancel(ID_POPUP)
            nm.notify(ID_RESULT, b.build())
        }
    }

    fun info(c: Context, title: String, text: String, id: Int = 5000 + Random.nextInt(1000)) {
        val open = PendingIntent.getActivity(c, 3, Intent(c, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        nm(c).notify(id, base(c, CH_MSG, title, text).setContentIntent(open).setAutoCancel(true).build())
    }

    fun confirm(c: Context, m: Msg, popup: Boolean) {
        val open = PendingIntent.getActivity(
            c, 10,
            Intent(c, ResultActivity::class.java)
                .putExtra(ResultActivity.EXTRA_MODE, ResultActivity.MODE_CONFIRM)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            FLAGS
        )
        val send = PendingIntent.getBroadcast(
            c, 11, Intent(c, ActionReceiver::class.java).setAction(ActionReceiver.SEND), FLAGS
        )
        val cancel = PendingIntent.getBroadcast(
            c, 12, Intent(c, ActionReceiver::class.java).setAction(ActionReceiver.CANCEL), FLAGS
        )
        val scheduled = m.at > System.currentTimeMillis() + 60_000
        val title = (if (scheduled) "¿Programar " else "¿Enviar ") + "${m.appLabel} a ${m.name}?"
        val text = (if (scheduled) Messenger.describeWhen(m.at) + " · " else "") + "“${m.text}”"
        val b = base(c, if (popup) CH_POPUP else CH_MSG, title, text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .addAction(Notification.Action.Builder(null, if (scheduled) "Programar" else "Enviar", send).build())
            .addAction(Notification.Action.Builder(null, "Cancelar", cancel).build())
        if (popup) b.setFullScreenIntent(open, true)
        nm(c).notify(ID_CONFIRM, b.build())
    }

    /** Aviso que abre WhatsApp con el mensaje al tocarlo. */
    fun tapToSend(c: Context, m: Msg, title: String, text: String) {
        val pi = PendingIntent.getActivity(
            c, msgId(m),
            Intent(c, SendActivity::class.java)
                .putExtra("msg", m.toJson().toString())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            FLAGS
        )
        nm(c).notify(
            msgId(m),
            base(c, CH_MSG, title, text).setContentIntent(pi).setAutoCancel(true).setTimeoutAfter(30 * 60 * 1000L).build()
        )
    }

    fun cancel(c: Context, id: Int) = nm(c).cancel(id)
}
