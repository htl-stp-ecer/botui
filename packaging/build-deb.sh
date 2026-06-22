#!/usr/bin/env bash
# build-deb.sh — assemble an installable .deb for the StpVelox flutter-pi UI.
#
# Produces a package that mirrors what install.py used to do by hand:
#   * drops the flutter-pi build output into /home/pi/stp-velox/
#   * writes the version file raccoon-server reads
#   * installs the flutter-ui systemd unit
#   * (postinst) daemon-reload + enable + restart flutter-ui
#   * (prerm)    stop + disable on removal
#
# Usage:
#   packaging/build-deb.sh <version> [build_dir] [output.deb]
#
#   version    Debian version string, e.g. 1.0.42
#   build_dir  flutter-pi build output (default: build/flutter-pi/pi3-64)
#   output     output path (default: stp-velox_<version>_arm64.deb)
set -euo pipefail

VERSION="${1:?usage: build-deb.sh <version> [build_dir] [output.deb]}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${2:-$REPO_DIR/build/flutter-pi/pi3-64}"
OUTPUT="${3:-$REPO_DIR/stp-velox_${VERSION}_arm64.deb}"

ARCH="arm64"
PKG="stp-velox"
APP_DIR="home/pi/stp-velox"          # install target (matches the systemd unit + raccoon-server)
UNIT_SRC="$REPO_DIR/systemd/flutter-ui.service"

if [ ! -f "$BUILD_DIR/app.so" ]; then
  echo "ERROR: no flutter-pi build found in $BUILD_DIR (missing app.so)" >&2
  exit 1
fi
if [ ! -f "$UNIT_SRC" ]; then
  echo "ERROR: systemd unit not found: $UNIT_SRC" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# --- payload: flutter build output -> /home/pi/stp-velox ---
mkdir -p "$STAGE/$APP_DIR"
cp -r "$BUILD_DIR/." "$STAGE/$APP_DIR/"
# Drop incremental-build bookkeeping that has no business in a release.
rm -f "$STAGE/$APP_DIR/.last_build_id"
printf '%s' "$VERSION" > "$STAGE/$APP_DIR/version"

# --- systemd unit -> /lib/systemd/system ---
mkdir -p "$STAGE/lib/systemd/system"
cp "$UNIT_SRC" "$STAGE/lib/systemd/system/flutter-ui.service"

# --- control metadata ---
INSTALLED_KB="$(du -sk "$STAGE" | cut -f1)"
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Architecture: $ARCH
Maintainer: HTL St. Pölten ECER <noreply@htl-stp-ecer.dev>
Section: misc
Priority: optional
Installed-Size: $INSTALLED_KB
Depends: libc6, libstdc++6, libgcc-s1
Description: StpVelox robotics touch UI (flutter-pi)
 Dynamic Flutter UI for the Raccoon / wombat robotics platform, rendered by
 flutter-pi on the embedded 800x480 display. Installs the application bundle
 to /home/pi/stp-velox and runs it as the flutter-ui systemd service.
EOF

# --- maintainer scripts ---
cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

# A previous install.py run may have left a hand-placed unit in
# /etc/systemd/system; it would shadow the packaged one. Remove it if it is a
# plain file (not an admin-managed symlink/override).
STALE=/etc/systemd/system/flutter-ui.service
if [ -f "$STALE" ] && [ ! -L "$STALE" ]; then
    rm -f "$STALE"
fi

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
    systemctl enable flutter-ui.service || true
    systemctl restart flutter-ui.service || true
fi

exit 0
EOF

cat > "$STAGE/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = remove ] || [ "$1" = purge ]; then
    if [ -d /run/systemd/system ]; then
        systemctl stop flutter-ui.service || true
        systemctl disable flutter-ui.service || true
    fi
fi

exit 0
EOF

cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = remove ] || [ "$1" = purge ]; then
    if [ -d /run/systemd/system ]; then
        systemctl daemon-reload || true
    fi
fi

exit 0
EOF

chmod 0755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/DEBIAN/postrm"

dpkg-deb --root-owner-group --build "$STAGE" "$OUTPUT"
echo "Built $OUTPUT"
