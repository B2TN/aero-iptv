package com.aeroiptv.app

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Empêche l'écran de veille pendant une tâche longue, comme un import.
 *
 * Le réglage porte sur la vue, et non sur la fenêtre : le lecteur vidéo utilise
 * le drapeau de la fenêtre pendant la lecture, et aucun des deux ne doit
 * éteindre ce que l'autre a allumé.
 */
class KeepAwakeChannel(private val activity: Activity) {
    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "set") {
                activity.window.decorView.keepScreenOn = call.arguments == true
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private companion object {
        const val CHANNEL = "aero_iptv/screen"
    }
}
