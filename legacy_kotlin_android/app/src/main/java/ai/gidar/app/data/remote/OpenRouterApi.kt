package ai.gidar.app.data.remote

import android.content.Context
import ai.gidar.app.R
import com.google.gson.annotations.SerializedName
import dagger.hilt.android.qualifiers.ApplicationContext
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Streaming
import okhttp3.ResponseBody
import retrofit2.Call

interface OpenRouterApi {
    @Streaming
    @POST("chat/completions")
    fun chatCompletionsStream(
        @Header("Authorization") apiKey: String,
        @Header("HTTP-Referer") referer: String = context.getString(R.string.http_referer),
        @Header("X-Title") title: String = context.getString(R.string.x_title),
        @Body request: ChatRequest
    ): Call<ResponseBody>
}

data class ChatRequest(
    val model: String,
    val messages: List<ChatMessage>,
    val stream: Boolean = true,
    val route: String = "fallback"
)

data class ChatMessage(
    val role: String,
    val content: Any // Can be String or List<MessageContent> for Vision
)

data class MessageContent(
    val type: String,
    val text: String? = null,
    @SerializedName("image_url") val imageUrl: ImageUrl? = null
)

data class ImageUrl(
    val url: String,
    val detail: String = "high"
)

data class ChatResponseChunk(
    val choices: List<ChoiceChunk>
)

data class ChoiceChunk(
    val delta: DeltaChunk,
    @SerializedName("finish_reason") val finishReason: String?
)

data class DeltaChunk(
    val content: String?
)
