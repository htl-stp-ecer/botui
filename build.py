#!/usr/bin/env python3
"""build.py — build the botui .deb for the Pi (flutter-pi, arm64) inside Docker.

Nothing is installed on the host and nothing is written outside ./builds/: the
sources are copied into the container, built there, and only the finished .deb plus
builds/manifest.json come out. CI runs exactly this script.

Usage:
    python3 build.py                  # local build, version 0.0
    python3 build.py --version 81     # release build (CI)

Result:
    builds/botui_<version>_arm64.deb
    builds/manifest.json

The host only needs Docker and Python. Flutter, flutterpi_tool, the aarch64 cross
compiler and dpkg-deb are in the image (see Dockerfile).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILDS = ROOT / "builds"
IMAGE = "botui-build"
VERSION_PATTERN = re.compile(r"^[0-9]+(\.[0-9]+)*$")

# Installed on the Pi: /home/pi/stp-velox (the systemd unit and raccoon-server use this path).
APP_DIR = "home/pi/stp-velox"
BRIDGE_DIR = Path("packages/raccoon-transport/cpp/bridge")
FLUTTER_OUTPUT = Path("build/flutter-pi/pi3-64")

# Top-level entries that are not copied into the container.
EXCLUDE = {".git", "build", "builds", ".dart_tool", "coverage", "__pycache__"}

POSTINST = """#!/bin/sh
set -e

# A unit placed by hand in /etc/systemd/system would shadow the packaged one.
# Remove it if it is a plain file (not an admin-managed symlink/override).
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
"""

PRERM = """#!/bin/sh
set -e

if [ "$1" = remove ] || [ "$1" = purge ]; then
    if [ -d /run/systemd/system ]; then
        systemctl stop flutter-ui.service || true
        systemctl disable flutter-ui.service || true
    fi
fi

exit 0
"""

POSTRM = """#!/bin/sh
set -e

if [ "$1" = remove ] || [ "$1" = purge ]; then
    if [ -d /run/systemd/system ]; then
        systemctl daemon-reload || true
    fi
fi

exit 0
"""

CONTROL = """Package: botui
Version: {version}
Architecture: arm64
Maintainer: HTL St. Pölten ECER <noreply@htl-stp-ecer.dev>
Section: misc
Priority: optional
Installed-Size: {size_kb}
Depends: libc6, libstdc++6, libgcc-s1
Replaces: stp-velox
Conflicts: stp-velox
Description: StpVelox robotics touch UI (flutter-pi)
 Dynamic Flutter UI for the Raccoon / wombat robotics platform, rendered by
 flutter-pi on the embedded 800x480 display. Installs the application bundle
 to /home/pi/stp-velox and runs it as the flutter-ui systemd service.
"""


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def run(command: list[str], **kwargs) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, check=True, **kwargs)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# ── inside the container ─────────────────────────────────────────────────


def build_deb(build_dir: Path, unit: Path, version: str, output: Path) -> None:
    """Assemble botui_<version>_arm64.deb from the flutter-pi build output."""
    stage = Path(tempfile.mkdtemp())
    try:
        app = stage / APP_DIR
        shutil.copytree(build_dir, app)
        # Incremental-build bookkeeping has no business in a release.
        (app / ".last_build_id").unlink(missing_ok=True)
        (app / "version").write_text(version)

        unit_dir = stage / "lib/systemd/system"
        unit_dir.mkdir(parents=True)
        shutil.copy(unit, unit_dir / "flutter-ui.service")

        size_kb = int(subprocess.run(["du", "-sk", str(stage)], capture_output=True, text=True, check=True)
                      .stdout.split()[0])
        debian = stage / "DEBIAN"
        debian.mkdir()
        (debian / "control").write_text(CONTROL.format(version=version, size_kb=size_kb))
        for name, text in (("postinst", POSTINST), ("prerm", PRERM), ("postrm", POSTRM)):
            (debian / name).write_text(text)
            (debian / name).chmod(0o755)

        run(["dpkg-deb", "--root-owner-group", "--build", str(stage), str(output)])
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def run_in_container(version: str, owner: str) -> None:
    """The actual build. Runs inside the image as root; /src is the repository, read-only."""
    src = Path("/src")
    work = Path("/tmp/work")
    shutil.copytree(src, work, ignore=lambda directory, names: (
        [n for n in names if n in EXCLUDE] if Path(directory) == src else []
    ))
    os.chdir(work)
    # `dart pub global activate` puts the executables here; `dart pub global run` does not work
    # for flutterpi_tool because it needs the Flutter SDK.
    os.environ["PATH"] += os.pathsep + os.environ.get("PUB_CACHE", "/root/.pub-cache") + "/bin"

    run(["flutter", "pub", "get"])
    run(["flutter", "pub", "run", "build_runner", "build", "-d"])
    run(["dart", "pub", "global", "activate", "flutterpi_tool"])
    run(["flutterpi_tool", "build",
         "--arch=arm64", "--cpu=pi3", "--release", f"--dart-define=APP_VERSION={version}"])

    # The bridge statically embeds raccoon_ring (the shared-memory transport), so beyond
    # libc/libstdc++/libgcc_s it needs nothing next to it. Always rebuilt: it takes a second
    # and a stale .so after a submodule bump has bitten us before.
    run(["bash", "build.sh"], cwd=work / BRIDGE_DIR)
    bridge = work / BRIDGE_DIR / "libraccoon_ring_bridge.so"
    if not bridge.is_file():
        fail(f"{bridge.name} could not be built")
    output_dir = work / FLUTTER_OUTPUT
    shutil.copy(bridge, output_dir)
    # Stale libraries of the earlier iceoryx2 bridge must never be dlopen()ed.
    for stale in ("libiox2_bridge.so", "libiceoryx2_ffi_c.so"):
        (output_dir / stale).unlink(missing_ok=True)
    if not (output_dir / "app.so").is_file():
        fail(f"no flutter-pi build in {FLUTTER_OUTPUT} (missing app.so)")

    deb = Path("/out") / f"botui_{version}_arm64.deb"
    build_deb(output_dir, work / "systemd/flutter-ui.service", version, deb)
    uid, gid = owner.split(":")
    os.chown(deb, int(uid), int(gid))


# ── on the host ──────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the botui .deb in Docker.")
    parser.add_argument("--version", default="0.0", help="version of the package (default: 0.0 = local build)")
    parser.add_argument("--image", help="use this Docker image instead of building ./Dockerfile")
    parser.add_argument(
        "--cache-dir",
        default=str(Path.home() / ".cache" / "raccoon-build" / "botui"),
        help="pub cache kept between builds (default: %(default)s)",
    )
    parser.add_argument("--in-container", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--owner", default="0:0", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if not VERSION_PATTERN.match(args.version):
        fail(f"--version must be numbers separated by dots (got {args.version!r})")

    if args.in_container:
        run_in_container(args.version, args.owner)
        return

    if not shutil.which("docker"):
        fail("docker not found. The build runs in a container so the host stays clean.")
    if not (ROOT / BRIDGE_DIR / "build.sh").is_file():
        fail("packages/raccoon-transport is empty. Run `git submodule update --init`.")

    image = args.image
    if not image:
        image = IMAGE
        print(f"▶ Building Docker image {image}")
        subprocess.run(["docker", "build", "-t", image, "-f", str(ROOT / "Dockerfile"), str(ROOT)], check=True)

    BUILDS.mkdir(exist_ok=True)
    for stale in [*BUILDS.glob("botui_*_arm64.deb"), BUILDS / "manifest.json"]:
        stale.unlink(missing_ok=True)
    cache = Path(args.cache_dir)
    (cache / "pub").mkdir(parents=True, exist_ok=True)

    print(f"▶ Building botui {args.version}")
    # Root inside the container: the Flutter SDK in the image is root-owned and writes its cache.
    # The result is handed to the host user at the end of the build.
    subprocess.run(
        [
            "docker", "run", "--rm",
            "-e", "PUB_CACHE=/cache/pub",
            "-v", f"{ROOT}:/src:ro",
            "-v", f"{BUILDS}:/out",
            "-v", f"{cache}:/cache",
            image,
            "python3", "/src/build.py", "--in-container",
            "--version", args.version, "--owner", f"{os.getuid()}:{os.getgid()}",
        ],
        check=True,
    )

    debs = sorted(BUILDS.glob("botui_*_arm64.deb"))
    if len(debs) != 1:
        fail(f"expected exactly one .deb in {BUILDS}, found {len(debs)}")
    manifest = {
        "name": "botui",
        "version": args.version,
        "files": [{"name": debs[0].name, "kind": "deb", "sha256": sha256(debs[0])}],
    }
    (BUILDS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"✓ {debs[0].relative_to(ROOT)}")


if __name__ == "__main__":
    main()
