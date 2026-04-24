package ai.gidar.app.data.local

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import ai.gidar.app.R
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SecureStorage @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val encryptedPrefs = EncryptedSharedPreferences.create(
        context,
        context.getString(R.string.secure_prefs),
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveApiKey(apiKey: String) {
        encryptedPrefs.edit().putString("api_key", apiKey).apply()
    }

    fun getApiKey(): String? {
        return encryptedPrefs.getString("api_key", null)
    }

    fun clearApiKey() {
        encryptedPrefs.edit().remove("api_key").apply()
    }

    fun clearAll() {
        encryptedPrefs.edit().clear().apply()
    }
}
