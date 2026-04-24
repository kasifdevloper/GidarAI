package ai.gidar.app.ui.chat

import ai.gidar.app.data.local.ChatEntity
import ai.gidar.app.data.local.MessageEntity
import ai.gidar.app.data.repository.ChatRepository
import ai.gidar.app.data.repository.SettingsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import kotlinx.coroutines.launch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {

    private lateinit var viewModel: ChatViewModel
    private lateinit var chatRepository: ChatRepository
    private lateinit var settingsRepository: SettingsRepository
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        chatRepository = mock()
        settingsRepository = mock()
        viewModel = ChatViewModel(chatRepository, settingsRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `getMessages returns flow of messages`() = runTest {
        val chatId = "test_chat_id"
        val messages = listOf(
            MessageEntity(1, chatId, "user", "Hello", System.currentTimeMillis()),
            MessageEntity(2, chatId, "assistant", "Hi there!", System.currentTimeMillis())
        )
        whenever(chatRepository.getMessagesForChat(chatId)).thenReturn(flowOf(messages))

        val result = viewModel.getMessages(chatId)
        result.collect { collectedMessages ->
            assertEquals(messages, collectedMessages)
        }
    }

    @Test
    fun `allChats returns flow of chats`() = runTest {
        val chats = listOf(
            ChatEntity("1", "Chat 1", System.currentTimeMillis()),
            ChatEntity("2", "Chat 2", System.currentTimeMillis())
        )
        whenever(chatRepository.getAllChats()).thenReturn(flowOf(chats))

        val result = viewModel.allChats
        result.collect { collectedChats ->
            assertEquals(chats, collectedChats)
        }
    }

    @Test
    fun `sendMessage shows error when API key is missing`() = runTest {
        whenever(settingsRepository.apiKey).thenReturn(flowOf(null))
        
        viewModel.sendMessage("test_chat_id", "Hello")
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.uiState.value is ChatUiState.Error)
    }

    @Test
    fun `handleCommand emits NewChat event`() = runTest {
        val events = mutableListOf<CommandEvent>()
        val job = launch {
            viewModel.commandEvent.collect { events.add(it) }
        }

        viewModel.handleCommand("/new", "test_chat_id")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(events.contains(CommandEvent.NewChat))
        job.cancel()
    }

    @Test
    fun `handleCommand emits ChatCleared event`() = runTest {
        val events = mutableListOf<CommandEvent>()
        val job = launch {
            viewModel.commandEvent.collect { events.add(it) }
        }

        viewModel.handleCommand("/clear", "test_chat_id")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(events.contains(CommandEvent.ChatCleared))
        job.cancel()
    }

    @Test
    fun `handleCommand emits OpenSettings event`() = runTest {
        val events = mutableListOf<CommandEvent>()
        val job = launch {
            viewModel.commandEvent.collect { events.add(it) }
        }

        viewModel.handleCommand("/settings", "test_chat_id")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(events.contains(CommandEvent.OpenSettings))
        job.cancel()
    }

    @Test
    fun `handleCommand emits CopyLastMessage event`() = runTest {
        val events = mutableListOf<CommandEvent>()
        val job = launch {
            viewModel.commandEvent.collect { events.add(it) }
        }

        viewModel.handleCommand("/copy", "test_chat_id")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(events.contains(CommandEvent.CopyLastMessage))
        job.cancel()
    }

    @Test
    fun `handleCommand emits ExportChat event`() = runTest {
        val events = mutableListOf<CommandEvent>()
        val job = launch {
            viewModel.commandEvent.collect { events.add(it) }
        }

        viewModel.handleCommand("/export", "test_chat_id")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(events.contains(CommandEvent.ExportChat))
        job.cancel()
    }

    @Test
    fun `handleCommand emits ShowHelp event`() = runTest {
        val events = mutableListOf<CommandEvent>()
        val job = launch {
            viewModel.commandEvent.collect { events.add(it) }
        }

        viewModel.handleCommand("/help", "test_chat_id")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(events.contains(CommandEvent.ShowHelp))
        job.cancel()
    }
}
