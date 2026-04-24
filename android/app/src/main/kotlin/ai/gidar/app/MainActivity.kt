package ai.gidar.app

import android.Manifest
import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Bundle
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "ai.gidar.app/downloads"
    private val appearanceChannel = "ai.gidar.app/appearance"
    private val downloadNotificationChannel = "gidar_ai_downloads"
    private val flutterPrefsName = "FlutterSharedPreferences"
    private val appearanceModeKey = "flutter.appearance_mode"
    private val appThemeKey = "flutter.app_theme"
    private val darkAppearanceValue = "dark"
    private val lightAppearanceValue = "light"
    private val systemAppearanceValue = "system"
    private val pureLightThemeValue = "pureLight"
    private val defaultAppearanceValue = darkAppearanceValue
    private val defaultAppThemeValue = "classicDark"

    override fun onCreate(savedInstanceState: Bundle?) {
        setTheme(resolveLaunchTheme())
        super.onCreate(savedInstanceState)
        syncLaunchThemeOverride()
    }

    private fun resolveLaunchTheme(): Int {
        val prefs = getSharedPreferences(flutterPrefsName, Context.MODE_PRIVATE)
        val appearanceMode = prefs.getString(appearanceModeKey, defaultAppearanceValue)
        val themeMode = prefs.getString(appThemeKey, defaultAppThemeValue)
        return when (appearanceMode) {
            lightAppearanceValue -> R.style.LaunchThemeLight
            darkAppearanceValue -> R.style.LaunchThemeDark
            systemAppearanceValue -> R.style.LaunchTheme
            else -> if (themeMode == pureLightThemeValue) {
                R.style.LaunchThemeLight
            } else {
                R.style.LaunchThemeDark
            }
        }
    }

    private fun syncLaunchThemeOverride() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setSplashScreenTheme(resolveLaunchTheme())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveTextFile" -> {
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    val mimeType = call.argument<String>("mimeType") ?: "text/plain"
                    if (fileName.isNullOrBlank() || content == null) {
                        result.error(
                            "invalid_args",
                            "fileName and content are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val savedPath = saveTextFileToDownloads(
                            fileName = fileName,
                            content = content,
                            mimeType = mimeType,
                        )
                        showDownloadCompleteNotification(fileName)
                        result.success(savedPath)
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }

                "saveBinaryFile" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    val mimeType = call.argument<String>("mimeType")
                        ?: "application/octet-stream"
                    if (fileName.isNullOrBlank() || bytes == null) {
                        result.error(
                            "invalid_args",
                            "fileName and bytes are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val savedPath = saveBytesToDownloads(
                            fileName = fileName,
                            bytes = bytes,
                            mimeType = mimeType,
                        )
                        showDownloadCompleteNotification(fileName)
                        result.success(savedPath)
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appearanceChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncLaunchTheme" -> {
                    syncLaunchThemeOverride()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun saveTextFileToDownloads(
        fileName: String,
        content: String,
        mimeType: String,
    ): String {
        val bytes = content.toByteArray(Charsets.UTF_8)
        return saveBytesToDownloads(
            fileName = fileName,
            bytes = bytes,
            mimeType = mimeType,
        )
    }

    private fun saveBytesToDownloads(
        fileName: String,
        bytes: ByteArray,
        mimeType: String,
    ): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(
                fileName = fileName,
                mimeType = mimeType,
                bytes = bytes,
            )
        } else {
            saveLegacyFile(
                fileName = fileName,
                mimeType = mimeType,
                bytes = bytes,
            )
        }
    }

    private fun saveWithMediaStore(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
    ): String {
        val resolver = applicationContext.contentResolver
        val relativePath = Environment.DIRECTORY_DOWNLOADS + File.separator + "GidarAI"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val itemUri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("Could not create download entry.")

        resolver.openOutputStream(itemUri)?.use { stream ->
            stream.write(bytes)
            stream.flush()
        } ?: error("Could not open download output stream.")

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(itemUri, values, null, null)
        return "Downloads${File.separator}GidarAI${File.separator}$fileName"
    }

    private fun saveLegacyFile(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
    ): String {
        val downloadsDir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val exportDir = File(downloadsDir, "GidarAI")
        if (!exportDir.exists()) {
            exportDir.mkdirs()
        }

        val file = File(exportDir, fileName)
        FileOutputStream(file).use { output ->
            output.write(bytes)
            output.flush()
        }

        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(file.absolutePath),
            arrayOf(mimeType),
            null,
        )

        val downloadManager = ContextCompat.getSystemService(
            applicationContext,
            DownloadManager::class.java,
        )
        downloadManager?.addCompletedDownload(
            fileName,
            fileName,
            true,
            mimeType,
            file.absolutePath,
            file.length(),
            true,
        )

        return file.absolutePath
    }

    private fun showDownloadCompleteNotification(fileName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val notificationManager = NotificationManagerCompat.from(this)
        ensureNotificationChannel(notificationManager)

        val openDownloadsIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
        val pendingIntent = PendingIntent.getActivity(
            this,
            201,
            openDownloadsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, downloadNotificationChannel)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Download complete")
            .setContentText(fileName)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        notificationManager.notify(fileName.hashCode(), notification)
    }

    private fun ensureNotificationChannel(notificationManager: NotificationManagerCompat) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val platformManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = platformManager.getNotificationChannel(downloadNotificationChannel)
        if (existing != null) {
            return
        }

        val channel = NotificationChannel(
            downloadNotificationChannel,
            "Downloads",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Download completion alerts from Gidar AI"
        }
        notificationManager.createNotificationChannel(channel)
    }
}
