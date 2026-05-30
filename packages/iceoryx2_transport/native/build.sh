#!/usr/bin/env bash
# Cross-compile libiox2_bridge.so for aarch64 (Pi 3/4/5).
#
# The bridge is now a thin C++ Dart-FFI wrapper around raccoon_ring (the
# in-tree SHM ring buffer that replaced iceoryx2). Two source files,
# no Rust toolchain, no vendored iceoryx2 wrapper, no separate
# libiceoryx2_ffi_c.so to ship next to it.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f raccoon_ring.h ] || [ ! -f raccoon_ring.c ]; then
  echo "ERROR: raccoon_ring.{h,c} missing from $SCRIPT_DIR" >&2
  exit 1
fi
if [ ! -f iox2_bridge.cpp ]; then
  echo "ERROR: iox2_bridge.cpp missing" >&2
  exit 1
fi

CXX="${CXX:-aarch64-linux-gnu-g++}"
CC_CROSS="${CC_CROSS:-aarch64-linux-gnu-gcc}"

echo "▶ Building libiox2_bridge.so (rrb backend) with $CXX"

# raccoon_ring is plain C11. Compile to PIC .o, link into the bridge .so.
"$CC_CROSS" -std=c11 -fPIC -O2 -Wall -Wextra -c raccoon_ring.c -o raccoon_ring.o

"$CXX" -std=c++17 -fPIC -O2 -Wall -Wextra \
  -I"$SCRIPT_DIR" \
  -shared iox2_bridge.cpp raccoon_ring.o \
  -lpthread \
  -o libiox2_bridge.so

rm -f raccoon_ring.o

echo "  built $(file libiox2_bridge.so | cut -d, -f1-3)"
echo "  size:   $(stat -c%s libiox2_bridge.so) bytes"
echo "  NEEDED: $(readelf -d libiox2_bridge.so | awk '/NEEDED/ {print $5}' | xargs)"
