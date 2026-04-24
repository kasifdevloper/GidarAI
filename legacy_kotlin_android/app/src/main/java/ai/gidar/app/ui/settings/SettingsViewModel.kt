package ai.gidar.app.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ai.gidar.app.data.repository.ChatRepository
import ai.gidar.app.data.repository.SettingsRepository
import ai.gidar.app.theme.GidarTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val chatRepository: ChatRepository
) : ViewModel() {

    val apiKey: StateFlow<String?> = settingsRepository.apiKey
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val selectedModelId: StateFlow<String> = settingsRepository.selectedModelId
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "openai/gpt-4o-mini")

    val systemPrompt: StateFlow<String> = settingsRepository.systemPrompt
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "")

    val appTheme: StateFlow<GidarTheme> = settingsRepository.appTheme
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), GidarTheme.ORIGINAL)

    fun saveApiKey(key: String) {
        viewModelScope.launch { settingsRepository.saveApiKey(key) }
    }

    fun saveSystemPrompt(prompt: String) {
        viewModelScope.launch { settingsRepository.saveSystemPrompt(prompt) }
    }

    fun saveTheme(theme: GidarTheme) {
        viewModelScope.launch { settingsRepository.saveAppTheme(theme) }
    }

    fun clearAllChats() {
        viewModelScope.launch { chatRepository.clearAll() }
    }

    fun clearAllData() {
        viewModelScope.launch {
            settingsRepository.clearAllData()
            chatRepository.clearAll()
        }
    }
}
