package ai.gidar.app.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import ai.gidar.app.R
import ai.gidar.app.data.local.SecureStorage
import ai.gidar.app.theme.GidarTheme
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = context.getString(R.string.settings_datastore))

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val secureStorage: SecureStorage
) {
    private val SELECTED_MODEL_ID = stringPreferencesKey("selected_model_id")
    private val SELECTED_MODEL_NAME = stringPreferencesKey("selected_model_name")
    private val SYSTEM_PROMPT = stringPreferencesKey("system_prompt")
    private val APP_THEME = stringPreferencesKey("app_theme")
    private val CUSTOM_MODELS = stringPreferencesKey("custom_models")

    val apiKey: Flow<String?> = flow {
        emit(secureStorage.getApiKey())
    }
    val selectedModelId: Flow<String> = context.dataStore.data.map { it[SELECTED_MODEL_ID] ?: context.getString(R.string.gpt_4o_mini_id) }
    val selectedModelName: Flow<String> = context.dataStore.data.map { it[SELECTED_MODEL_NAME] ?: context.getString(R.string.gpt_4o_mini) }
    val systemPrompt: Flow<String> = context.dataStore.data.map { it[SYSTEM_PROMPT] ?: context.getString(R.string.default_system_prompt) }
    val appTheme: Flow<GidarTheme> = context.dataStore.data.map {
        GidarTheme.valueOf(it[APP_THEME] ?: GidarTheme.ORIGINAL.name)
    }
    val customModels: Flow<String?> = context.dataStore.data.map { it[CUSTOM_MODELS] }

    suspend fun saveApiKey(key: String) {
        secureStorage.saveApiKey(key)
    }

    suspend fun saveSelectedModel(id: String, name: String) {
        context.dataStore.edit {
            it[SELECTED_MODEL_ID] = id
            it[SELECTED_MODEL_NAME] = name
        }
    }

    suspend fun saveSystemPrompt(prompt: String) {
        context.dataStore.edit { it[SYSTEM_PROMPT] = prompt }
    }

    suspend fun saveAppTheme(theme: GidarTheme) {
        context.dataStore.edit { it[APP_THEME] = theme.name }
    }

    suspend fun saveCustomModels(json: String) {
        context.dataStore.edit { it[CUSTOM_MODELS] = json }
    }

    suspend fun clearAllData() {
        context.dataStore.edit { it.clear() }
        secureStorage.clearAll()
    }
}
