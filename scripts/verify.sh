#!/usr/bin/env bash
# Puerta de calidad. Todo o nada: si esto no sale en 0, no se pasa al gate.
set -euo pipefail

# RNF-14 pide 80%. El piso arranco en 70 mientras se construian los modulos;
# desde F13 la cobertura real es 85%, asi que el piso sube al valor del
# requerimiento: dejarlo en 70 permitiria caer por debajo de lo exigido sin
# que la puerta dijera nada.
COBERTURA_MINIMA=${COBERTURA_MINIMA:-80}

cd "$(dirname "$0")/.."

command -v flutter >/dev/null 2>&1 || {
  echo "FALLA: flutter no esta en el PATH." >&2
  echo "  export PATH=\"/c/src/flutter/bin:\$PATH\"" >&2
  exit 1
}

echo "── format ─────────────────────────────────────────────"
dart format --set-exit-if-changed lib test

echo "── codegen ────────────────────────────────────────────"
# Sin --delete-conflicting-outputs: build_runner 2.15 lo elimino y solo
# emite un warning. El borrado de salidas en conflicto ya es el default.
dart run build_runner build

echo "── analyze ────────────────────────────────────────────"
flutter analyze --fatal-infos --fatal-warnings

echo "── test ───────────────────────────────────────────────"
# --exclude-tags servidor: las pruebas contra un backend real viven en
# test_servidor/, que `flutter test` no recorre. Esto es el segundo cierre,
# por si alguna aterriza bajo test/ con el tag puesto.
flutter test --coverage --exclude-tags servidor

echo "── cobertura ──────────────────────────────────────────"
# Se lee lcov.info directo con awk en vez de usar `lcov --summary`.
#
# El script original dependia de `lcov` (no viene en Windows) y de
# `grep -oP`, que en Git Bash falla con "supports only unibyte and UTF-8
# locales". Asi corre igual en Windows, Linux y dentro del contenedor,
# sin instalar nada.
#
# Los archivos generados quedan fuera del calculo: nadie escribe pruebas
# para un .g.dart, y contarlos mide la suerte del generador, no la del
# codigo. Es el mismo criterio con que se excluyen de analysis_options.
[ -f coverage/lcov.info ] || {
  echo "FALLA: no se genero coverage/lcov.info" >&2
  exit 1
}

pct=$(awk -F: '
  /^SF:/ { generado = ($0 ~ /\.(g|freezed)\.dart$/) }
  /^LF:/ { if (!generado) encontradas += $2 }
  /^LH:/ { if (!generado) alcanzadas  += $2 }
  END {
    if (encontradas == 0) { print "0.0"; exit }
    printf "%.1f", (alcanzadas / encontradas) * 100
  }
' coverage/lcov.info)

awk -v p="$pct" -v min="$COBERTURA_MINIMA" \
  'BEGIN { exit (p >= min) ? 0 : 1 }' \
  || {
    echo "FALLA: cobertura ${pct}% < ${COBERTURA_MINIMA}%" >&2
    exit 1
  }

echo "cobertura ${pct}% (minimo ${COBERTURA_MINIMA}%)"
echo
echo "VERIFY OK"
