#!/usr/bin/env bash
#
# Compila el APK, regenerando primero el código generado.
#
# ## Por qué existe
#
# `*.g.dart` y `*.freezed.dart` están en `.gitignore`, y `flutter build` **no**
# corre `build_runner`. Un clon nuevo —o un árbol donde se hizo `git pull` de
# cambios que mueven un provider— compila contra código generado ausente o de
# antes del pull, y falla con errores que no nombran la causa:
#
#     Error when reading 'lib/core/data/especialidades_catalogo.g.dart'
#     Undefined name 'catalogoEspecialidades'
#
# El segundo es el peor: un `.g.dart` viejo que todavía declara un símbolo que
# ya se movió de archivo.
#
# Le costó dos builds fallidos al usuario antes de que esto existiera. Este
# script existe para que el paso no dependa de acordarse.
#
# (`--delete-conflicting-outputs` **no** va: build_runner 2.15 lo removió y
# hoy solo emite un warning de opción ignorada. Verificado, no supuesto.)
#
# ## Uso
#
#   ./scripts/build_apk.sh                          # emulador (10.0.2.2)
#   ./scripts/build_apk.sh 192.168.1.50             # teléfono en la LAN
#   ./scripts/build_apk.sh 192.168.1.50 salida.apk  # y con nombre propio
set -euo pipefail

cd "$(dirname "$0")/.."

HOST="${1:-10.0.2.2}"
DESTINO="${2:-}"
URL="http://${HOST}:3000/api"

echo "── dependencias ───────────────────────────────────────"
flutter pub get

echo
echo "── código generado ────────────────────────────────────"
# Sin esto el build falla, o peor: compila con un provider que ya no existe.
dart run build_runner build

echo
echo "── análisis ───────────────────────────────────────────"
# Antes de esperar los ~13 min del APK. Un error acá lo ahorra entero.
flutter analyze

echo
echo "── APK contra ${URL} ──────────────────────────────────"
flutter build apk --release --dart-define=API_BASE_URL="$URL"

APK=build/app/outputs/flutter-apk/app-release.apk

# La URL es una constante de compilación: si el `--dart-define` no llegó, la
# app arranca y falla al primer pedido. Se comprueba en el binario, no en el
# comando que se creyó haber corrido.
echo
echo "── verificación ───────────────────────────────────────"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -o -q -d "$TMP" "$APK" lib/arm64-v8a/libapp.so
if grep -aqF "$URL" "$TMP/lib/arm64-v8a/libapp.so"; then
  echo "   URL compilada dentro del APK: $URL"
else
  echo "   ERROR: el APK no contiene $URL" >&2
  exit 1
fi

if [ -n "$DESTINO" ]; then
  cp "$APK" "$DESTINO"
  APK="$DESTINO"
fi

echo
echo "APK LISTO: $APK"
