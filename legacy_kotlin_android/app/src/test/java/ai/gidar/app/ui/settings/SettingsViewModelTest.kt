package ai.gidar.app.ui.settings

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

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private lateinit var viewModel: SettingsViewModel
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var chatRepository: ChatRepository
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        settingsRepository = mock()
        chatRepository = mock()
        viewModel = SettingsViewModel(settingsRepository, chatRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `apiKey returns stored API key`() = runTest {
        whenever(settingsRepository.apiKey).thenReturn(flowOf("test_api_key"))
        
        val result = viewModel.apiKey
        result.collect { apiKey ->
            assertEquals("test_api_key", apiKey)
        }
    }

    @Test
    fun `selectedModelId returns default model`() = runTest {
        whenever(settingsRepository.selectedModelId).thenReturn(flowOf("openai/gpt-4o-mini"))
        
        val result = viewModel.selectedModelId
        result.collect { modelId ->
            assertEquals("openai/gpt-4o-mini", modelId)
        }
    }

    @Test
    fun `systemPrompt returns default prompt`() = runTest {
        whenever(settingsRepository.systemPrompt).thenReturn(flowOf("You are Gidar AI"))
        
        val result = viewModel.systemPrompt
        result.collect { prompt ->
            assertEquals("You are Gidar AI", prompt)
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
    fun `saveApiKey saves API key`() = runTest {
        var savedKey: String? = null
        whenever(settingsRepository.saveApiKey("new_api_key")).thenAnswer {
            savedKey = "new_api_key"
        }
        
        viewModel.saveApiKey("new_api_key")
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals("new_api_key", savedKey)
    }

    @Test
    fun `saveSystemPrompt saves system prompt`() = runTest {
        var savedPrompt: String? = null
        whenever(settingsRepository.saveSystemPrompt("New prompt")).thenAnswer {
            savedPrompt = "New prompt"
        }
        
        viewModel.saveSystemPrompt("New prompt")
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals("New prompt", savedPrompt)
    }

    @Test
    fun `saveTheme saves app theme`() = runTest {
        var savedTheme: GidarTheme? = null
        whenever(settingsRepository.saveAppTheme(GidarTheme.DEEP_OCEAN)).thenAnswer {
            savedTheme = GidarTheme.DEEP_OCEAN
        }
        
        viewModel.saveTheme(GidarTheme.DEEP_OCEAN)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals(GidarTheme.DEEP_OCEAN, savedTheme)
    }

    @Test
    fun `clearAllChats clears all chats`() = runTest {
        var chatsCleared = false
        whenever(chatRepository.clearAll()).thenAnswer {
            chatsCleared = true
        }
        
        viewModel.clearAllChats()
        testDispatcher.scheduler.advanceUntilIdle()
        
        assert(chatsCleared)
    }

    @Test
    fun `clearAllData clears all data`() = runTest {
        var dataCleared = false
        whenever(settingsRepository.clearAllData()).thenAnswer {
            dataCleared = true
        }
        whenever(chatRepository.clearAll()).thenAnswer { }
        
        viewModel.clearAllData()
        testDispatcher.scheduler.advanceUntilIdle()
        
        assert(dataCleared)
    }
}
