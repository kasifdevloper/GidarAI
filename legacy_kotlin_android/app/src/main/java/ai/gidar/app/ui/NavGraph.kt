package ai.gidar.app.ui

sealed class Screen(val route: String) {
    object Home : Screen("home")
    object Chat : Screen("chat/{chatId}") {
        fun createRoute(chatId: String) = "chat/$chatId"
    }
    object Settings : Screen("settings")
}
