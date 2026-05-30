#!/usr/bin/env bash
# Cross-compile libiox2_bridge.so for aarch64 (Pi 3/4/5).
#
# What this builds: a single .so that exposes the iox2_bridge_* C ABI
# expected by iox2_bridge_ffi.dart, implemented on top of raccoon::Transport
# (the same C++ class the raccoon-lib cli uses on the Pi). We deliberately
# avoid talking to the iceoryx2 C API directly — the previous bridge did
# that and hit a wedging bug on iox2 v0.9.999-dev that raccoon::Transport
# transparently works around in its retry/cleanup loop.
#
# Inputs (override with env vars if your layout differs):
#   RACCOON_LIB        — path to raccoon-lib checkout
#                        (default ../../../../../raccoon-lib)
#   IOX2_INC           — directory containing iox2/iceoryx2.h (C header)
#                        (default $RACCOON_LIB/_skbuild-docker/rust/native/release/iceoryx2-ffi-c-cbindgen/include)
#   IOX2_CXX_INC       — directory containing iox2/iceoryx2.hpp (C++ wrapper)
#                        (default $RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-cxx/include)
#   IOX2_BB_INC        — directory containing iox2/bb/*.hpp (C++ bb headers)
#                        (default $RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-bb/cxx/include)
#   IOX2_FFI_LIB       — static .a containing the iox2 C symbols
#                        (default $RACCOON_LIB/_skbuild-docker/rust/native/release/libiceoryx2_ffi_c.a)
#   IOX2_FFI_SHARED    — runtime .so to ship next to the bridge (linked --no-as-needed)
#                        (default $RACCOON_LIB/_skbuild-docker/rust/native/release/libiceoryx2_ffi_c.so)
#   RACCOON_TRANSPORT  — path to raccoon-transport (default $RACCOON_LIB/raccoon-transport)
#   CXX                — aarch64 cross C++ compiler (default aarch64-linux-gnu-g++)
#
# The script links libiceoryx2_ffi_c.a STATICALLY into the .so so we ship
# one self-contained bridge with the iox2 ABI version that matches the
# cli/reader on the Pi. No more per-host version-skew confusion.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

RACCOON_LIB="${RACCOON_LIB:-$(cd "$SCRIPT_DIR/../../../../../raccoon-lib" && pwd)}"
RACCOON_TRANSPORT="${RACCOON_TRANSPORT:-$RACCOON_LIB/raccoon-transport}"
IOX2_INC="${IOX2_INC:-$RACCOON_LIB/_skbuild-docker/rust/native/release/iceoryx2-ffi-c-cbindgen/include}"
IOX2_CXX_INC="${IOX2_CXX_INC:-$RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-cxx/include}"
IOX2_CXX_SRC_DIR="${IOX2_CXX_SRC_DIR:-$RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-cxx/src}"
IOX2_BB_INC="${IOX2_BB_INC:-$RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-bb/cxx/include}"
# iceoryx2-bb pulls expected_adaption.hpp / optional_adaption.hpp from one
# of two parallel trees depending on whether the user opted into std::expected
# / std::optional at CMake time. raccoon-lib's build sets both to OFF so we
# match that here and add the iox2-variant include dirs.
IOX2_BB_EXPECTED_INC="${IOX2_BB_EXPECTED_INC:-$RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-bb/cxx/variation/expected-iox2-include}"
IOX2_BB_OPTIONAL_INC="${IOX2_BB_OPTIONAL_INC:-$RACCOON_LIB/.cmake-cache-docker/iceoryx2-src/iceoryx2-bb/cxx/variation/optional-iox2-include}"
IOX2_FFI_LIB="${IOX2_FFI_LIB:-$RACCOON_LIB/_skbuild-docker/rust/native/release/libiceoryx2_ffi_c.a}"
IOX2_FFI_SHARED="${IOX2_FFI_SHARED:-$RACCOON_LIB/_skbuild-docker/rust/native/release/libiceoryx2_ffi_c.so}"
CXX="${CXX:-aarch64-linux-gnu-g++}"

# --- Sanity checks -----------------------------------------------------------
for path in \
    "$IOX2_INC/iox2/iceoryx2.h" \
    "$IOX2_CXX_INC/iox2/iceoryx2.hpp" \
    "$IOX2_BB_INC/iox2/bb/layout.hpp" \
    "$IOX2_BB_EXPECTED_INC/iox2/bb/variation/expected_adaption.hpp" \
    "$IOX2_BB_OPTIONAL_INC/iox2/bb/variation/optional_adaption.hpp" \
    "$IOX2_FFI_LIB" \
    "$RACCOON_TRANSPORT/cpp/src/Transport.cpp" \
    "$IOX2_CXX_SRC_DIR/config.cpp" \
    "$IOX2_CXX_SRC_DIR/node_name.cpp" \
    "$RACCOON_TRANSPORT/cpp/include/raccoon/Transport.h"; do
  if [ ! -f "$path" ]; then
    echo "ERROR: required input missing: $path" >&2
    echo "  Override with the matching env var (see header of this script)." >&2
    exit 1
  fi
done

# We also need a matching runtime .so so flutter-pi can dlopen() iox2 symbols
# at runtime. If a previously-committed copy is here we keep it; otherwise
# pull a fresh one from raccoon-lib's build tree.
if [ ! -f libiceoryx2_ffi_c.so ] || [ "$IOX2_FFI_SHARED" -nt libiceoryx2_ffi_c.so ]; then
  if [ -f "$IOX2_FFI_SHARED" ]; then
    cp -v "$IOX2_FFI_SHARED" libiceoryx2_ffi_c.so
  fi
fi

echo "▶ Building libiox2_bridge.so with $CXX"
echo "  raccoon-transport: $RACCOON_TRANSPORT"
echo "  iox2 C header:     $IOX2_INC"
echo "  iox2 C++ headers:  $IOX2_CXX_INC + $IOX2_BB_INC"
echo "  iox2 static lib:   $IOX2_FFI_LIB"

# Compile both translation units, then link as one .so. We bundle the iox2
# C FFI symbols statically so there is no chance of pulling a stale
# system-wide libiceoryx2_ffi_c.so at dlopen time (libiox2_bridge.so still
# has libiceoryx2_ffi_c.so as a NEEDED entry — see below — so we keep that
# shared object next to it as a runtime dep belt-and-braces).
# The iceoryx2 C++ wrapper has out-of-line definitions across ~44 .cpp
# files. Compile them all into the bridge so the public templates (Node,
# Config, ServiceBuilder*) link cleanly; otherwise dlopen fails with
# undefined symbols on iox2::Config::global_config() and friends.
CXX_WRAPPER_SRCS=()
while IFS= read -r f; do
  CXX_WRAPPER_SRCS+=("$f")
done < <(find "$IOX2_CXX_SRC_DIR" -maxdepth 1 -name '*.cpp' | sort)

"$CXX" -std=c++20 -fPIC -O2 -Wall -Wextra \
  -I"$IOX2_INC" -I"$IOX2_CXX_INC" -I"$IOX2_BB_INC" \
  -I"$IOX2_BB_EXPECTED_INC" -I"$IOX2_BB_OPTIONAL_INC" \
  -I"$RACCOON_TRANSPORT/cpp/include" \
  -I"$SCRIPT_DIR" \
  -shared \
  "$SCRIPT_DIR/iox2_bridge.cpp" \
  "$RACCOON_TRANSPORT/cpp/src/Transport.cpp" \
  "${CXX_WRAPPER_SRCS[@]}" \
  -Wl,--whole-archive "$IOX2_FFI_LIB" -Wl,--no-whole-archive \
  -lpthread -ldl -lm \
  -Wl,-rpath,'$ORIGIN' \
  -o libiox2_bridge.so

echo "  built $(file libiox2_bridge.so | cut -d, -f1-3)"
echo "  size:   $(stat -c%s libiox2_bridge.so) bytes"
