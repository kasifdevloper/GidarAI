package ai.gidar.app.ui.components

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import ai.gidar.app.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CodeSandboxSheet(
    initialCode: String,
    onDismiss: () -> Unit
) {
    var code by remember { mutableStateOf(initialCode) }
    var selectedTab by remember { mutableIntStateOf(0) }
    var output by remember { mutableStateOf("") }
    var consoleLogs by remember { mutableStateOf("") }
    val tabs = listOf(
        stringResource(R.string.code),
        stringResource(R.string.output),
        stringResource(R.string.console)
    )

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.fillMaxHeight(0.9f).padding(16.dp)) {
            TabRow(selectedTabIndex = selectedTab) {
                tabs.forEachIndexed { index, title ->
                    Tab(selected = selectedTab == index, onClick = { selectedTab = index }, text = { Text(title) })
                }
            }
            
            Spacer(Modifier.height(16.dp))
            
            when (selectedTab) {
                0 -> {
                    OutlinedTextField(
                        value = code,
                        onValueChange = { code = it },
                        modifier = Modifier.fillMaxSize().weight(1f),
                        textStyle = MaterialTheme.typography.bodyMedium
                    )
                }
                1 -> {
                    // Output tab - WebView for HTML/JS
                    AndroidView(
                        factory = { context ->
                            WebView(context).apply {
                                webViewClient = object : WebViewClient() {
                                    override fun onPageFinished(view: WebView?, url: String?) {
                                        // Capture console logs
                                        evaluateJavascript(
                                            """
                                            (function() {
                                                var oldLog = console.log;
                                                var oldError = console.error;
                                                var oldWarn = console.warn;
                                                var logs = [];
                                                console.log = function() {
                                                    logs.push('LOG: ' + Array.from(arguments).join(' '));
                                                    oldLog.apply(console, arguments);
                                                };
                                                console.error = function() {
                                                    logs.push('ERROR: ' + Array.from(arguments).join(' '));
                                                    oldError.apply(console, arguments);
                                                };
                                                console.warn = function() {
                                                    logs.push('WARN: ' + Array.from(arguments).join(' '));
                                                    oldWarn.apply(console, arguments);
                                                };
                                                window.getLogs = function() { return logs.join('\\n'); };
                                            })();
                                            """.trimIndent()
                                        ) { }
                                    }
                                }
                                settings.javaScriptEnabled = true
                                settings.domStorageEnabled = true
                            }
                        },
                        update = { webView ->
                            // Wrap code in HTML if it's not already HTML
                            val htmlContent = if (code.trim().startsWith("<!DOCTYPE") || code.trim().startsWith("<html")) {
                                code
                            } else {
                                """
                                <!DOCTYPE html>
                                <html>
                                <head>
                                    <style>
                                        body { font-family: monospace; padding: 16px; background: #1e1e1e; color: #d4d4d4; }
                                    </style>
                                </head>
                                <body>
                                    <script>
                                        $code
                                    </script>
                                </body>
                                </html>
                                """.trimIndent()
                            }
                            webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null)
                            
                            // Get console logs after a delay
                            webView.postDelayed({
                                webView.evaluateJavascript("window.getLogs ? window.getLogs() : ''") { logs ->
                                    consoleLogs = logs?.removeSurrounding("\"") ?: ""
                                }
                            }, 1000)
                        },
                        modifier = Modifier.fillMaxSize().weight(1f)
                    )
                }
                2 -> {
                    // Console tab
                    OutlinedTextField(
                        value = consoleLogs,
                        onValueChange = { },
                        modifier = Modifier.fillMaxSize().weight(1f),
                        textStyle = MaterialTheme.typography.bodyMedium,
                        readOnly = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            disabledTextColor = MaterialTheme.colorScheme.onSurface,
                            disabledBorderColor = MaterialTheme.colorScheme.outline
                        )
                    )
                }
            }
            
            Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Button(onClick = {
                    // Run logic - trigger WebView reload
                    selectedTab = 1 // Switch to output tab
                }) {
                    Text(stringResource(R.string.run))
                }
                Button(
                    onClick = {
                        code = ""
                        output = ""
                        consoleLogs = ""
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text(stringResource(R.string.clear))
                }
            }
        }
    }
}
