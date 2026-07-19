/// Configuración global de la app.
class AppConfig {
  /// URL del manifiesto de actualizaciones (JSON), en la rama main del repo
  /// público. Como el repo es público, tanto este JSON como los APKs de las
  /// Releases se descargan sin autenticación.
  ///
  /// Formato del JSON (archivo update.json en la raíz del repo):
  /// {
  ///   "versionCode": 2,
  ///   "versionName": "1.0.1",
  ///   "notes": "Qué cambió en esta versión",
  ///   "apkUrl": "https://github.com/.../releases/download/v1.0.1/WiwyDownloader-1.0.1.apk"
  /// }
  static const String updateManifestUrl =
      'https://raw.githubusercontent.com/angelanda023-prog/WiwyDownloader/main/update.json';
}
