package ai.gidar.app.ui.home

import ai.gidar.app.data.repository.ChatRepository
import ai.gidar.app.data.repository.SettingsRepository
import ai.gidar.app.theme.GidarTheme
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
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    private lateinit var viewModel: HomeViewModel
    private lateinit var chatRepository: ChatRepository
    private lateinit var settingsRepository: SettingsRepository
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        chatRepository = mock()
        settingsRepository = mock()
        viewModel = HomeViewModel(chatRepository, settingsRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `hasApiKey returns true when API key is set`() = runTest {
        whenever(settingsRepository.apiKey).thenReturn(flowOf("test_api_key"))
        
        val result = viewModel.hasApiKey
        result.collect { hasKey ->
            assertTrue(hasKey)
        }
    }

    @Test
    fun `hasApiKey returns false when API key is null`() = runTest {
        whenever(settingsRepository.apiKey).thenReturn(flowOf(null))
        
        val result = viewModel.hasApiKey
        result.collect { hasKey ->
            assertFalse(hasKey)
        }
    }

    @Test
    fun `hasApiKey returns false when API key is blank`() = runTest {
        whenever(settingsRepository.apiKey).thenReturn(flowOf(""))
        
        val result = viewModel.hasApiKey
        result.collect { hasKey ->
            assertFalse(hasKey)
        }
    }

    @Test
    fun `selectedModelName returns default model name`() = runTest {
        whenever(settingsRepository.selectedModelName).thenReturn(flowOf("GPT-4o Mini"))
        
        val result = viewModel.selectedModelName
        result.collect { modelName ->
            assertEquals("GPT-4o Mini", modelName)
        }
    }

    @Test
    fun `appTheme returns default theme`() = runTest {
        whenever(settingsRepository.appTheme).thenReturn(flowOf(GidarTheme.ORIGINAL))
        
        val result = viewModel.appTheme
        result.collect { theme ->
            assertEquals(GidarTheme.ORIGINAL, theme)
        }
    }

    @Test
    fun `startChat creates new chat and invokes callback`() = runTest {
        val chatId = "test_chat_id"
        whenever(chatRepository.createNewChat("Hello")).thenReturn(chatId)
        
        var callbackInvoked = false
        var receivedChatId: String? = null
        
        viewModel.startChat("Hello") { id ->
            callbackInvoked = true
            receivedChatId = id
        }
        
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(callbackInvoked)
        assertEquals(chatId, receivedChatId)
    }

    @Test
    fun `saveModel saves selected model`() = runTest {
        var savedId: String? = null
        var savedName: String? = null
        
        whenever(settingsRepository.saveSelectedModel("openai/gpt-4o", "GPT-4o")).thenAnswer {
            savedId = "openai/gpt-4o"
            savedName = "GPT-4o"
        }
        
        viewModel.saveModel("openai/gpt-4o", "GPT-4o")
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals("openai/gpt-4o", savedId)
        assertEquals("GPT-4o", savedName)
    }
}
