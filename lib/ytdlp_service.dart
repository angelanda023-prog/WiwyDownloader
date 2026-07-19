import 'dart:convert';
import 'package:flutter/services.dart';

/// Información básica de un video/audio, sin descargarlo.
class MediaInfo {
  final String title;
  final String uploader;
  final int duration; // segundos
  final String thumbnail;

  MediaInfo({
    required this.title,
    required this.uploader,
    required this.duration,
    required this.thumbnail,
  });

  factory MediaInfo.fromJson(Map<String, dynamic> j) => MediaInfo(
        title: j['title'] ?? '',
        uploader: j['uploader'] ?? '',
        duration: (j['duration'] ?? 0) is int
            ? j['duration'] ?? 0
            : (j['duration'] as num).toInt(),
        thumbnail: j['thumbnail'] ?? '',
      );
}

/// Progreso de una descarga en curso.
class DownloadProgress {
  final double progress; // 0..100
  final int eta; // segundos restantes
  final String line; // texto crudo de yt-dlp

  DownloadProgress(this.progress, this.eta, this.line);

  factory DownloadProgress.fromJson(Map<String, dynamic> j) => DownloadProgress(
        (j['progress'] as num?)?.toDouble() ?? 0,
        (j['eta'] as num?)?.toInt() ?? -1,
        j['line'] ?? '',
      );
}

/// Puente entre Flutter y el motor nativo yt-dlp (youtubedl-android).
class YtdlpService {
  static const _method = MethodChannel('wiwy/ytdlp');
  static const _events = EventChannel('wiwy/ytdlp/progress');

  /// Stream con el progreso de la descarga activa.
  static Stream<DownloadProgress> get progressStream => _events
      .receiveBroadcastStream()
      .map((e) => DownloadProgress.fromJson(jsonDecode(e as String)));

  /// Extrae los binarios la primera vez (lento). Llamar al iniciar la app.
  static Future<void> init() async {
    await _method.invokeMethod('init');
  }

  /// Obtiene título/duración/miniatura sin descargar.
  static Future<MediaInfo> getInfo(String url) async {
    final res = await _method.invokeMethod<String>('getInfo', {'url': url});
    return MediaInfo.fromJson(jsonDecode(res!) as Map<String, dynamic>);
  }

  /// Descarga. mode = 'audio' (mp3) o 'video' (mp4).
  /// quality video: '2160' | '1080' | '720' | '480' | '360' | 'best'.
  /// quality audio: '320' | '192' | '128' | 'best'.
  /// Devuelve la carpeta destino.
  static Future<String> download(
    String url, {
    required String mode,
    required String quality,
  }) async {
    final res = await _method.invokeMethod<String>(
      'download',
      {'url': url, 'mode': mode, 'quality': quality},
    );
    return res ?? '';
  }
}
