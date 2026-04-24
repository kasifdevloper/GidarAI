package ai.gidar.app.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ai.gidar.app.data.repository.ChatRepository
import ai.gidar.app.data.repository.SettingsRepository
import ai.gidar.app.theme.GidarTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    val hasApiKey: StateFlow<Boolean> = settingsRepository.apiKey
        .map { !it.isNullOrBlank() }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val selectedModelName: StateFlow<String> = settingsRepository.selectedModelName
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "GPT-4o Mini")

    val appTheme: StateFlow<GidarTheme> = settingsRepository.appTheme
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), GidarTheme.ORIGINAL)

    fun startChat(message: String, onChatCreated: (String) -> Unit) {
        viewModelScope.launch {
            val chatId = chatRepository.createNewChat(message)
            onChatCreated(chatId)
        }
    }

    fun saveModel(id: String, name: String) {
        viewModelScope.launch {
            settingsRepository.saveSelectedModel(id, name)
        }
    }
}
