#!/usr/bin/env bash
set -euo pipefail

dart format --set-exit-if-changed lib test
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage

# Cobertura minima por fase
pct=$(lcov --summary coverage/lcov.info 2>&1 | grep -oP 'lines\.*: \K[0-9.]+')
awk -v p="$pct" 'BEGIN { exit (p >= 70) ? 0 : 1 }' \
  || { echo "FALLA: cobertura ${pct}% < 70%"; exit 1; }

echo "VERIFY OK"
