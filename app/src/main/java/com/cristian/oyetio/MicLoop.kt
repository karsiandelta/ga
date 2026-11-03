package com.cristian.oyetio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.NoiseSuppressor
import android.os.SystemClock
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sign
import kotlin.math.sqrt

/**
 * Micrófono propio a 16 kHz con:
 * - reducción de ruido del sistema (si el móvil la tiene),
 * - ganancia automática para oírte desde lejos (sube la voz baja, no satura la alta),
 * - detección de si estás hablando ahora mismo.
 */
class MicLoop(
    private val sensitivity: Int, // 1..10
    private val onAudio: (ShortArray, Int) -> Unit,
    private val onError: (String) -> Unit,
) {
    @Volatile private var running = false
    @Volatile var lastVoiceAt = 0L
        private set
    @Volatile var level = 0f
        private set
    private var thread: Thread? = null

    fun start() {
        running = true
        thread = Thread({ loop() }, "oyetio-mic").also {
            it.priority = Thread.MAX_PRIORITY
            it.start()
        }
    }

    fun stop() {
        running = false
        val t = thread
        thread = null
        if (t != null && t !== Thread.currentThread()) t.join(1500)
    }

    @SuppressLint("MissingPermission")
    private fun loop() {
        val rate = 16000
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val rec = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, max(min, rate)
            )
        } catch (e: Exception) {
            onError(e.message ?: "sin micrófono"); return
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release(); onError("micrófono ocupado"); return
        }
        val ns = try {
            if (NoiseSuppressor.isAvailable()) NoiseSuppressor.create(rec.audioSessionId)?.also { it.enabled = true } else null
        } catch (e: Exception) { null }

        val buf = ShortArray(1600) // 100 ms
        val maxGain = 1f + sensitivity * 1.4f
        var gain = 1f + sensitivity * 0.3f
        var floor = 200.0
        try {
            rec.startRecording()
            if (rec.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                onError("micrófono ocupado"); return
            }
            while (running) {
                val n = rec.read(buf, 0, buf.size)
                if (n < 0) { onError("error de lectura ($n)"); return }
                if (n == 0) continue
                var sum = 0.0
                for (i in 0 until n) { val s = buf[i].toDouble(); sum += s * s }
                val rms = sqrt(sum / n)
                // Ruido de fondo: baja rápido, sube muy despacio
                floor = if (rms < floor) floor * 0.8 + rms * 0.2 else floor * 0.995 + rms * 0.005
                val voice = rms > floor * 2.5 && rms > 120
                if (voice) {
                    lastVoiceAt = SystemClock.elapsedRealtime()
                    val desired = (3500.0 / rms).toFloat().coerceIn(1f, maxGain)
                    gain += (desired - gain) * (if (desired < gain) 0.6f else 0.15f)
                }
                if (gain > 1.02f) for (i in 0 until n) buf[i] = clip(buf[i] * gain)
                level = ((rms * gain) / 9000.0).toFloat().coerceIn(0f, 1f)
                onAudio(buf, n)
            }
        } catch (e: Exception) {
            onError(e.message ?: "error de micrófono")
        } finally {
            try { rec.stop() } catch (_: Exception) {}
            rec.release()
            try { ns?.release() } catch (_: Exception) {}
            level = 0f
        }
    }

    /** Limitador suave para no distorsionar cuando subimos la ganancia. */
    private fun clip(v: Float): Short {
        val a = abs(v)
        val o = if (a <= 22000f) a else 22000f + (a - 22000f) * 0.25f
        return (sign(v) * min(o, 32767f)).toInt().toShort()
    }
}
