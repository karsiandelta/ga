package com.cristian.oyetio

import android.content.Context
import android.content.res.AssetManager
import java.io.File
import java.io.IOException

/** Copia el modelo de voz en español desde la app a la memoria interna (solo la primera vez). */
object ModelInstaller {
    private const val ASSET_DIR = "model-es"

    fun ensure(ctx: Context): File {
        val dir = File(ctx.filesDir, ASSET_DIR)
        val marker = File(dir, ".instalado")
        if (marker.exists()) return dir

        val top = ctx.assets.list(ASSET_DIR)
        if (top.isNullOrEmpty()) {
            throw IOException("Falta el modelo de voz dentro de la app. Compílala con el workflow de GitHub.")
        }
        dir.deleteRecursively()
        copy(ctx.assets, ASSET_DIR, dir)
        marker.writeText("ok")
        return dir
    }

    private fun copy(am: AssetManager, path: String, dest: File) {
        val children = am.list(path) ?: emptyArray()
        if (children.isEmpty()) {
            dest.parentFile?.mkdirs()
            am.open(path).use { input -> dest.outputStream().use { input.copyTo(it) } }
        } else {
            dest.mkdirs()
            for (name in children) copy(am, "$path/$name", File(dest, name))
        }
    }
}
