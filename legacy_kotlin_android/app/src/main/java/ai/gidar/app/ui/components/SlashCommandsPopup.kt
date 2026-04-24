package ai.gidar.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import ai.gidar.app.R

@Composable
fun SlashCommandsPopup(
    onCommandClick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val commands = listOf(
        stringResource(R.string.new_chat_command) to stringResource(R.string.new_chat_command_description),
        stringResource(R.string.clear_command) to stringResource(R.string.clear_command_description),
        stringResource(R.string.model_command) to stringResource(R.string.model_command_description),
        stringResource(R.string.settings_command) to stringResource(R.string.settings_command_description),
        stringResource(R.string.copy_command) to stringResource(R.string.copy_command_description),
        stringResource(R.string.export_command) to stringResource(R.string.export_command_description),
        stringResource(R.string.help_command) to stringResource(R.string.help_command_description)
    )

    Popup(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.padding(bottom = 60.dp, start = 16.dp, end = 16.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            LazyColumn(modifier = Modifier.width(200.dp)) {
                items(commands) { (cmd, desc) ->
                    ListItem(
                        headlineContent = { Text(cmd) },
                        supportingContent = { Text(desc) },
                        modifier = Modifier.clickable { onCommandClick(cmd) }
                    )
                }
            }
        }
    }
}
