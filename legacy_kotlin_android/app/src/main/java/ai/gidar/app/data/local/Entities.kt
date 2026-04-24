package ai.gidar.app.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "chats")
data class ChatEntity(
    @PrimaryKey val id: String,  // timestamp string
    val title: String,           // first message ka first 52 chars
    val timestamp: Long
)

@Entity(
    tableName = "messages",
    indices = [
        Index(value = ["chatId"]),
        Index(value = ["timestamp"]),
        Index(value = ["chatId", "timestamp"])
    ]
)
data class MessageEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val chatId: String,
    val role: String,            // "user" | "assistant" | "system"
    val content: String,         // plain text ya JSON for vision
    val timestamp: Long
)
