#!/usr/bin/env bash
# Publica una nueva versión de Wiwy Downloader para las actualizaciones OTA.
#
# Uso:
#   ./scripts/publicar_version.sh 1.0.1 "Arreglé tal cosa y mejoré tal otra"
#
# Antes de ejecutar:
#   1. Sube el versionName y versionCode en pubspec.yaml (línea `version: 1.0.1+2`).
#      El número después del + (versionCode) DEBE ser mayor que el anterior.
#
# El script: compila el APK release, crea la Release en GitHub con el APK,
# actualiza update.json y lo sube. Las apps instaladas verán la actualización.

set -e

VERSION_NAME="$1"
NOTES="${2:-Mejoras y correcciones.}"

if [ -z "$VERSION_NAME" ]; then
  echo "Uso: $0 <versionName> [notas]"
  echo "Ejemplo: $0 1.0.1 \"Arreglé la descarga de audio\""
  exit 1
fi

REPO="angelanda023-prog/WiwyDownloader"
APK_NAME="WiwyDownloader-${VERSION_NAME}.apk"

# versionCode = el número tras el + en pubspec.yaml
VERSION_CODE="$(grep '^version:' pubspec.yaml | sed 's/.*+//')"

echo "==> Compilando APK release v${VERSION_NAME} (code ${VERSION_CODE})…"
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$APK_NAME"

echo "==> Creando Release v${VERSION_NAME} en GitHub…"
gh release create "v${VERSION_NAME}" "$APK_NAME" \
  --repo "$REPO" \
  --title "v${VERSION_NAME}" \
  --notes "$NOTES"

echo "==> Actualizando update.json…"
cat > update.json <<EOF
{
  "versionCode": ${VERSION_CODE},
  "versionName": "${VERSION_NAME}",
  "notes": "${NOTES}",
  "apkUrl": "https://github.com/${REPO}/releases/download/v${VERSION_NAME}/${APK_NAME}"
}
EOF

git add update.json pubspec.yaml
git commit -m "Release v${VERSION_NAME}"
git push origin main

rm -f "$APK_NAME"
echo "✅ Publicado. Las apps instaladas verán la actualización a v${VERSION_NAME}."
