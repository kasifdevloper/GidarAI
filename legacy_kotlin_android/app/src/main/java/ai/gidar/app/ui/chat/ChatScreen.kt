package ai.gidar.app.ui.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ai.gidar.app.R
import ai.gidar.app.data.local.MessageEntity
import ai.gidar.app.ui.components.InputBar
import ai.gidar.app.ui.components.MarkdownText
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    chatId: String,
    onBack: () -> Unit,
    onOpenDrawer: () -> Unit,
    onOpenSettings: () -> Unit = {},
    onNewChat: () -> Unit = {},
    viewModel: ChatViewModel = hiltViewModel()
) {
    val messages by viewModel.getMessages(chatId).collectAsState(initial = emptyList())
    val uiState by viewModel.uiState.collectAsState()
    val selectedModel by viewModel.selectedModelName.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val clipboardManager = LocalClipboardManager.current

    // Handle command events
    LaunchedEffect(Unit) {
        viewModel.commandEvent.collect { event ->
            when (event) {
                is CommandEvent.NewChat -> onNewChat()
                is CommandEvent.ChatCleared -> {
                    // Chat cleared, navigate back
                    onBack()
                }
                is CommandEvent.OpenModelPicker -> {
                    // TODO: Open model picker
                }
                is CommandEvent.OpenSettings -> onOpenSettings()
                is CommandEvent.CopyLastMessage -> {
                    val lastAssistantMessage = messages.lastOrNull { it.role == "assistant" }
                    lastAssistantMessage?.let {
                        clipboardManager.setText(AnnotatedString(it.content))
                    }
                }
                is CommandEvent.ExportChat -> {
                    // TODO: Export chat to PDF
                }
                is CommandEvent.ShowHelp -> {
                    // TODO: Show help dialog
                }
            }
        }
    }

    LaunchedEffect(messages) {
        if (messages.size == 1 && messages.first().role == "user" && uiState is ChatUiState.Idle) {
            viewModel.triggerInitialResponse(chatId, messages.first().content)
        }
        if (messages.isNotEmpty() || uiState is ChatUiState.Streaming) {
            listState.animateScrollToItem(if (uiState is ChatUiState.Streaming) messages.size else messages.size - 1)
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize().navigationBarsPadding(),
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(stringResource(R.string.chat), style = MaterialTheme.typography.titleMedium)
                        Text(selectedModel, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(Icons.Default.Menu, contentDescription = stringResource(R.string.menu))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .windowInsetsPadding(WindowInsets.ime)
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(messages) { message ->
                    if (message.role == "user") {
                        UserBubble(message.content)
                    } else {
                        AssistantBubble(message.content)
                    }
                }
                
                if (uiState is ChatUiState.Streaming) {
                    val streamingContent = (uiState as ChatUiState.Streaming).content
                    item {
                        AssistantBubble(content = streamingContent, isStreaming = true)
                    }
                } else if (uiState is ChatUiState.Idle && messages.isNotEmpty() && messages.last().role == "user") {
                    item {
                        TypingIndicator()
                    }
                }
                
                if (uiState is ChatUiState.Error) {
                    item {
                        Text(
                            stringResource(R.string.error, (uiState as ChatUiState.Error).message),
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.padding(8.dp)
                        )
                    }
                }
            }

            Surface(
                tonalElevation = 8.dp,
                shadowElevation = 8.dp,
                color = MaterialTheme.colorScheme.surface
            ) {
                InputBar(
                    onSend = { viewModel.sendMessage(chatId, it) },
                    onCommand = { viewModel.handleCommand(it, chatId) }
                )
            }
        }
    }
}

@Composable
fun TypingIndicator() {
    Row(
        modifier = Modifier.padding(horizontal = 48.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        repeat(3) { index ->
            val infiniteTransition = rememberInfiniteTransition(label = "typing")
            val dy by infiniteTransition.animateFloat(
                initialValue = 0f,
                targetValue = -10f,
                animationSpec = infiniteRepeatable(
                    animation = tween(600, delayMillis = index * 200),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "bounce"
            )
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .offset(y = dy.dp)
                    .background(MaterialTheme.colorScheme.primary, CircleShape)
            )
        }
    }
}

