package ai.gidar.app.ui.components

import android.content.Context
import android.content.Intent
import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import ai.gidar.app.R
import java.io.File
import java.io.FileOutputStream

object PDFExport {
    fun exportToPdf(context: Context, htmlContent: String, fileName: String) {
        val webView = WebView(context)
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                val printManager = context.getSystemService(Context.PRINT_SERVICE) as PrintManager
                val printAdapter = webView.createPrintDocumentAdapter(fileName)
                printManager.print(fileName, printAdapter, PrintAttributes.Builder().build())
            }
        }
        webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null)
    }

    fun exportToHtmlFile(context: Context, htmlContent: String, fileName: String): File? {
        return try {
            val file = File(context.getExternalFilesDir(null), fileName)
            FileOutputStream(file).use { fos ->
                fos.write(htmlContent.toByteArray())
            }
            file
        } catch (e: Exception) {
            null
        }
    }

    fun shareHtml(context: Context, htmlContent: String, subject: String = context.getString(R.string.chat_export)) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/html"
            putExtra(Intent.EXTRA_TEXT, htmlContent)
            putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        context.startActivity(Intent.createChooser(intent, context.getString(R.string.share)))
    }

    fun chatToHtml(messages: List<ai.gidar.app.data.local.MessageEntity>, title: String = context.getString(R.string.chat_export)): String {
        val messagesHtml = messages.joinToString("\n") { message ->
            val role = if (message.role == "user") context.getString(R.string.you) else context.getString(R.string.gidar_ai_assistant)
            val bgColor = if (message.role == "user") "#262626" else "#121212"
            """
            <div style="margin: 16px 0; padding: 16px; background-color: $bgColor; border-radius: 12px;">
                <div style="font-weight: bold; margin-bottom: 8px; color: #7EB1FF;">$role</div>
                <div style="white-space: pre-wrap;">${message.content}</div>
            </div>
            """.trimIndent()
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>$title</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 24px;
                    background-color: #090909;
                    color: #ffffff;
                }
                h1 {
                    color: #7EB1FF;
                    border-bottom: 2px solid #3A3A3C;
                    padding-bottom: 12px;
                }
                .timestamp {
                    color: #666;
                    font-size: 12px;
                    margin-top: 8px;
                }
            </style>
        </head>
        <body>
            <h1>$title</h1>
            <div class="timestamp">Exported on ${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}</div>
            $messagesHtml
        </body>
        </html>
        """.trimIndent()
    }
}
