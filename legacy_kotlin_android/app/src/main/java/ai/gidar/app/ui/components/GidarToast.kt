package ai.gidar.app.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
fun GidarToast(
    message: String,
    type: ToastType = ToastType.INFO,
    onDismiss: () -> Unit
) {
    var visible by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        delay(3000)
        visible = false
        onDismiss()
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn() + slideInVertically(initialOffsetY = { it }),
        exit = fadeOut() + slideOutVertically(targetOffsetY = { it })
    ) {
        Card(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = when (type) {
                    ToastType.INFO -> Color(0xFF1E88E5)
                    ToastType.SUCCESS -> Color(0xFF4CAF50)
                    ToastType.ERROR -> Color(0xFFE53935)
                    ToastType.WARNING -> Color(0xFFFFA000)
                }
            ),
            shape = MaterialTheme.shapes.medium
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = message,
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

enum class ToastType { INFO, SUCCESS, ERROR, WARNING }

// Toast manager to handle multiple toasts
class ToastManager {
    private val _toasts = mutableStateListOf<ToastData>()
    val toasts: List<ToastData> get() = _toasts

    fun show(message: String, type: ToastType = ToastType.INFO) {
        _toasts.add(ToastData(message, type))
    }

    fun dismiss(toast: ToastData) {
        _toasts.remove(toast)
    }
}

data class ToastData(
    val message: String,
    val type: ToastType,
    val id: Long = System.currentTimeMillis()
)

@Composable
fun ToastContainer(toastManager: ToastManager) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        toastManager.toasts.forEach { toast ->
            GidarToast(
                message = toast.message,
                type = toast.type,
                onDismiss = { toastManager.dismiss(toast) }
            )
        }
    }
}
