import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../downloads_store.dart';

/// Qué mostrar en la lista.
enum DownloadFilter { all, audio, video }

/// Lista de descargas con acciones (abrir, borrar). Se usa en las pestañas
/// Descargas, Música, Videos e Historial.
class DownloadsListView extends StatelessWidget {
  final List<DownloadItem> items;
  final DownloadFilter filter;
  final String emptyText;
  final Future<void> Function() onRefresh;
  final void Function(DownloadItem) onDelete;
  final void Function(DownloadItem) onOpen;
  final void Function(DownloadItem) onShare;

  const DownloadsListView({
    super.key,
    required this.items,
    required this.filter,
    required this.emptyText,
    required this.onRefresh,
    required this.onDelete,
    required this.onOpen,
    required this.onShare,
  });

  List<DownloadItem> get _filtered {
    switch (filter) {
      case DownloadFilter.audio:
        return items.where((e) => e.isAudio).toList();
      case DownloadFilter.video:
        return items.where((e) => e.isVideo).toList();
      case DownloadFilter.all:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.orange,
      backgroundColor: AppColors.card,
      child: list.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Icon(Icons.inbox_outlined,
                    size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Center(
                  child: Text(emptyText,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('Desliza hacia abajo para refrescar',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, i) =>
                  const Divider(color: AppColors.border, height: 16),
              itemBuilder: (context, i) => _DownloadTile(
                  item: list[i],
                  onDelete: onDelete,
                  onOpen: onOpen,
                  onShare: onShare),
            ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final void Function(DownloadItem) onDelete;
  final void Function(DownloadItem) onOpen;
  final void Function(DownloadItem) onShare;
  const _DownloadTile(
      {required this.item,
      required this.onDelete,
      required this.onOpen,
      required this.onShare});

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('¿Borrar archivo?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(item);
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpen(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: item.isAudio
                    ? AppColors.pinkGradient
                    : AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.isAudio ? Icons.music_note : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${item.formatLabel} • ${item.sizeLabel} • ${item.timeAgo}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: AppColors.textMuted),
              onPressed: () => onShare(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textMuted),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}
