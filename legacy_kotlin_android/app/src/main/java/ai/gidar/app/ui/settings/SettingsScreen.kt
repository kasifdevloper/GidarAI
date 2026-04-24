package ai.gidar.app.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.selection.selectable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import ai.gidar.app.R
import ai.gidar.app.theme.GidarTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val apiKey by viewModel.apiKey.collectAsState()
    val systemPrompt by viewModel.systemPrompt.collectAsState()
    val appTheme by viewModel.appTheme.collectAsState()

    var apiKeyInput by remember { mutableStateOf(apiKey ?: "") }
    var showApiKey by remember { mutableStateOf(false) }
    var systemPromptInput by remember { mutableStateOf(systemPrompt) }

    LaunchedEffect(apiKey) { apiKey?.let { apiKeyInput = it } }
    LaunchedEffect(systemPrompt) { systemPromptInput = systemPrompt }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(stringResource(R.string.settings), style = MaterialTheme.typography.titleLarge)
                        Text(stringResource(R.string.manage_your_workspace_configuration), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        },
        bottomBar = {
            SettingsBottomBar(onBack)
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // ACCOUNT
            item {
                SettingsSectionHeader(stringResource(R.string.account))
                SettingsCard {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.api_key), style = MaterialTheme.typography.labelLarge)
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(
                            value = apiKeyInput,
                            onValueChange = { apiKeyInput = it },
                            modifier = Modifier.fillMaxWidth().background(Color(0xFF1A1A1A), RoundedCornerShape(12.dp)),
                            visualTransformation = if (showApiKey) VisualTransformation.None else PasswordVisualTransformation(),
                            trailingIcon = {
                                IconButton(onClick = { showApiKey = !showApiKey }) {
                                    Icon(if (showApiKey) Icons.Default.VisibilityOff else Icons.Default.Visibility, null, tint = Color.Gray)
                                }
                            },
                            shape = RoundedCornerShape(12.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = Color(0xFF333333),
                                unfocusedBorderColor = Color(0xFF333333)
                            )
                        )
                        Text(
                            stringResource(R.string.api_key_description),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.Gray,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                }
            }

            // MODEL
            item {
                SettingsSectionHeader(stringResource(R.string.model))
                SettingsCard {
                    Row(
                        modifier = Modifier.padding(16.dp).fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier.size(40.dp).background(Color(0xFF262626), RoundedCornerShape(8.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.FlashOn, null, tint = Color.LightGray)
                        }
                        Spacer(Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(stringResource(R.string.gpt_4o_mini), style = MaterialTheme.typography.titleMedium)
                            Text(stringResource(R.string.active), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                        }
                        Icon(Icons.Default.CheckCircle, null, tint = MaterialTheme.colorScheme.primary)
                    }
                }
                Spacer(Modifier.height(12.dp))
                OutlinedButton(
                    onClick = { /* Add Model */ },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF262626))
                ) {
                    Icon(Icons.Default.Add, null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.add_model))
                }
            }

            // SYSTEM PROMPT
            item {
                SettingsSectionHeader(stringResource(R.string.system_prompt))
                SettingsCard {
                    OutlinedTextField(
                        value = systemPromptInput,
                        onValueChange = { systemPromptInput = it },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Color.Transparent,
                            unfocusedBorderColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            focusedContainerColor = Color.Transparent
                        )
                    )
                }
                Text(
                    stringResource(R.string.auto_saved_2m_ago),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.End
                )
            }

            // APPEARANCE
            item {
                SettingsSectionHeader(stringResource(R.string.appearance))
                SettingsCard {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.accent_color), style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.height(16.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            val themeMapping = listOf(
                                Color.Black to GidarTheme.ORIGINAL,
                                Color(0xFFB3C7FF) to GidarTheme.DEEP_OCEAN,
                                Color(0xFF81C784) to GidarTheme.MIDNIGHT_FOREST,
                                Color(0xFFFBC02D) to GidarTheme.SUNSET_GLOW,
                                Color(0xFFCE93D8) to GidarTheme.LAVENDER_MIST,
                                Color(0xFF4DB6AC) to GidarTheme.NEON_CYBERPUNK
                            )
                            themeMapping.forEach { (color, theme) ->
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .clip(CircleShape)
                                        .background(if (color == Color.Black) Color(0xFF7EB1FF) else color)
                                        .border(if (theme == appTheme) 2.dp else 0.dp, Color.White, CircleShape)
                                        .clickable { viewModel.saveTheme(theme) }
                                )
                            }
                        }
                    }
                }
            }

            // CHAT MANAGEMENT
            item {
                SettingsSectionHeader(stringResource(R.string.chat_management))
                SettingsCard {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.clear_all_chats_description), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                        Spacer(Modifier.height(16.dp))
                        Button(
                            onClick = { viewModel.clearAllChats() },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A1010)),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Delete, null, tint = Color(0xFFEF9A9A), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.clear_all_chats), color = Color(0xFFEF9A9A))
                        }
                    }
                }
            }

            // DATA PRIVACY
            item {
                SettingsSectionHeader(stringResource(R.string.data_privacy))
                SettingsCard {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.clear_all_data_description), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                        Spacer(Modifier.height(16.dp))
                        Button(
                            onClick = { viewModel.clearAllData() },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A1010)),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.ErrorOutline, null, tint = Color(0xFFEF9A9A), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.clear_all_data), color = Color(0xFFEF9A9A))
                        }
                    }
                }
            }
            
            item {
                Button(
                    onClick = {
                        viewModel.saveApiKey(apiKeyInput)
                        viewModel.saveSystemPrompt(systemPromptInput)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(stringResource(R.string.save_changes))
                }
                Spacer(Modifier.height(80.dp))
            }
        }
    }
}

@Composable
fun SettingsSectionHeader(text: String) {
    Text(
        text, 
        style = MaterialTheme.typography.labelSmall, 
        color = Color(0xFF7EB1FF),
        modifier = Modifier.padding(bottom = 8.dp)
    )
}

@Composable
fun SettingsCard(content: @Composable () -> Unit) {
    Surface(
        color = Color(0xFF121212),
        shape = RoundedCornerShape(12.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF262626)),
        modifier = Modifier.fillMaxWidth()
    ) {
        content()
    }
}

@Composable
fun SettingsBottomBar(onHome: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Surface(
            color = Color(0xFF1A1A1A),
            shape = RoundedCornerShape(32.dp),
            modifier = Modifier.width(240.dp).height(64.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxSize(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onHome) {
                    Icon(Icons.Default.History, null, tint = Color.Gray)
                }
                Box(
                    modifier = Modifier.size(48.dp).clip(CircleShape).background(Color(0xFF7EB1FF)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Add, null, tint = Color.White)
                }
                IconButton(onClick = { /* Stay here */ }) {
                    Icon(Icons.Default.Settings, null, tint = Color.White)
                }
            }
        }
    }
}
