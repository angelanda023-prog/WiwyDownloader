package com.wiwy.wiwy_downloader

import android.os.Environment
import androidx.annotation.NonNull
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    private val methodChannel = "wiwy/ytdlp"
    private val eventChannel = "wiwy/ytdlp/progress"
    private var progressSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.IO)

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

    /** Descarga a la carpeta pública de Descargas. mode = "audio" | "video". */
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
                // Carpeta propia de la app: no requiere permisos y funciona en todas
                // las versiones de Android. Ruta visible: Android/data/<app>/files/Download
                val downloadDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: File(filesDir, "Download")
                if (!downloadDir.exists()) downloadDir.mkdirs()

                val request = YoutubeDLRequest(url).apply {
                    addOption("-o", File(downloadDir, "%(title)s.%(ext)s").absolutePath)
                    addOption("--no-mtime")
                    if (mode == "audio") {
                        addOption("-x")                 // extraer solo audio
                        addOption("--audio-format", "mp3")
                        // quality: "320" | "192" | "128" | "best"
                        val aq = when (quality) {
                            "320" -> "320K"
                            "192" -> "192K"
                            "128" -> "128K"
                            else -> "0"                 // mejor calidad disponible
                        }
                        addOption("--audio-quality", aq)
                    } else {
                        // quality: "2160" | "1080" | "720" | "480" | "360" | "best"
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
                withContext(Dispatchers.Main) {
                    result.success(downloadDir.absolutePath)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_FAILED", e.message, null)
                }
            }
        }
    }
}
