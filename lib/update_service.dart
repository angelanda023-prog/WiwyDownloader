import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';

/// Datos de una versión disponible en el servidor.
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String notes;
  final String apkUrl;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        versionCode: (j['versionCode'] as num).toInt(),
        versionName: j['versionName']?.toString() ?? '',
        notes: j['notes']?.toString() ?? '',
        apkUrl: j['apkUrl']?.toString() ?? '',
      );
}

/// Maneja las actualizaciones OTA: buscar, descargar e instalar el APK.
class UpdateService {
  /// versionCode (build number) instalado actualmente.
  static Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// versionName (p. ej. "1.0.0") instalado actualmente.
  static Future<String> currentVersionName() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Consulta el manifiesto remoto.
  /// Devuelve [UpdateInfo] si hay una versión más nueva; `null` si estás al día.
  ///
  /// Compara por **versionName** (semver "1.0.1") y NO por versionCode, porque
  /// `--split-per-abi` le suma 1000·índiceABI al versionCode (arm64 = +2000),
  /// lo que rompería la comparación numérica.
  static Future<UpdateInfo?> checkForUpdate() async {
    final res = await http
        .get(Uri.parse(AppConfig.updateManifestUrl))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('No se pudo consultar actualizaciones (${res.statusCode})');
    }
    final info =
        UpdateInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    final current = await currentVersionName();
    return _isNewer(info.versionName, current) ? info : null;
  }

  /// ¿[remote] es una versión semántica mayor que [local]? (p. ej. 1.0.1 > 1.0.0)
  static bool _isNewer(String remote, String local) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final r = parse(remote);
    final l = parse(local);
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  /// Descarga el APK (con progreso 0..1) y lanza el instalador del sistema.
  ///
  /// El usuario verá la pantalla nativa de Android para confirmar la
  /// instalación (requiere permiso de "instalar apps desconocidas").
  static Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    // 1. Permiso para instalar APKs (Android 8+).
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        throw Exception(
            'Necesitas permitir "Instalar apps desconocidas" para actualizar.');
      }
    }

    // 2. Descargar a la carpeta temporal.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/WiwyDownloader-${info.versionName}.apk');

    final request = http.Request('GET', Uri.parse(info.apkUrl));
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Fallo al descargar el APK (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();

    // 3. Abrir el APK → dispara el instalador del sistema.
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception('No se pudo abrir el instalador: ${result.message}');
    }
  }
}
