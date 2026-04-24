package ai.gidar.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ai.gidar.app.R

@Composable
fun InputBar(
    onSend: (String) -> Unit,
    onAttach: () -> Unit = {},
    onCommands: () -> Unit = {},
    onCommand: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    var text by remember { mutableStateOf("") }
    var showCommands by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        // Show slash commands popup when text starts with /
        if (showCommands && text.startsWith("/")) {
            SlashCommandsPopup(
                onCommandClick = { command ->
                    onCommand(command)
                    text = ""
                    showCommands = false
                },
                onDismiss = { showCommands = false }
            )
        }

        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(12.dp, RoundedCornerShape(28.dp)),
            shape = RoundedCornerShape(28.dp),
            color = Color(0xFF1C1C1E),
            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF3A3A3C))
        ) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Attach button with a subtle ring
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF2C2C2E)),
                    contentAlignment = Alignment.Center
                ) {
                    IconButton(onClick = onAttach) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = stringResource(R.string.attach),
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
                
                Spacer(Modifier.width(8.dp))

                TextField(
                    value = text,
                    onValueChange = { newText ->
                        text = newText
                        showCommands = newText.startsWith("/")
                    },
                    modifier = Modifier.weight(1f),
                    placeholder = {
                        Text(
                            stringResource(R.string.message_gidar_ai),
                            style = MaterialTheme.typography.bodyLarge,
                            color = Color.Gray
                        )
                    },
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        disabledContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        cursorColor = Color(0xFF7EB1FF),
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    ),
                    maxLines = 5,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default)
                )

                if (text.isEmpty()) {
                    IconButton(onClick = onCommands) {
                        Icon(
                            Icons.Default.AutoAwesome,
                            contentDescription = stringResource(R.string.ai_action),
                            tint = Color(0xFF7EB1FF),
                            modifier = Modifier.size(22.dp)
                        )
                    }
                }

                Spacer(Modifier.width(4.dp))

                // Premium Send Button
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            if (text.isNotBlank())
                                Brush.linearGradient(listOf(Color(0xFF007AFF), Color(0xFF00C6FF)))
                            else
                                Brush.linearGradient(listOf(Color(0xFF3A3A3C), Color(0xFF3A3A3C)))
                        )
                        .clickable(enabled = text.isNotBlank()) {
                            if (text.isNotBlank()) {
                                onSend(text)
                                text = ""
                                showCommands = false
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Send,
                        contentDescription = stringResource(R.string.send),
                        tint = if (text.isNotBlank()) Color.White else Color.Gray,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}
