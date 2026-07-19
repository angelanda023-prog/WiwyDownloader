/// Una descarga completada, mostrada en "Descargas recientes".
class RecentDownload {
  final String title;
  final String format; // MP4, MP3, …
  final String quality; // 1080p, 320kbps, …
  final String size; // "85.6 MB"
  final DateTime date;
  final bool isAudio;
  final String? thumbnail; // URL o null

  RecentDownload({
    required this.title,
    required this.format,
    required this.quality,
    required this.size,
    required this.date,
    required this.isAudio,
    this.thumbnail,
  });

  /// Texto "Hace 2 min", "Hace 1 hora"…
  String get timeAgo {
    final d = DateTime.now().difference(date);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) {
      return 'Hace ${d.inHours} ${d.inHours == 1 ? "hora" : "horas"}';
    }
    return 'Hace ${d.inDays} ${d.inDays == 1 ? "día" : "días"}';
  }
}
