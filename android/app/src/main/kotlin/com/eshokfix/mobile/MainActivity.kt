package com.eshokfix.mobile

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
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
        private const val REQUEST_EXPORT = 7411
        private const val REQUEST_IMPORT = 7412
        private const val ACTION_EXPORT = "EXPORT"
        private const val ACTION_IMPORT = "IMPORT"
    }
}
