#!/usr/bin/env bash
# Release build with Dart AOT obfuscation (XRW-23).
#
# The Flutter tool always passes -Pdart-obfuscation=false unless --obfuscate
# is given on the command line (gradle.properties cannot enable it), so all
# release builds should go through this script.
#
# Obfuscated symbol maps land in build/symbols/ — they are needed to
# symbolicate release stack traces. Keep them private: never commit or ship.
set -euo pipefail
cd "$(dirname "$0")/.."
exec flutter build apk --release --obfuscate \
  --split-debug-info=build/symbols/android \
  --extra-gen-snapshot-options=--strip \
  "$@"
