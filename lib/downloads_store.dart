import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Un archivo descargado en el disco.
class DownloadItem {
  final File file;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  DownloadItem({
    required this.file,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

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

  /// Nombre sin la extensión, para mostrar como título.
  String get title {
    final i = name.lastIndexOf('.');
    return i == -1 ? name : name.substring(0, i);
  }
}

/// Lee y gestiona los archivos de la carpeta de descargas de la app.
class DownloadsStore {
  /// Misma carpeta donde escribe el motor nativo:
  /// `/sdcard/Android/data/<pkg>/files/Download`
  static Future<Directory> downloadsDir() async {
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base!.path}/Download');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Lista los archivos descargados, del más reciente al más antiguo.
  /// Ignora archivos temporales (.part, .ytdl).
  static Future<List<DownloadItem>> list() async {
    final dir = await downloadsDir();
    final items = <DownloadItem>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.part') ||
          name.endsWith('.ytdl') ||
          name.startsWith('.')) {
        continue;
      }
      final stat = entity.statSync();
      items.add(DownloadItem(
        file: entity,
        name: name,
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }
    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  static Future<void> delete(DownloadItem item) async {
    if (await item.file.exists()) await item.file.delete();
  }
}
