package com.cristian.oyetio

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import kotlin.math.min

/**
 * Avisa cuando el móvil sale del bolsillo, usando el sensor de proximidad.
 * - Si el sensor dice "tapado" y luego "destapado" -> has sacado el móvil.
 * - Si en 2,5 s nunca está tapado -> el móvil ya está fuera, avisa enseguida.
 */
class PocketDetector(ctx: Context, private val onOut: () -> Unit) : SensorEventListener {

    private val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor: Sensor? =
        sm.getDefaultSensor(Sensor.TYPE_PROXIMITY, true) ?: sm.getDefaultSensor(Sensor.TYPE_PROXIMITY)
    private val handler = Handler(Looper.getMainLooper())
    private var wasCovered = false
    private var done = false

    fun start() {
        val s = sensor
        if (s == null) {
            fire(); return
        }
        sm.registerListener(this, s, SensorManager.SENSOR_DELAY_NORMAL)
        handler.postDelayed({ if (!wasCovered) fire() }, 2_500)
        handler.postDelayed({ stop() }, 15 * 60 * 1000L) // deja de esperar a los 15 min
    }

    override fun onSensorChanged(e: SensorEvent) {
        val s = sensor ?: return
        val covered = e.values[0] < min(s.maximumRange, 3f)
        if (covered) wasCovered = true
        else if (wasCovered) fire()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun fire() {
        if (done) return
        done = true
        stop()
        onOut()
    }

    fun stop() {
        sm.unregisterListener(this)
        handler.removeCallbacksAndMessages(null)
    }
}
