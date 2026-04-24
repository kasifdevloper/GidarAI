package ai.gidar.app.ui

import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import ai.gidar.app.ui.home.HomeScreen
import ai.gidar.app.ui.sidebar.SidebarDrawer
import ai.gidar.app.ui.chat.ChatScreen
import ai.gidar.app.ui.settings.SettingsScreen
import ai.gidar.app.theme.GidarAITheme
import ai.gidar.app.ui.home.HomeViewModel
import kotlinx.coroutines.launch

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val homeViewModel: HomeViewModel = hiltViewModel()
    val appTheme by homeViewModel.appTheme.collectAsState()

    GidarAITheme(theme = appTheme) {
        ModalNavigationDrawer(
            drawerState = drawerState,
            drawerContent = {
                SidebarDrawer(
                    onChatClick = { chatId ->
                        navController.navigate(Screen.Chat.createRoute(chatId))
                        scope.launch { drawerState.close() }
                    },
                    onNewChatClick = {
                        navController.navigate(Screen.Home.route)
                        scope.launch { drawerState.close() }
                    },
                    onSettingsClick = {
                        navController.navigate(Screen.Settings.route)
                        scope.launch { drawerState.close() }
                    }
                )
            }
        ) {
            NavHost(navController = navController, startDestination = Screen.Home.route) {
                composable(Screen.Home.route) {
                    HomeScreen(
                        onOpenDrawer = { scope.launch { drawerState.open() } },
                        onChatCreated = { chatId ->
                            navController.navigate(Screen.Chat.createRoute(chatId))
                        }
                    )
                }
                composable(Screen.Chat.route) { backStackEntry ->
                    val chatId = backStackEntry.arguments?.getString("chatId") ?: return@composable
                    ChatScreen(
                        chatId = chatId,
                        onBack = { navController.popBackStack() },
                        onOpenDrawer = { scope.launch { drawerState.open() } }
                    )
                }
                composable(Screen.Settings.route) {
                    SettingsScreen(onBack = { navController.popBackStack() })
                }
            }
        }
    }
}
