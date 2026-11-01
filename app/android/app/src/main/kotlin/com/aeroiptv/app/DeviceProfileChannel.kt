package com.aeroiptv.app

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Décrit l'appareil à Flutter.
 *
 * La mémoire totale fixe les plafonds de l'application : tampons vidéo et cache
 * d'images. La détection TV couvre Android TV et Fire TV, qui ne déclare pas
 * toujours la fonctionnalité Leanback.
 */
class DeviceProfileChannel(private val context: Context) {
    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "profile") {
                result.success(profile())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun profile(): Map<String, Any> {
        val activities =
            context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo().also(activities::getMemoryInfo)
        val packages = context.packageManager
        val isTv =
            packages.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                packages.hasSystemFeature(FEATURE_FIRE_TV)
        return mapOf(
            "totalRamMb" to (memory.totalMem / BYTES_PER_MEBIBYTE).toInt(),
            "isTv" to isTv,
        )
    }

    private companion object {
        const val CHANNEL = "aero_iptv/device"
        const val FEATURE_FIRE_TV = "amazon.hardware.fire_tv"
        const val BYTES_PER_MEBIBYTE = 1024L * 1024L
    }
}
