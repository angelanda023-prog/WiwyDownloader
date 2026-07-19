import 'dart:async';
import 'package:flutter/material.dart';
import 'ytdlp_service.dart';

void main() => runApp(const WiwyApp());

class WiwyApp extends StatelessWidget {
  const WiwyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wiwy Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7C3AED),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  StreamSubscription? _progressSub;

  bool _engineReady = false;
  String _mode = 'video'; // 'video' | 'audio'
  String _quality = '1080';
  MediaInfo? _info;

  // Opciones de calidad según el modo.
  static const _videoQualities = <String, String>{
    'best': 'Máxima disponible',
    '2160': '4K (2160p)',
    '1080': 'Full HD (1080p)',
    '720': 'HD (720p)',
    '480': '480p',
    '360': '360p (ligero)',
  };
  static const _audioQualities = <String, String>{
    'best': 'Máxima disponible',
    '320': '320 kbps',
    '192': '192 kbps',
    '128': '128 kbps (ligero)',
  };

  Map<String, String> get _currentQualities =>
      _mode == 'audio' ? _audioQualities : _videoQualities;

  void _onModeChanged(String mode) {
    setState(() {
      _mode = mode;
      // Elegir un valor por defecto válido para el nuevo modo.
      _quality = mode == 'audio' ? '320' : '1080';
    });
  }
  double _progress = 0;
  String _status = 'Iniciando motor…';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
    _progressSub = YtdlpService.progressStream.listen((p) {
      setState(() {
        _progress = p.progress;
        _status = p.line.isNotEmpty
            ? p.line
            : 'Descargando… ${p.progress.toStringAsFixed(1)}%';
      });
    });
  }

  Future<void> _initEngine() async {
    try {
      await YtdlpService.init();
      setState(() {
        _engineReady = true;
        _status = 'Listo. Pega un enlace.';
      });
    } catch (e) {
      setState(() => _status = 'Error al iniciar el motor: $e');
    }
  }

  Future<void> _fetchInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _info = null;
      _status = 'Buscando información…';
    });
    try {
      final info = await YtdlpService.getInfo(url);
      setState(() {
        _info = info;
        _status = 'Encontrado: ${info.title}';
      });
    } catch (e) {
      setState(() => _status = 'No se pudo leer el enlace: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Iniciando descarga…';
    });
    try {
      final dir =
          await YtdlpService.download(url, mode: _mode, quality: _quality);
      setState(() {
        _progress = 100;
        _status = '¡Listo! Guardado en:\n$dir';
      });
    } catch (e) {
      setState(() => _status = 'Falló la descarga: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiwy Downloader'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              enabled: _engineReady && !_busy,
              decoration: InputDecoration(
                labelText: 'Pega el enlace del video o música',
                hintText: 'https://…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: (_engineReady && !_busy) ? _fetchInfo : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'video',
                  label: Text('Video (MP4)'),
                  icon: Icon(Icons.movie),
                ),
                ButtonSegment(
                  value: 'audio',
                  label: Text('Música (MP3)'),
                  icon: Icon(Icons.music_note),
                ),
              ],
              selected: {_mode},
              onSelectionChanged:
                  _busy ? null : (s) => _onModeChanged(s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _quality,
              decoration: const InputDecoration(
                labelText: 'Calidad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.high_quality),
              ),
              items: _currentQualities.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _quality = v ?? _quality),
            ),
            const SizedBox(height: 16),
            if (_info != null) _InfoCard(info: _info!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_engineReady && !_busy) ? _download : null,
              icon: const Icon(Icons.download),
              label: const Text('Descargar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (_busy || _progress > 0)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress / 100 : null,
                minHeight: 8,
              ),
            const SizedBox(height: 12),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final MediaInfo info;
  const _InfoCard({required this.info});

  String _fmtDuration(int s) {
    final d = Duration(seconds: s);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$sec' : '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (info.thumbnail.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  info.thumbnail,
                  width: 100,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.image_not_supported),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info.uploader} · ${_fmtDuration(info.duration)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
