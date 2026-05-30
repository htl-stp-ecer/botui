#!/usr/bin/env bash
set -e

BUILD_NUMBER="${BUILD_NUMBER:-0}"

# Use fvm prefix when available, fall back to plain flutter/dart in CI
if command -v fvm &>/dev/null; then
  FLUTTER="fvm flutter"
  DART="fvm dart"
else
  FLUTTER="flutter"
  DART="dart"
fi

$FLUTTER pub get
$FLUTTER pub run build_runner build -d
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FVM_VERSION=$(python3 -c "import json; print(json.load(open('$SCRIPT_DIR/.fvmrc'))['flutter'])" 2>/dev/null || true)
FVM_CACHE="${FVM_HOME:-$HOME/fvm}/versions"
if [ -n "$FVM_VERSION" ] && [ -d "$FVM_CACHE/$FVM_VERSION/bin" ]; then
  export PATH="$FVM_CACHE/$FVM_VERSION/bin:$PATH"
fi
$DART pub global activate flutterpi_tool
flutterpi_tool build --arch=arm64 --cpu=pi3 --release

# Copy the bridge .so into the build output. The bridge now statically
# embeds raccoon_ring (the SHM transport that replaced iceoryx2), so
# there is no libiceoryx2_ffi_c.so to ship alongside it any more — the
# bridge has no dynamic deps beyond libc/libstdc++/libgcc_s.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/flutter-pi/pi3-64"
SO_DIR="$SCRIPT_DIR/packages/iceoryx2_transport/native"
if [ -d "$BUILD_DIR" ]; then
  if [ -f "$SO_DIR/libiox2_bridge.so" ]; then
    cp "$SO_DIR/libiox2_bridge.so" "$BUILD_DIR/"
    echo "Copied libiox2_bridge.so to build output"
  else
    echo "ERROR: libiox2_bridge.so not built — run packages/iceoryx2_transport/native/build.sh first" >&2
    exit 1
  fi
  # Best-effort cleanup of stale libiceoryx2_ffi_c.so left from old builds
  # so flutter-pi doesn't dlopen the old one accidentally.
  rm -f "$BUILD_DIR/libiceoryx2_ffi_c.so"
fi
