package ai.gidar.app.data.repository

import android.content.Context
import ai.gidar.app.R
import ai.gidar.app.data.local.ChatDao
import ai.gidar.app.data.local.ChatEntity
import ai.gidar.app.data.local.MessageEntity
import ai.gidar.app.data.remote.ChatMessage
import ai.gidar.app.data.remote.ChatRequest
import ai.gidar.app.data.remote.ChatResponseChunk
import ai.gidar.app.data.remote.OpenRouterApi
import com.google.gson.Gson
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import okhttp3.ResponseBody
import java.io.BufferedReader
import java.io.InputStreamReader
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChatRepository @Inject constructor(
    private val api: OpenRouterApi,
    private val dao: ChatDao,
    private val settingsRepository: SettingsRepository,
    @ApplicationContext private val context: Context
) {
    private val gson = Gson()

    fun getAllChats(): Flow<List<ChatEntity>> = dao.getAllChats()

    fun getMessagesForChat(chatId: String): Flow<List<MessageEntity>> = dao.getMessagesForChat(chatId)

    suspend fun getMessagesForChatPaginated(chatId: String, page: Int, pageSize: Int = 50): List<MessageEntity> {
        val offset = page * pageSize
        return dao.getMessagesForChatPaginated(chatId, pageSize, offset)
    }

    suspend fun getMessageCountForChat(chatId: String): Int {
        return dao.getMessageCountForChat(chatId)
    }

    suspend fun searchMessages(chatId: String, query: String): List<MessageEntity> {
        return dao.searchMessages(chatId, query)
    }

    suspend fun createNewChat(firstMessage: String): String {
        val chatId = System.currentTimeMillis().toString()
        val title = if (firstMessage.length > 52) firstMessage.take(52) + "..." else firstMessage
        dao.insertChat(ChatEntity(chatId, title, System.currentTimeMillis()))
        saveMessage(chatId, "user", firstMessage)
        return chatId
    }

    suspend fun saveMessage(chatId: String, role: String, content: String) {
        dao.insertMessage(MessageEntity(chatId = chatId, role = role, content = content, timestamp = System.currentTimeMillis()))
    }

    fun sendMessageStream(chatId: String, userMessage: String, retryCount: Int = 3) = flow {
        val apiKey = settingsRepository.apiKey.first() ?: throw Exception(context.getString(R.string.api_key_missing))
        val model = settingsRepository.selectedModelId.first()
        val systemPrompt = settingsRepository.systemPrompt.first()

        // Prepare context (last 20 messages)
        val history = dao.getMessagesForChat(chatId).first().takeLast(20)
        val messages = mutableListOf<ChatMessage>()
        messages.add(ChatMessage("system", systemPrompt))
        history.forEach { messages.add(ChatMessage(it.role, it.content)) }

        android.util.Log.d("ChatRepository", "Sending request to OpenRouter. Model: $model, Key starts with: ${apiKey.take(10)}")

        val request = ChatRequest(model = model, messages = messages)
        
        // Retry logic with exponential backoff
        var lastException: Exception? = null
        for (attempt in 1..retryCount) {
            try {
                val response = api.chatCompletionsStream("Bearer $apiKey", request = request).execute()

                if (!response.isSuccessful) {
                    val errorCode = response.code()
                    val errorMessage = response.message()
                    android.util.Log.e("ChatRepository", "Response failed: $errorCode $errorMessage")
                    
                    // Don't retry on client errors (4xx)
                    if (errorCode in 400..499) {
                        throw Exception(context.getString(R.string.api_error, "$errorCode $errorMessage"))
                    }
                    
                    // Retry on server errors (5xx)
                    if (errorCode in 500..599) {
                        lastException = Exception(context.getString(R.string.server_error, "$errorCode $errorMessage"))
                        if (attempt < retryCount) {
                            delay(1000L * attempt) // Exponential backoff
                            continue
                        }
                    }
                    
                    throw Exception(context.getString(R.string.api_error, "$errorCode $errorMessage"))
                }

                val reader = BufferedReader(InputStreamReader(response.body()?.byteStream()))
                var assistantContent = ""

                try {
                    var line: String? = reader.readLine()
                    while (line != null) {
                        if (line.trim().startsWith("data: ")) {
                            val data = line.trim().substring(6)
                            if (data == "[DONE]") break
                            
                            try {
                                val chunk = gson.fromJson(data, ChatResponseChunk::class.java)
                                chunk.choices.firstOrNull()?.delta?.content?.let {
                                    assistantContent += it
                                    emit(assistantContent)
                                }
                            } catch (e: Exception) {
                                android.util.Log.e("ChatRepository", "JSON Parse error: $data", e)
                            }
                        }
                        line = reader.readLine()
                    }
                } finally {
                    reader.close()
                }
                
                if (assistantContent.isNotBlank()) {
                    saveMessage(chatId, "assistant", assistantContent)
                }
                return@flow // Success, exit retry loop
            } catch (e: Exception) {
                lastException = e
                android.util.Log.e("ChatRepository", "Attempt $attempt failed: ${e.message}", e)
                if (attempt < retryCount) {
                    delay(1000L * attempt) // Exponential backoff
                }
            }
        }
        
        // All retries failed
        throw lastException ?: Exception(context.getString(R.string.network_error))
    }.flowOn(Dispatchers.IO)

    suspend fun deleteChat(chatId: String) = dao.deleteChatWithMessages(chatId)
    
    suspend fun clearAll() {
        dao.deleteAllChats()
        dao.deleteAllMessages()
    }
}
