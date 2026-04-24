package ai.gidar.app.ui.components

import android.content.Context
import android.content.Intent
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import ai.gidar.app.R
import java.io.File
import java.io.FileOutputStream

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HtmlPreviewSheet(
    html: String,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.fillMaxHeight(0.8f).padding(16.dp)) {
            Text(stringResource(R.string.html_preview), style = MaterialTheme.typography.titleLarge)
            Spacer(Modifier.height(12.dp))
            AndroidView(
                factory = { context ->
                    WebView(context).apply {
                        webViewClient = WebViewClient()
                        settings.javaScriptEnabled = true
                    }
                },
                update = { webView ->
                    webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
                },
                modifier = Modifier.fillMaxSize().weight(1f)
            )
            Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Button(onClick = {
                    // Share HTML
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/html"
                        putExtra(Intent.EXTRA_TEXT, html)
                        putExtra(Intent.EXTRA_SUBJECT, stringResource(R.string.html_preview))
                    }
                    context.startActivity(Intent.createChooser(intent, stringResource(R.string.share)))
                }) {
                    Text(stringResource(R.string.share))
                }
                Button(onClick = {
                    // Download HTML file
                    try {
                        val fileName = "preview_${System.currentTimeMillis()}.html"
                        val file = File(context.getExternalFilesDir(null), fileName)
                        FileOutputStream(file).use { fos ->
                            fos.write(html.toByteArray())
                        }
                        // Show success message
                        android.widget.Toast.makeText(context, stringResource(R.string.saved_to, file.absolutePath), android.widget.Toast.LENGTH_LONG).show()
                    } catch (e: Exception) {
                        android.widget.Toast.makeText(context, stringResource(R.string.error_saving_file, e.message ?: ""), android.widget.Toast.LENGTH_SHORT).show()
                    }
                }) {
                    Text(stringResource(R.string.download_html))
                }
            }
        }
    }
}
