package ai.gidar.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import ai.gidar.app.R

@Database(entities = [ChatEntity::class, MessageEntity::class], version = 2, exportSchema = false)
abstract class ChatDatabase : RoomDatabase() {
    abstract fun chatDao(): ChatDao

    companion object {
        fun getDatabaseName(context: Context): String {
            return context.getString(R.string.database_name)
        }

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                // Create new table with indices
                database.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS messages_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        chatId TEXT NOT NULL,
                        role TEXT NOT NULL,
                        content TEXT NOT NULL,
                        timestamp INTEGER NOT NULL
                    )
                    """
                )
                
                // Copy data from old table
                database.execSQL(
                    """
                    INSERT INTO messages_new (id, chatId, role, content, timestamp)
                    SELECT id, chatId, role, content, timestamp FROM messages
                    """
                )
                
                // Drop old table
                database.execSQL("DROP TABLE messages")
                
                // Rename new table
                database.execSQL("ALTER TABLE messages_new RENAME TO messages")
                
                // Create indices
                database.execSQL("CREATE INDEX IF NOT EXISTS index_messages_chatId ON messages(chatId)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_messages_timestamp ON messages(timestamp)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_messages_chatId_timestamp ON messages(chatId, timestamp)")
            }
        }
    }
}
