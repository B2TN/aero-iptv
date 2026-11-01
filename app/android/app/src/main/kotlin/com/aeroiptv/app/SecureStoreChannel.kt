package com.aeroiptv.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Coffre des identifiants IPTV.
 *
 * Les données sont chiffrées en AES-GCM avec une clé du Keystore Android, qui ne
 * quitte jamais le système. Seul le texte chiffré est écrit sur le stockage. Les
 * messages d'erreur ne citent aucune valeur.
 */
class SecureStoreChannel(context: Context) {
    private val preferences =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "read" -> result.success(read(call.arguments as String))
                    "write" -> {
                        write(call)
                        result.success(null)
                    }
                    "delete" -> {
                        preferences.edit().remove(call.arguments as String).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: GeneralSecurityException) {
                result.error("vault", "Coffre indisponible.", null)
            } catch (_: IllegalArgumentException) {
                result.error("vault", "Entrée du coffre illisible.", null)
            }
        }
    }

    private fun read(key: String): String? {
        val stored = preferences.getString(key, null) ?: return null
        val bytes = Base64.decode(stored, Base64.NO_WRAP)
        val iv = bytes.copyOfRange(0, IV_BYTES)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(TAG_BITS, iv))
        val clear = cipher.doFinal(bytes, IV_BYTES, bytes.size - IV_BYTES)
        return String(clear, Charsets.UTF_8)
    }

    private fun write(call: MethodCall) {
        val key = call.argument<String>("key")
        val value = call.argument<String>("value")
        requireNotNull(key)
        requireNotNull(value)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        // Le Keystore génère un vecteur d'initialisation neuf à chaque écriture.
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val stored = Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP)
        preferences.edit().putString(key, stored).apply()
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as SecretKey?)?.let { return it }

        val generator =
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec
                .Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(KEY_BITS)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val CHANNEL = "aero_iptv/secure_store"
        const val PREFERENCES = "aero_iptv_vault"
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "aero_iptv_credentials"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_BITS = 256
        const val IV_BYTES = 12
        const val TAG_BITS = 128
    }
}
