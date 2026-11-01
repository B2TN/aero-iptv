package com.aeroiptv.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Point d'entrée Android : relie Flutter aux services natifs de l'application. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        DeviceProfileChannel(applicationContext).attach(messenger)
        SecureStoreChannel(applicationContext).attach(messenger)
        ExternalPlayerChannel(applicationContext).attach(messenger)
    }
}
