# Wiwy Downloader

App multiplataforma (Android · Windows · Mac) para descargar **video y música de casi cualquier página**, construida con Flutter sobre el motor open-source [yt-dlp](https://github.com/yt-dlp/yt-dlp).

> ⚠️ **Uso personal.** Descargar contenido puede infringir los Términos de Servicio de algunos sitios. Úsalo solo con material que tengas derecho a descargar.

## Estado actual

| Plataforma | Estado | Motor |
|-----------|--------|-------|
| Android   | ✅ Funcional | [`youtubedl-android`](https://github.com/yausername/youtubedl-android) (yt-dlp + ffmpeg empaquetados) |
| Windows   | 🚧 Pendiente | binario `yt-dlp` vía `Process` |
| macOS     | 🚧 Pendiente | binario `yt-dlp` vía `Process` |

## Funciones

- Pegar cualquier enlace y previsualizar título, autor, duración y miniatura.
- Descargar como **video (MP4)** o **música (MP3)**.
- **Selección de calidad**: 360p–4K en video, 128–320 kbps en audio.
- Progreso en tiempo real vía `EventChannel`.
- Soporta 1.800+ sitios + extractor genérico para páginas desconocidas.

## Arquitectura

```
Flutter (UI, Dart)
   │  MethodChannel  "wiwy/ytdlp"           → comandos (init, getInfo, download)
   │  EventChannel   "wiwy/ytdlp/progress"  → progreso
   ▼
Kotlin (MainActivity)  →  youtubedl-android (yt-dlp/ffmpeg nativos)
```

- Lógica Flutter: [`lib/main.dart`](lib/main.dart), [`lib/ytdlp_service.dart`](lib/ytdlp_service.dart)
- Puente nativo: [`android/app/src/main/kotlin/com/wiwy/wiwy_downloader/MainActivity.kt`](android/app/src/main/kotlin/com/wiwy/wiwy_downloader/MainActivity.kt)

## Cómo ejecutar

```bash
flutter pub get
flutter run              # con un dispositivo/emulador Android conectado
# o generar el APK:
flutter build apk --debug
```

Los archivos se guardan en `Android/data/com.wiwy.wiwy_downloader/files/Download`.

## Hoja de ruta

- [ ] Exportar descargas a la carpeta pública *Descargas* (MediaStore).
- [ ] Motor de escritorio (Windows/Mac) con binario yt-dlp.
- [ ] Cola de descargas y notificaciones.
- [ ] Icono y nombre de app personalizados.
