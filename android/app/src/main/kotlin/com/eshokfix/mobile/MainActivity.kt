package com.eshokfix.mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var backupResult: MethodChannel.Result? = null
    private var backupAction: String? = null
    private var backupSourcePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportDatabaseBackup" -> {
                    if (backupResult != null) {
                        result.error("BACKUP_BUSY", "Ya hay una operación de respaldo en curso.", null)
                        return@setMethodCallHandler
                    }
                    val sourcePath = call.argument<String>("sourcePath")
                    if (sourcePath.isNullOrBlank() || !File(sourcePath).exists()) {
                        result.error("BACKUP_SOURCE", "No se encontró el archivo de la base de datos.", null)
                        return@setMethodCallHandler
                    }
                    backupResult = result
                    backupAction = ACTION_EXPORT
                    backupSourcePath = sourcePath
                    val title = call.argument<String>("fileName") ?: "eShokFix-backup.db"
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, title)
                    }
                    try {
                        startActivityForResult(intent, REQUEST_EXPORT)
                    } catch (error: Exception) {
                        clearPending()
                        result.error("BACKUP_PICKER", error.message, null)
                    }
                }
                "pickDatabaseBackup" -> {
                    if (backupResult != null) {
                        result.error("BACKUP_BUSY", "Ya hay una operación de respaldo en curso.", null)
                        return@setMethodCallHandler
                    }
                    backupResult = result
                    backupAction = ACTION_IMPORT
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                            "application/octet-stream",
                            "application/vnd.sqlite3",
                            "application/x-sqlite3"
                        ))
                    }
                    try {
                        startActivityForResult(intent, REQUEST_IMPORT)
                    } catch (error: Exception) {
                        clearPending()
                        result.error("BACKUP_PICKER", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        packageManager.canRequestPackageInstalls()
                )
                "requestInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()) {
                        startActivity(Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        ))
                    }
                    result.success(true)
                }
                "installApk" -> {
                    try {
                        val path = call.argument<String>("path")
                            ?: throw IllegalArgumentException("Falta la ruta del APK.")
                        val apk = File(path)
                        if (!apk.exists() || apk.length() < 1024) {
                            throw IllegalArgumentException("El APK no existe o está incompleto.")
                        }
                        val archiveInfo = packageManager.getPackageArchiveInfo(
                            apk.absolutePath,
                            android.content.pm.PackageManager.GET_ACTIVITIES
                        ) ?: throw IllegalArgumentException("Android no reconoce el archivo como APK instalable.")
                        if (archiveInfo.packageName != packageName) {
                            throw IllegalArgumentException("El APK pertenece a otra aplicación.")
                        }
                        val installedInfo = packageManager.getPackageInfo(packageName, 0)
                        val downloadedVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            archiveInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            archiveInfo.versionCode.toLong()
                        }
                        val installedVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            installedInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            installedInfo.versionCode.toLong()
                        }
                        if (downloadedVersion <= installedVersion) {
                            throw IllegalArgumentException("Esta versión no es más reciente que la instalada.")
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            !packageManager.canRequestPackageInstalls()) {
                            result.error("INSTALL_PERMISSION_REQUIRED",
                                "Autoriza a eShokFix para instalar actualizaciones.", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("APK_INSTALL_FAILED", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated by Android, retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_EXPORT && requestCode != REQUEST_IMPORT) return
        val callback = backupResult ?: return
        try {
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data!!
            if (requestCode == REQUEST_EXPORT) {
                val sourcePath = backupSourcePath
                    ?: throw IllegalStateException("Se perdió la ruta de la copia.")
                val source = File(sourcePath)
                val output = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("No se pudo abrir el destino seleccionado.")
                output.use { stream ->
                    source.inputStream().use { input -> input.copyTo(stream) }
                }
                callback.success(uri.toString())
            } else {
                val destination = File(cacheDir, "eshokfix-restore-${System.currentTimeMillis()}.db")
                val input = contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("No se pudo leer el archivo seleccionado.")
                input.use { inputStream ->
                    destination.outputStream().use { output -> inputStream.copyTo(output) }
                }
                callback.success(destination.absolutePath)
            }
        } catch (error: Exception) {
            callback.error("BACKUP_IO", error.message, null)
        } finally {
            clearPending()
        }
    }

    private fun clearPending() {
        backupResult = null
        backupAction = null
        backupSourcePath = null
    }

    companion object {
        private const val CHANNEL_NAME = "com.eshokfix.mobile/database_backup"
        private const val UPDATE_CHANNEL_NAME = "com.eshokfix.mobile/app_updates"
        private const val REQUEST_EXPORT = 7411
        private const val REQUEST_IMPORT = 7412
        private const val ACTION_EXPORT = "EXPORT"
        private const val ACTION_IMPORT = "IMPORT"
    }
}
