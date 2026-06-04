#!/usr/bin/env bash
# Cross-compile libraccoon_ring_bridge.so for aarch64 (Pi 3/4/5).
#
# The bridge is a thin C++ Dart-FFI wrapper around raccoon_ring (the
# SHM ring buffer transport from the official raccoon-transport
# submodule). Two source files, no Rust toolchain, no separate
# .so to ship next to it.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Pull raccoon_ring from the raccoon-transport submodule. Having one
# canonical source means the bridge and any other consumer in this repo
# always speak the exact same on-wire ring layout.
RRB_ROOT="$SCRIPT_DIR/../../raccoon-transport/cpp"
RRB_INC="$RRB_ROOT/include"
RRB_SRC="$RRB_ROOT/src/raccoon_ring.c"

if [ ! -f "$RRB_SRC" ] || [ ! -f "$RRB_INC/raccoon/raccoon_ring.h" ]; then
  echo "ERROR: raccoon_ring source not found in submodule at $RRB_ROOT" >&2
  echo "  Did you run: git submodule update --init --recursive ?" >&2
  exit 1
fi
if [ ! -f raccoon_ring_bridge.cpp ]; then
  echo "ERROR: raccoon_ring_bridge.cpp missing" >&2
  exit 1
fi

CXX="${CXX:-aarch64-linux-gnu-g++}"
CC_CROSS="${CC_CROSS:-aarch64-linux-gnu-gcc}"

echo "▶ Building libraccoon_ring_bridge.so with $CXX"

# raccoon_ring is plain C11. Compile to PIC .o, link into the bridge .so.
"$CC_CROSS" -std=c11 -fPIC -O2 -Wall -Wextra \
  -I"$RRB_INC" \
  -c "$RRB_SRC" -o raccoon_ring.o

"$CXX" -std=c++17 -fPIC -O2 -Wall -Wextra \
  -I"$SCRIPT_DIR" -I"$RRB_INC" \
  -shared raccoon_ring_bridge.cpp raccoon_ring.o \
  -lpthread \
  -o libraccoon_ring_bridge.so

rm -f raccoon_ring.o

echo "  built $(file libraccoon_ring_bridge.so | cut -d, -f1-3)"
echo "  size:   $(stat -c%s libraccoon_ring_bridge.so) bytes"
echo "  NEEDED: $(readelf -d libraccoon_ring_bridge.so | awk '/NEEDED/ {print $5}' | xargs)"
