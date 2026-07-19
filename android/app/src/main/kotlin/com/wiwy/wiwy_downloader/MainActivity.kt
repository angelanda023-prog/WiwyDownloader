package com.wiwy.wiwy_downloader

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.NonNull
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    private val methodChannel = "wiwy/ytdlp"
    private val eventChannel = "wiwy/ytdlp/progress"
    private var progressSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    // Carpeta pública destino: Descargas/WiwyDownloader
    private val publicSubDir = "WiwyDownloader"
    private val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/WiwyDownloader"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    progressSink = sink
                }
                override fun onCancel(args: Any?) {
                    progressSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> initEngine(result)
                    "update" -> updateEngine(result)
                    "getInfo" -> getInfo(call.argument<String>("url"), result)
                    "download" -> download(
                        call.argument<String>("url"),
                        call.argument<String>("mode") ?: "video",
                        call.argument<String>("quality") ?: "best",
                        result
                    )
                    "listDownloads" -> listDownloads(result)
                    "openDownload" -> openDownload(call.argument<String>("id"), result)
                    "shareDownload" -> shareDownload(call.argument<String>("id"), result)
                    "deleteDownload" -> deleteDownload(call.argument<String>("id"), result)
                    else -> result.notImplemented()
                }
            }
    }

    /** Extrae los binarios de python/ffmpeg la primera vez. Es lento: hazlo una sola vez. */
    private fun initEngine(result: MethodChannel.Result) {
        scope.launch {
            try {
                YoutubeDL.getInstance().init(applicationContext)
                FFmpeg.getInstance().init(applicationContext)
                // yt-dlp empaquetado suele estar viejo y YouTube lo rompe (nsig).
                // Lo actualizamos a la última versión (mejor esfuerzo, requiere red).
                try {
                    YoutubeDL.getInstance().updateYoutubeDL(applicationContext)
                } catch (_: Throwable) {
                    // Sin conexión o ya está al día: seguimos con el que hay.
                }
                withContext(Dispatchers.Main) { result.success(true) }
            } catch (e: Throwable) {
                withContext(Dispatchers.Main) {
                    result.error("INIT_FAILED", e.message, null)
                }
            }
        }
    }

    /** Fuerza la actualización de yt-dlp a la última versión. */
    private fun updateEngine(result: MethodChannel.Result) {
        scope.launch {
            try {
                val status = YoutubeDL.getInstance().updateYoutubeDL(applicationContext)
                withContext(Dispatchers.Main) { result.success(status?.toString() ?: "DONE") }
            } catch (e: Throwable) {
                withContext(Dispatchers.Main) {
                    result.error("UPDATE_FAILED", e.message, null)
                }
            }
        }
    }

    /** Devuelve título, duración y miniatura sin descargar. */
    private fun getInfo(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("NO_URL", "URL vacía", null); return
        }
        scope.launch {
            try {
                val info = YoutubeDL.getInstance().getInfo(url)
                val json = JSONObject().apply {
                    put("title", info.title ?: "")
                    put("uploader", info.uploader ?: "")
                    put("duration", info.duration)
                    put("thumbnail", info.thumbnail ?: "")
                }
                withContext(Dispatchers.Main) { result.success(json.toString()) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("INFO_FAILED", e.message, null)
                }
            }
        }
    }

    /**
     * Descarga a una carpeta temporal y luego exporta a Descargas/WiwyDownloader
     * (pública, sobrevive a la desinstalación). mode = "audio" | "video".
     */
    private fun download(
        url: String?,
        mode: String,
        quality: String,
        result: MethodChannel.Result
    ) {
        if (url.isNullOrBlank()) {
            result.error("NO_URL", "URL vacía", null); return
        }
        scope.launch {
            try {
                // Carpeta temporal privada (rápida y sin permisos) para trabajar.
                val staging = File(cacheDir, "staging")
                if (staging.exists()) staging.deleteRecursively()
                staging.mkdirs()

                val request = YoutubeDLRequest(url).apply {
                    addOption("-o", File(staging, "%(title)s.%(ext)s").absolutePath)
                    addOption("--no-mtime")
                    if (mode == "audio") {
                        addOption("-x")
                        addOption("--audio-format", "mp3")
                        val aq = when (quality) {
                            "320" -> "320K"
                            "192" -> "192K"
                            "128" -> "128K"
                            else -> "0"
                        }
                        addOption("--audio-quality", aq)
                    } else {
                        val fmt = if (quality == "best") {
                            "bestvideo+bestaudio/best"
                        } else {
                            "bestvideo[height<=$quality]+bestaudio/best[height<=$quality]/best"
                        }
                        addOption("-f", fmt)
                        addOption("--merge-output-format", "mp4")
                    }
                }

                YoutubeDL.getInstance().execute(request) { progress, etaSeconds, line ->
                    runOnUiThread {
                        val payload = JSONObject().apply {
                            put("progress", progress)
                            put("eta", etaSeconds)
                            put("line", line)
                        }
                        progressSink?.success(payload.toString())
                    }
                }

                // Exportar los archivos producidos a Descargas/WiwyDownloader.
                val produced = staging.listFiles()?.filter { it.isFile } ?: emptyList()
                Log.d("WiwyDL", "descarga OK; archivos en staging: ${produced.size} -> ${produced.map { it.name }}")
                for (f in produced) {
                    Log.d("WiwyDL", "exportando ${f.name} (${f.length()} bytes)")
                    exportToPublicDownloads(f)
                }
                staging.deleteRecursively()
                Log.d("WiwyDL", "exportación completa a Descargas/$publicSubDir")

                withContext(Dispatchers.Main) {
                    result.success("Descargas/$publicSubDir")
                }
            } catch (e: Throwable) {
                Log.e("WiwyDL", "DOWNLOAD_FAILED", e)
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_FAILED", e.message, null)
                }
            }
        }
    }

    private fun mimeFor(name: String): String {
        val n = name.lowercase()
        return when {
            n.endsWith(".mp3") -> "audio/mpeg"
            n.endsWith(".m4a") -> "audio/mp4"
            n.endsWith(".aac") -> "audio/aac"
            n.endsWith(".ogg") || n.endsWith(".opus") -> "audio/ogg"
            n.endsWith(".wav") -> "audio/wav"
            n.endsWith(".flac") -> "audio/flac"
            n.endsWith(".mp4") -> "video/mp4"
            n.endsWith(".webm") -> "video/webm"
            n.endsWith(".mkv") -> "video/x-matroska"
            n.endsWith(".3gp") -> "video/3gpp"
            else -> "application/octet-stream"
        }
    }

    /** Copia [src] a la carpeta pública Descargas/WiwyDownloader. */
    private fun exportToPublicDownloads(src: File) {
        val mime = mimeFor(src.name)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, src.name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return
            resolver.openOutputStream(uri)?.use { out ->
                src.inputStream().use { it.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            Log.d("WiwyDL", "MediaStore export OK: $uri")
        } else {
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                publicSubDir
            )
            if (!dir.exists()) dir.mkdirs()
            src.copyTo(File(dir, src.name), overwrite = true)
        }
    }

    /** Lista los archivos de Descargas/WiwyDownloader como JSON. */
    private fun listDownloads(result: MethodChannel.Result) {
        scope.launch {
            try {
                val arr = JSONArray()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val projection = arrayOf(
                        MediaStore.Downloads._ID,
                        MediaStore.Downloads.DISPLAY_NAME,
                        MediaStore.Downloads.SIZE,
                        MediaStore.Downloads.DATE_MODIFIED
                    )
                    val selection = "${MediaStore.Downloads.RELATIVE_PATH} LIKE ?"
                    val args = arrayOf("%$publicSubDir%")
                    val sort = "${MediaStore.Downloads.DATE_MODIFIED} DESC"
                    contentResolver.query(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        projection, selection, args, sort
                    )?.use { c ->
                        val idCol = c.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                        val nameCol = c.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)
                        val sizeCol = c.getColumnIndexOrThrow(MediaStore.Downloads.SIZE)
                        val dateCol = c.getColumnIndexOrThrow(MediaStore.Downloads.DATE_MODIFIED)
                        while (c.moveToNext()) {
                            arr.put(JSONObject().apply {
                                put("id", c.getLong(idCol).toString())
                                put("name", c.getString(nameCol) ?: "")
                                put("size", c.getLong(sizeCol))
                                put("modified", c.getLong(dateCol) * 1000L) // a milisegundos
                            })
                        }
                    }
                } else {
                    val dir = File(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                        publicSubDir
                    )
                    dir.listFiles()?.filter { it.isFile }
                        ?.sortedByDescending { it.lastModified() }
                        ?.forEach { f ->
                            arr.put(JSONObject().apply {
                                put("id", f.absolutePath)
                                put("name", f.name)
                                put("size", f.length())
                                put("modified", f.lastModified())
                            })
                        }
                }
                withContext(Dispatchers.Main) { result.success(arr.toString()) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("LIST_FAILED", e.message, null)
                }
            }
        }
    }

    /** Abre un archivo (id = MediaStore _ID en API 29+, o ruta absoluta en API < 29). */
    private fun openDownload(id: String?, result: MethodChannel.Result) {
        if (id.isNullOrBlank()) {
            result.error("NO_ID", "id vacío", null); return
        }
        try {
            val uri: Uri
            val mime: String
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                uri = ContentUris.withAppendedId(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toLong()
                )
                mime = contentResolver.getType(uri) ?: "*/*"
            } else {
                val file = File(id)
                uri = androidx.core.content.FileProvider.getUriForFile(
                    this, "$packageName.fileprovider", file
                )
                mime = mimeFor(file.name)
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    /** Comparte un archivo con otras apps (WhatsApp, etc.). */
    private fun shareDownload(id: String?, result: MethodChannel.Result) {
        if (id.isNullOrBlank()) {
            result.error("NO_ID", "id vacío", null); return
        }
        try {
            val uri: Uri
            val mime: String
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                uri = ContentUris.withAppendedId(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toLong()
                )
                mime = contentResolver.getType(uri) ?: "*/*"
            } else {
                val file = File(id)
                uri = androidx.core.content.FileProvider.getUriForFile(
                    this, "$packageName.fileprovider", file
                )
                mime = mimeFor(file.name)
            }
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, "Compartir con…").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", e.message, null)
        }
    }

    /** Borra un archivo por id (MediaStore) o ruta. */
    private fun deleteDownload(id: String?, result: MethodChannel.Result) {
        if (id.isNullOrBlank()) {
            result.error("NO_ID", "id vacío", null); return
        }
        scope.launch {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toLong()
                    )
                    contentResolver.delete(uri, null, null)
                } else {
                    File(id).delete()
                }
                withContext(Dispatchers.Main) { result.success(true) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DELETE_FAILED", e.message, null)
                }
            }
        }
    }
}
