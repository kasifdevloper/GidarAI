package ai.gidar.app.ui.sidebar

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ai.gidar.app.R
import ai.gidar.app.data.local.ChatEntity
import androidx.hilt.navigation.compose.hiltViewModel
import ai.gidar.app.ui.chat.ChatViewModel
import java.util.*

@Composable
fun SidebarDrawer(
    onChatClick: (String) -> Unit,
    onNewChatClick: () -> Unit,
    onSettingsClick: () -> Unit,
    viewModel: ChatViewModel = hiltViewModel()
) {
    val chats by viewModel.allChats.collectAsState(initial = emptyList())
    val categorizedChats = remember(chats) { groupChatsByDate(chats) }

    ModalDrawerSheet(
        drawerContainerColor = Color(0xFF090909),
        drawerContentColor = Color.White
    ) {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            // Profile Header
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xFF7EB1FF)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.FlashOn, null, tint = Color.Black)
                }
                Spacer(Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(stringResource(R.string.premium_user), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.gidar_ai_pro), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                }
                Icon(
                    Icons.Default.AccountCircle,
                    contentDescription = stringResource(R.string.profile),
                    modifier = Modifier.size(32.dp),
                    tint = Color.Gray
                )
            }

            Spacer(Modifier.height(16.dp))

            // New Chat Button
            Button(
                onClick = onNewChatClick,
                modifier = Modifier.fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF7EB1FF))
            ) {
                Icon(Icons.Default.Add, null, tint = Color.Black)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.new_chat), color = Color.Black, fontWeight = FontWeight.Bold)
            }

            Spacer(Modifier.height(32.dp))

            // History Sections
            LazyColumn(modifier = Modifier.weight(1f)) {
                if (categorizedChats.today.isNotEmpty()) {
                    item { SidebarSectionHeader(stringResource(R.string.today)) }
                    items(categorizedChats.today) { chat ->
                        SidebarChatItem(chat.title) { onChatClick(chat.id) }
                    }
                    item { Spacer(Modifier.height(16.dp)) }
                }

                if (categorizedChats.yesterday.isNotEmpty()) {
                    item { SidebarSectionHeader(stringResource(R.string.yesterday)) }
                    items(categorizedChats.yesterday) { chat ->
                        SidebarChatItem(chat.title) { onChatClick(chat.id) }
                    }
                    item { Spacer(Modifier.height(16.dp)) }
                }

                if (categorizedChats.last30Days.isNotEmpty()) {
                    item { SidebarSectionHeader(stringResource(R.string.last_30_days)) }
                    items(categorizedChats.last30Days) { chat ->
                        SidebarChatItem(chat.title) { onChatClick(chat.id) }
                    }
                    item { Spacer(Modifier.height(16.dp)) }
                }

                if (categorizedChats.older.isNotEmpty()) {
                    item { SidebarSectionHeader(stringResource(R.string.older)) }
                    items(categorizedChats.older) { chat ->
                        SidebarChatItem(chat.title) { onChatClick(chat.id) }
                    }
                    item { Spacer(Modifier.height(16.dp)) }
                }
                
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp).clickable { },
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Archive, null, tint = Color.Gray, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(16.dp))
                        Text(stringResource(R.string.archived_conversations), style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
                    }
                }
            }

            // Bottom Actions
            HorizontalDivider(color = Color(0xFF1A1A1A))
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp).clickable { onSettingsClick() },
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Default.Settings, null, tint = Color.White)
                Spacer(Modifier.width(16.dp))
                Text(stringResource(R.string.settings), style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.weight(1f))
                Text(stringResource(R.string.version), style = MaterialTheme.typography.labelSmall, color = Color.DarkGray)
            }
        }
    }
}

private data class CategorizedChats(
    val today: List<ChatEntity> = emptyList(),
    val yesterday: List<ChatEntity> = emptyList(),
    val last30Days: List<ChatEntity> = emptyList(),
    val older: List<ChatEntity> = emptyList()
)

private fun groupChatsByDate(chats: List<ChatEntity>): CategorizedChats {
    val today = mutableListOf<ChatEntity>()
    val yesterday = mutableListOf<ChatEntity>()
    val last30Days = mutableListOf<ChatEntity>()
    val older = mutableListOf<ChatEntity>()

    val now = Calendar.getInstance().timeInMillis
    val todayMidnight = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    val yesterdayMidnight = todayMidnight - DateUtils.DAY_IN_MILLIS
    val thirtyDaysAgo = todayMidnight - (30 * DateUtils.DAY_IN_MILLIS)

    chats.forEach { chat ->
        when {
            chat.timestamp >= todayMidnight -> today.add(chat)
            chat.timestamp >= yesterdayMidnight -> yesterday.add(chat)
            chat.timestamp >= thirtyDaysAgo -> last30Days.add(chat)
            else -> older.add(chat)
        }
    }

    return CategorizedChats(today, yesterday, last30Days, older)
}

@Composable
fun SidebarSectionHeader(text: String) {
    Text(
        text, 
        style = MaterialTheme.typography.labelSmall, 
        color = Color.DarkGray,
        modifier = Modifier.padding(bottom = 8.dp)
    )
}

@Composable
fun SidebarChatItem(title: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(vertical = 12.dp, horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Default.ChatBubbleOutline, null, tint = Color.Gray, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(16.dp))
        Text(title, style = MaterialTheme.typography.bodyMedium, color = Color.LightGray, maxLines = 1)
    }
}
