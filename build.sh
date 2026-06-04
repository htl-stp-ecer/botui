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

# Copy the bridge .so into the build output. The bridge statically embeds
# raccoon_ring (the SHM transport from raccoon-transport), so there are
# no extra deps to ship alongside it beyond libc/libstdc++/libgcc_s.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/flutter-pi/pi3-64"
SO_DIR="$SCRIPT_DIR/packages/raccoon-transport/cpp/bridge"
if [ -d "$BUILD_DIR" ]; then
  # Always rebuild the bridge — it's a 2-file aarch64 cross-compile
  # (~1 s) and skipping it has bitten us before when the submodule was
  # bumped but the cached .so wasn't rebuilt.
  (cd "$SO_DIR" && ./build.sh)
  if [ -f "$SO_DIR/libraccoon_ring_bridge.so" ]; then
    cp "$SO_DIR/libraccoon_ring_bridge.so" "$BUILD_DIR/"
    echo "Copied libraccoon_ring_bridge.so to build output"
  else
    echo "ERROR: libraccoon_ring_bridge.so could not be built — see packages/raccoon-transport/cpp/bridge/build.sh" >&2
    exit 1
  fi
  # Best-effort cleanup of stale .so files from the previous iceoryx2-named
  # build so flutter-pi never dlopen()s an outdated one.
  rm -f "$BUILD_DIR/libiox2_bridge.so" "$BUILD_DIR/libiceoryx2_ffi_c.so"
fi
