package com.aeroiptv.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Installe une mise à jour téléchargée par l'application.
 *
 * Android exige que l'utilisateur autorise une fois l'application à installer
 * des paquets, puis confirme chaque installation.
 */
class UpdateInstallerChannel(private val activity: Activity) {
    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstall())
                "openSettings" -> {
                    openSettings()
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("missing_path", "Chemin absent.", null)
                    } else {
                        install(File(path))
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    /**
     * Ouvre l'autorisation propre à l'application, ou à défaut les réglages
     * de sécurité : Fire TV range cette option dans ses options pour
     * développeurs.
     */
    private fun openSettings() {
        val intents = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                add(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                )
            }
            add(Intent(Settings.ACTION_SECURITY_SETTINGS))
            add(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
        }
        for (intent in intents) {
            try {
                activity.startActivity(intent)
                return
            } catch (_: ActivityNotFoundException) {
                // Réglage absent sur cet appareil : le suivant.
            }
        }
    }

    private fun install(apk: File) {
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }

    private companion object {
        const val CHANNEL = "aero_iptv/updates"
    }
}
