import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'downloads_store.dart';
import 'update_service.dart';
import 'ytdlp_service.dart';
import 'widgets/downloads_list.dart';
import 'widgets/logo.dart';
import 'widgets/site_icons.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _urlController = TextEditingController();
  StreamSubscription? _progressSub;

  int _navIndex = 0;
  String _appVersion = '';

  // Archivos realmente descargados (leídos de la carpeta de la app).
  List<DownloadItem> _downloads = [];

  @override
  void initState() {
    super.initState();
    _initEngine();
    _loadDownloads();
    _loadVersion();
    _progressSub = YtdlpService.progressStream.listen((_) {});
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkUpdates(silent: true));
  }

  Future<void> _loadVersion() async {
    try {
      final v = await UpdateService.currentVersionName();
      if (mounted) setState(() => _appVersion = v);
    } catch (_) {}
  }

  Future<void> _loadDownloads() async {
    try {
      final items = await DownloadsStore.list();
      if (mounted) setState(() => _downloads = items);
    } catch (_) {}
  }

  Future<void> _deleteDownload(DownloadItem item) async {
    await DownloadsStore.delete(item);
    await _loadDownloads();
  }

  Future<void> _openFile(DownloadItem item) async {
    try {
      await DownloadsStore.open(item);
    } catch (e) {
      if (mounted) _snack('No se pudo abrir el archivo: $e');
    }
  }

  Future<void> _shareFile(DownloadItem item) async {
    try {
      await DownloadsStore.share(item);
    } catch (e) {
      if (mounted) _snack('No se pudo compartir: $e');
    }
  }

  Future<void> _initEngine() async {
    try {
      await YtdlpService.init();
    } catch (_) {
      // Se reintentará al descargar.
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Pegar
  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() => _urlController.text = data!.text!.trim());
    }
  }

  // ------------------------------------------------------------- Descargar
  void _onDownloadPressed({bool? audioPreset}) {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _snack('Pega primero un enlace.');
      return;
    }
    _openDownloadSheet(audioPreset: audioPreset);
  }

  void _openDownloadSheet({bool? audioPreset}) {
    bool audio = audioPreset ?? false;
    String quality = audio ? '320' : '1080';
    final url = _urlController.text.trim();

    // Detectar en segundo plano hasta qué resolución llega el video.
    // null = detectando; con valor = ya se sabe (heights puede venir vacío).
    final infoN = ValueNotifier<MediaInfo?>(null);
    YtdlpService.getInfo(url).then((info) {
      infoN.value = info;
    }).catchError((_) {
      infoN.value = MediaInfo(title: '', uploader: '', duration: 0, thumbnail: '');
    });

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final videoQ = {
            'best': 'Máxima disponible',
            '2160': '4K (2160p)',
            '1080': 'Full HD (1080p)',
            '720': 'HD (720p)',
            '480': '480p',
            '360': '360p',
          };
          final audioQ = {
            'best': 'Máxima disponible',
            '320': '320 kbps',
            '192': '192 kbps',
            '128': '128 kbps',
          };
          final options = audio ? audioQ : videoQ;
          if (!options.containsKey(quality)) quality = options.keys.first;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('¿Qué quieres descargar?',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _typeChip(
                      label: 'Video',
                      icon: Icons.movie_outlined,
                      selected: !audio,
                      color: AppColors.purple,
                      onTap: () => setSheet(() {
                        audio = false;
                        quality = '1080';
                      }),
                    ),
                    const SizedBox(width: 12),
                    _typeChip(
                      label: 'Música',
                      icon: Icons.music_note,
                      selected: audio,
                      color: AppColors.pink,
                      onTap: () => setSheet(() {
                        audio = true;
                        quality = '320';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Calidad',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: quality,
                      isExpanded: true,
                      dropdownColor: AppColors.cardSoft,
                      items: options.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheet(() => quality = v ?? quality),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Aviso de la calidad real del video (solo modo video).
                if (!audio)
                  ValueListenableBuilder<MediaInfo?>(
                    valueListenable: infoN,
                    builder: (context, info, child) {
                      if (info == null) {
                        return const Row(children: [
                          SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Detectando calidad del video…',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ]);
                      }
                      final max = info.maxHeight;
                      if (max == null) return const SizedBox.shrink();
                      return Row(children: [
                        const Icon(Icons.hd_outlined,
                            size: 15, color: AppColors.green),
                        const SizedBox(width: 6),
                        Text('Este video llega hasta ${max}p',
                            style: const TextStyle(
                                color: AppColors.green, fontSize: 12)),
                      ]);
                    },
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _GradientButton(
                    label: 'Descargar',
                    icon: Icons.download,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startDownload(audio: audio, quality: quality);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload({
    required bool audio,
    required String quality,
  }) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final progress = ValueNotifier<double>(0);
    final titleN = ValueNotifier<String>('Preparando descarga…');
    final sub = YtdlpService.progressStream
        .listen((p) => progress.value = p.progress / 100);

    if (!mounted) {
      await sub.cancel();
      progress.dispose();
      titleN.dispose();
      return;
    }
    // Mostrar la hoja de progreso de inmediato (antes de leer el video),
    // así el usuario ve "Preparando…" y no una pantalla congelada.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: titleN,
              builder: (context, t, child) => Text(t,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, v, child) => Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: v > 0 ? v : null,
                      minHeight: 10,
                      backgroundColor: AppColors.inputBg,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.orange),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(v > 0 ? '${(v * 100).toStringAsFixed(0)}%' : 'Preparando…',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Leer el título (mejor esfuerzo) y actualizarlo en la hoja.
      try {
        final info = await YtdlpService.getInfo(url);
        if (info.title.isNotEmpty) titleN.value = info.title;
      } catch (_) {}
      await YtdlpService.download(url,
          mode: audio ? 'audio' : 'video', quality: quality);
      if (mounted) {
        Navigator.of(context).pop(); // cerrar progreso
        await _loadDownloads(); // refrescar con el archivo real
        _snack('¡Descarga completada! 🎉');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(_cleanError(e));
      }
    } finally {
      await sub.cancel();
      progress.dispose();
      titleN.dispose();
    }
  }

  /// Extrae un mensaje legible de una PlatformException u otro error.
  String _cleanError(Object e) {
    var msg = e is PlatformException ? (e.message ?? e.code) : e.toString();
    // Recortar trazas largas de yt-dlp: quedarnos con lo esencial.
    if (msg.contains('ERROR:')) {
      msg = msg.substring(msg.indexOf('ERROR:') + 6).trim();
    }
    if (msg.length > 300) msg = '${msg.substring(0, 300)}…';
    return msg.isEmpty ? 'Ocurrió un error desconocido.' : msg;
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('No se pudo descargar'),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- Actualizaciones
  Future<void> _checkUpdates({bool silent = false}) async {
    try {
      final update = await UpdateService.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        if (!silent) _snack('Ya tienes la última versión ✅');
        return;
      }
      _showUpdateDialog(update);
    } catch (e) {
      if (!silent && mounted) _snack('No se pudo buscar actualizaciones: $e');
    }
  }

  void _showUpdateDialog(UpdateInfo update) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Actualización disponible (${update.versionName})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hay una nueva versión de Wiwy Downloader.'),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Novedades:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(update.notes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Después'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              _runUpdate(update);
            },
            child: const Text('Instalar ahora'),
          ),
        ],
      ),
    );
  }

  Future<void> _runUpdate(UpdateInfo update) async {
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Descargando actualización…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value > 0 ? value : null),
              const SizedBox(height: 12),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );
    try {
      await UpdateService.downloadAndInstall(update,
          onProgress: (p) => progress.value = p);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Error al actualizar: $e');
      }
    } finally {
      progress.dispose();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------- BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: IndexedStack(
          index: _navIndex,
          children: [
            _buildHome(),
            _buildTab('Descargas', DownloadFilter.all,
                'Aún no has descargado nada.'),
            _buildTab('Música', DownloadFilter.audio,
                'No tienes música descargada.'),
            _buildTab('Videos', DownloadFilter.video,
                'No tienes videos descargados.'),
            _buildTab('Historial', DownloadFilter.all,
                'Tu historial está vacío.'),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTab(String title, DownloadFilter filter, String emptyText) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                tooltip: 'Refrescar',
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                onPressed: _loadDownloads,
              ),
            ],
          ),
        ),
        Expanded(
          child: DownloadsListView(
            items: _downloads,
            filter: filter,
            emptyText: emptyText,
            onRefresh: _loadDownloads,
            onDelete: _deleteDownload,
            onOpen: _openFile,
            onShare: _shareFile,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- HOME
  Widget _buildHome() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildTopBar(),
        const SizedBox(height: 16),
        _buildHeroCard(),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureCard(
                  title: 'Descargar Video',
                  subtitle:
                      'Descarga videos en diferentes calidades y formatos.',
                  chips: const ['MP4', 'WEBM', 'MKV', '3GP'],
                  gradient: AppColors.purpleGradient,
                  accent: AppColors.purple,
                  icon: Icons.play_arrow_rounded,
                  onTap: () => _onDownloadPressed(audioPreset: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FeatureCard(
                  title: 'Descargar Música',
                  subtitle: 'Extrae y descarga música en alta calidad.',
                  chips: const ['MP3', 'M4A', 'AAC', 'OGG'],
                  gradient: AppColors.pinkGradient,
                  accent: AppColors.pink,
                  icon: Icons.music_note,
                  onTap: () => _onDownloadPressed(audioPreset: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildRecents(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const Spacer(),
        const WiwyLogo(),
        const Spacer(),
        // (sin botón premium)
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(text: 'Descarga\n'),
                      TextSpan(
                        text: 'videos y música\n',
                        style: TextStyle(color: AppColors.orange),
                      ),
                      TextSpan(
                        text: 'de cualquier página web',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const _HeroArt(),
            ],
          ),
          const SizedBox(height: 20),
          _buildUrlField(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              label: 'Descargar',
              icon: Icons.download,
              onTap: _onDownloadPressed,
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('Soportamos más de 1000 sitios web',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 14),
          const SiteIconsRow(),
        ],
      ),
    );
  }

  Widget _buildUrlField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: Row(
        children: [
          const Icon(Icons.link, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Pega aquí el enlace del video o música…',
                hintStyle:
                    TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _paste,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.orange,
              side: const BorderSide(color: AppColors.orange),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.content_paste, size: 16),
            label: const Text('Pegar'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecents() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Descargas recientes',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => setState(() => _navIndex = 1),
                child: const Text('Ver todo',
                    style: TextStyle(color: AppColors.orange)),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 24),
          if (_downloads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Aún no has descargado nada.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ..._downloads
                .take(4)
                .map((item) => _RecentTile(item: item, onOpen: _openFile)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- NAV
  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, 'Inicio'),
      (Icons.download_rounded, 'Descargas'),
      (Icons.music_note_rounded, 'Música'),
      (Icons.play_circle_fill_rounded, 'Videos'),
      (Icons.history_rounded, 'Historial'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = _navIndex == i;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _navIndex = i);
                if (i != 0) _loadDownloads();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].$1,
                      color: selected
                          ? AppColors.orange
                          : AppColors.textMuted),
                  const SizedBox(height: 4),
                  Text(items[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? AppColors.orange
                            : AppColors.textMuted,
                      )),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  const Expanded(child: WiwyLogo()),
                  IconButton(
                    tooltip: 'Cerrar menú',
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border),
            _drawerItem(Icons.home_rounded, 'Inicio', () {
              Navigator.pop(context);
              setState(() => _navIndex = 0);
            }),
            _drawerItem(Icons.system_update, 'Buscar actualizaciones', () {
              Navigator.pop(context);
              _checkUpdates(silent: false);
            }),
            _drawerItem(Icons.folder_open, 'Mis descargas', () {
              Navigator.pop(context);
              setState(() => _navIndex = 1);
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'Wiwy Downloader · v${_appVersion.isEmpty ? "…" : _appVersion}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}

// ============================================================ WIDGETS

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.orangeGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    // Icono de la app (sin fondo) como arte del hero.
    return Image.asset(
      'assets/icon/hero_download.png',
      width: 115,
      height: 115,
      fit: BoxFit.contain,
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;
  final Gradient gradient;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.gradient,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c,
                            style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final DownloadItem item;
  final void Function(DownloadItem) onOpen;
  const _RecentTile({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpen(item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Miniatura (gradiente según tipo)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: item.isAudio
                    ? AppColors.pinkGradient
                    : AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.isAudio ? Icons.music_note : Icons.play_arrow,
                  color: Colors.white),
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
                  Row(
                    children: [
                      Icon(
                          item.isAudio
                              ? Icons.music_note
                              : Icons.play_circle_outline,
                          size: 13,
                          color:
                              item.isAudio ? AppColors.pink : AppColors.purple),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                            '${item.formatLabel} • ${item.sizeLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(item.timeAgo,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: AppColors.green, size: 20),
          ],
        ),
      ),
    );
  }
}
