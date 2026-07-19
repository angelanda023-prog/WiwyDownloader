import 'dart:convert';
import 'package:flutter/services.dart';

/// Un archivo descargado en Descargas/WiwyDownloader (carpeta pública).
class DownloadItem {
  /// Identificador para abrir/borrar: MediaStore _ID (Android 10+) o ruta.
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  DownloadItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(
            (j['modified'] as num?)?.toInt() ?? 0),
      );

  static const _audioExt = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'};

  String get ext {
    final i = name.lastIndexOf('.');
    return i == -1 ? '' : name.substring(i + 1).toLowerCase();
  }

  bool get isAudio => _audioExt.contains(ext);
  bool get isVideo => !isAudio;

  String get formatLabel => ext.toUpperCase();

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }

  String get timeAgo {
    final d = DateTime.now().difference(modified);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) {
      return 'Hace ${d.inHours} ${d.inHours == 1 ? "hora" : "horas"}';
    }
    return 'Hace ${d.inDays} ${d.inDays == 1 ? "día" : "días"}';
  }

  String get title {
    final i = name.lastIndexOf('.');
    return i == -1 ? name : name.substring(0, i);
  }
}

/// Lee y gestiona los archivos de Descargas/WiwyDownloader vía el canal nativo.
class DownloadsStore {
  static const _channel = MethodChannel('wiwy/ytdlp');

  static Future<List<DownloadItem>> list() async {
    final res = await _channel.invokeMethod<String>('listDownloads');
    if (res == null || res.isEmpty) return [];
    final data = jsonDecode(res) as List<dynamic>;
    return data
        .map((e) => DownloadItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Abre el archivo con la app del sistema.
  static Future<void> open(DownloadItem item) async {
    await _channel.invokeMethod('openDownload', {'id': item.id});
  }

  static Future<void> delete(DownloadItem item) async {
    await _channel.invokeMethod('deleteDownload', {'id': item.id});
  }
}
