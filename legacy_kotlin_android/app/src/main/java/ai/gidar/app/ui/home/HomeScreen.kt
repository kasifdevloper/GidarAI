package ai.gidar.app.ui.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ai.gidar.app.R
import ai.gidar.app.ui.components.InputBar
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenDrawer: () -> Unit,
    onChatCreated: (String) -> Unit,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val selectedModel by viewModel.selectedModelName.collectAsState()
    val hasApiKey by viewModel.hasApiKey.collectAsState()
    
    val sheetState = rememberModalBottomSheetState()
    var showModelSheet by remember { mutableStateOf(false) }

    val suggestions = listOf(
        SuggestionItem(
            stringResource(R.string.explain_quantum_computing),
            stringResource(R.string.simplified_for_a_beginner),
            Icons.Default.AutoAwesome
        ),
        SuggestionItem(
            stringResource(R.string.write_a_python_script),
            stringResource(R.string.automation_and_data_parsing),
            Icons.Default.Terminal
        ),
        SuggestionItem(
            stringResource(R.string.plan_a_trip_to_goa),
            stringResource(R.string.beaches_and_hidden_gems),
            Icons.Default.Map
        ),
        SuggestionItem(
            stringResource(R.string.summarize_this_text),
            stringResource(R.string.extract_key_bullet_points),
            Icons.Default.Description
        )
    )

    val models = listOf(
        stringResource(R.string.gpt_4o_mini) to stringResource(R.string.gpt_4o_mini_id),
        stringResource(R.string.gpt_4o) to stringResource(R.string.gpt_4o_id),
        stringResource(R.string.claude_3_opus) to stringResource(R.string.claude_3_opus_id),
        stringResource(R.string.claude_3_5_sonnet) to stringResource(R.string.claude_3_5_sonnet_id),
        stringResource(R.string.llama_3_70b) to stringResource(R.string.llama_3_70b_id)
    )

    if (showModelSheet) {
        ModalBottomSheet(
            onDismissRequest = { showModelSheet = false },
            sheetState = sheetState,
            containerColor = Color(0xFF121212),
            contentColor = Color.White
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxWidth().padding(bottom = 32.dp),
                contentPadding = PaddingValues(16.dp)
            ) {
                item {
                    Text(
                        stringResource(R.string.select_ai_model),
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                }
                items(models) { (name, id) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { 
                                viewModel.saveModel(id, name)
                                showModelSheet = false 
                            }
                            .padding(vertical = 16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier.size(40.dp).background(Color(0xFF262626), RoundedCornerShape(8.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.FlashOn, null, tint = if (name == selectedModel) Color(0xFF7EB1FF) else Color.Gray)
                        }
                        Spacer(Modifier.width(16.dp))
                        Text(
                            name, 
                            style = MaterialTheme.typography.bodyLarge,
                            color = if (name == selectedModel) Color(0xFF7EB1FF) else Color.White,
                            fontWeight = if (name == selectedModel) FontWeight.Bold else FontWeight.Normal
                        )
                        Spacer(Modifier.weight(1f))
                        if (name == selectedModel) {
                            Icon(Icons.Default.Check, null, tint = Color(0xFF7EB1FF))
                        }
                    }
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color(0xFF1A1A1A))
                            .clickable { showModelSheet = true }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(selectedModel, style = MaterialTheme.typography.bodyMedium)
                            Icon(Icons.Default.KeyboardArrowDown, null, modifier = Modifier.size(16.dp))
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(Icons.Default.Menu, contentDescription = stringResource(R.string.menu))
                    }
                },
                actions = {
                    IconButton(onClick = { /* Profile */ }) {
                        Icon(Icons.Default.AccountCircle, contentDescription = stringResource(R.string.profile), modifier = Modifier.size(32.dp))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(48.dp))

            // Gidar AI Logo
            GidarLogo()

            Spacer(Modifier.height(16.dp))
            Text(stringResource(R.string.gidar_ai), style = MaterialTheme.typography.displayLarge)
            
            Spacer(Modifier.height(48.dp))

            suggestions.forEach { suggestion ->
                SuggestionCard(suggestion) {
                    viewModel.startChat(suggestion.title, onChatCreated)
                }
                Spacer(Modifier.height(12.dp))
            }

            Spacer(Modifier.weight(1f))

            InputBar(onSend = { viewModel.startChat(it, onChatCreated) })
            
            Text(
                stringResource(R.string.powered_by_gidar_ai_pro),
                style = MaterialTheme.typography.labelSmall,
                color = Color.DarkGray,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }
    }
}

@Composable
fun GidarLogo() {
    Box(
        modifier = Modifier
            .size(80.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Color(0xFF0D1B1E))
            .border(2.dp, Color(0xFF1E88E5), RoundedCornerShape(20.dp)),
        contentAlignment = Alignment.Center
    ) {
        Text("G", color = Color(0xFF1E88E5), style = MaterialTheme.typography.displayLarge)
    }
}

data class SuggestionItem(val title: String, val subtitle: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

@Composable
fun SuggestionCard(item: SuggestionItem, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFF121212),
        shape = RoundedCornerShape(16.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF262626))
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                item.icon, 
                contentDescription = null, 
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(24.dp)
            )
            Spacer(Modifier.width(16.dp))
            Column {
                Text(item.title, style = MaterialTheme.typography.titleMedium, color = Color.White)
                Text(item.subtitle, style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
            }
        }
    }
}
