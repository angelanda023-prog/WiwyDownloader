/// Configuración global de la app.
class AppConfig {
  /// URL del manifiesto de actualizaciones (JSON).
  ///
  /// Debe ser accesible SIN autenticación. Como el repo de código es privado,
  /// lo más simple es publicar el manifiesto y el APK en un repo/Gist PÚBLICO
  /// dedicado solo a releases, o en cualquier hosting estático.
  ///
  /// Formato esperado del JSON:
  /// {
  ///   "versionCode": 2,
  ///   "versionName": "1.0.1",
  ///   "notes": "Qué cambió en esta versión",
  ///   "apkUrl": "https://.../wiwy-downloader-1.0.1.apk"
  /// }
  ///
  /// TODO: reemplaza esta URL por la tuya.
  static const String updateManifestUrl =
      'https://raw.githubusercontent.com/angelanda023-prog/wiwy-releases/main/update.json';
}
