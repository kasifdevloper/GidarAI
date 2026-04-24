package ai.gidar.app.ui.chat

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ai.gidar.app.R
import ai.gidar.app.data.local.ChatEntity
import ai.gidar.app.data.local.MessageEntity
import ai.gidar.app.data.repository.ChatRepository
import ai.gidar.app.data.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val settingsRepository: SettingsRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow<ChatUiState>(ChatUiState.Idle)
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    private val _commandEvent = MutableSharedFlow<CommandEvent>()
    val commandEvent: SharedFlow<CommandEvent> = _commandEvent.asSharedFlow()

    private val _paginatedMessages = MutableStateFlow<List<MessageEntity>>(emptyList())
    val paginatedMessages: StateFlow<List<MessageEntity>> = _paginatedMessages.asStateFlow()

    private val _isLoadingMore = MutableStateFlow(false)
    val isLoadingMore: StateFlow<Boolean> = _isLoadingMore.asStateFlow()

    private val _hasMoreMessages = MutableStateFlow(true)
    val hasMoreMessages: StateFlow<Boolean> = _hasMoreMessages.asStateFlow()

    private var currentPage = 0
    private val pageSize = 50

    val allChats: Flow<List<ChatEntity>> = chatRepository.getAllChats()
    
    val selectedModelName: StateFlow<String> = settingsRepository.selectedModelName
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "GPT-4o Mini")

    fun getMessages(chatId: String): Flow<List<MessageEntity>> = chatRepository.getMessagesForChat(chatId)

    fun loadMessagesPaginated(chatId: String, reset: Boolean = false) {
        viewModelScope.launch {
            if (reset) {
                currentPage = 0
                _paginatedMessages.value = emptyList()
                _hasMoreMessages.value = true
            }

            if (!_hasMoreMessages.value || _isLoadingMore.value) return@launch

            _isLoadingMore.value = true
            try {
                val messages = chatRepository.getMessagesForChatPaginated(chatId, currentPage, pageSize)
                if (messages.isEmpty()) {
                    _hasMoreMessages.value = false
                } else {
                    _paginatedMessages.value = _paginatedMessages.value + messages
                    currentPage++
                    _hasMoreMessages.value = messages.size == pageSize
                }
            } catch (e: Exception) {
                android.util.Log.e("ChatViewModel", "Error loading messages", e)
            } finally {
                _isLoadingMore.value = false
            }
        }
    }

    fun searchMessages(chatId: String, query: String) {
        viewModelScope.launch {
            try {
                val results = chatRepository.searchMessages(chatId, query)
                _paginatedMessages.value = results
                _hasMoreMessages.value = false
            } catch (e: Exception) {
                android.util.Log.e("ChatViewModel", "Error searching messages", e)
            }
        }
    }

    fun sendMessage(chatId: String, content: String) {
        viewModelScope.launch {
            val apiKey = settingsRepository.apiKey.first()
            if (apiKey.isNullOrBlank()) {
                _uiState.value = ChatUiState.Error(context.getString(R.string.api_key_missing))
                return@launch
            }
            
            _uiState.value = ChatUiState.Streaming("")
            chatRepository.saveMessage(chatId, "user", content)
            
            triggerResponse(chatId, content)
        }
    }

    private suspend fun triggerResponse(chatId: String, content: String) {
        chatRepository.sendMessageStream(chatId, content)
            .catch { e ->
                android.util.Log.e("ChatViewModel", "Stream error", e)
                _uiState.value = ChatUiState.Error(e.message ?: context.getString(R.string.network_error))
            }
            .collect { chunk ->
                _uiState.value = ChatUiState.Streaming(chunk)
                android.util.Log.d("ChatViewModel", "Received chunk length: ${chunk.length}")
            }
        _uiState.value = ChatUiState.Idle
    }

    fun triggerInitialResponse(chatId: String, content: String) {
        viewModelScope.launch {
            if (_uiState.value is ChatUiState.Idle) {
                val apiKey = settingsRepository.apiKey.first()
                if (apiKey.isNullOrBlank()) {
                    _uiState.value = ChatUiState.Error(context.getString(R.string.set_api_key_in_settings))
                    return@launch
                }
                triggerResponse(chatId, content)
            }
        }
    }

    fun deleteChat(chatId: String) {
        viewModelScope.launch {
            chatRepository.deleteChat(chatId)
        }
    }

    fun handleCommand(command: String, chatId: String) {
        viewModelScope.launch {
            when (command) {
                "/new" -> {
                    _commandEvent.emit(CommandEvent.NewChat)
                }
                "/clear" -> {
                    chatRepository.deleteChat(chatId)
                    _commandEvent.emit(CommandEvent.ChatCleared)
                }
                "/model" -> {
                    _commandEvent.emit(CommandEvent.OpenModelPicker)
                }
                "/settings" -> {
                    _commandEvent.emit(CommandEvent.OpenSettings)
                }
                "/copy" -> {
                    _commandEvent.emit(CommandEvent.CopyLastMessage)
                }
                "/export" -> {
                    _commandEvent.emit(CommandEvent.ExportChat)
                }
                "/help" -> {
                    _commandEvent.emit(CommandEvent.ShowHelp)
                }
            }
        }
    }
}

sealed class ChatUiState {
    object Idle : ChatUiState()
    data class Streaming(val content: String) : ChatUiState()
    data class Error(val message: String) : ChatUiState()
}

sealed class CommandEvent {
    object NewChat : CommandEvent()
    object ChatCleared : CommandEvent()
    object OpenModelPicker : CommandEvent()
    object OpenSettings : CommandEvent()
    object CopyLastMessage : CommandEvent()
    object ExportChat : CommandEvent()
    object ShowHelp : CommandEvent()
}
