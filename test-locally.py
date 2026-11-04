#!/usr/bin/env python3
"""test-locally.py — run the botui UI in a window on this PC (flutter run -d linux).

For trying out styling, margins and layout without a robot. Everything runs in Docker,
so you need neither Flutter nor GTK on the host.

The repository is mounted into the container, so what you change in your editor is
what runs: press `r` in this terminal for a hot reload, `R` for a hot restart, `q` to
quit. The build state stays in the repository (build/ and .dart_tool/, both ignored by
git), so after the first run the window is up in a few seconds.

There is no robot behind it: the raccoon server, the sensors and the hardware are not
there, so those screens stay empty or show errors. That is expected.

Nothing may change your PC. The app is started with LOCAL_TEST=true, in which
SudoProcess runs nothing (shutdown, reboot, service restarts, Wi-Fi changes, ... are only
printed as `[local-test] not running: ...`), and the container has no sudo anyway.

Usage:
    python3 test-locally.py
    python3 test-locally.py --codegen            # run build_runner first (after changing @riverpod, @freezed, ...)
    python3 test-locally.py --image my-image     # use a prebuilt image instead of Dockerfile.desktop

Needs an X11 display (a Wayland session works through XWayland, DISPLAY is set).
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMAGE = "botui-desktop"
CPP_DIR = Path("packages/raccoon-transport/cpp")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def run(command: list[str], **kwargs) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, check=True, **kwargs)


# ── inside the container ─────────────────────────────────────────────────


def build_bridge() -> Path:
    """The ring bridge for this machine (x86_64); the Pi build cross compiles it for aarch64.

    Built from a copy in the cache, so the submodule in the repository stays untouched.
    """
    target = Path("/cache/bridge")
    shutil.rmtree(target, ignore_errors=True)
    shutil.copytree(Path("/src") / CPP_DIR, target / "cpp")
    bridge = target / "cpp" / "bridge"
    run(["bash", "build.sh"], cwd=bridge, env={**os.environ, "CXX": "g++", "CC_CROSS": "gcc"})
    return bridge


def run_in_container(codegen: bool, owner: str) -> None:
    os.umask(0)  # whatever the container writes into the repository, you can change and delete
    os.chdir("/src")
    bridge = build_bridge()

    if codegen:
        run(["flutter", "pub", "run", "build_runner", "build", "-d"])

    env = {**os.environ, "LD_LIBRARY_PATH": f"{bridge}{os.pathsep}{os.environ.get('LD_LIBRARY_PATH', '')}"}
    # Flutter 3.38 resolves some packages differently from the committed pubspec.lock and
    # rewrites it on every start. Put the committed one back afterwards so git stays clean.
    lock = Path("pubspec.lock")
    original_lock = lock.read_bytes() if lock.is_file() else None
    try:
        status = subprocess.run(
            ["flutter", "run", "-d", "linux", "--dart-define=LOCAL_TEST=true"], env=env
        ).returncode
    finally:
        if original_lock is not None:
            lock.write_bytes(original_lock)
        # The container runs as root (the Flutter SDK in the image is root-owned): hand back
        # what it created in the repository.
        for name in ("build", ".dart_tool", ".flutter-plugins", ".flutter-plugins-dependencies",
                     "pubspec.lock", "linux/flutter"):
            if Path(name).exists():
                subprocess.run(["chown", "-R", owner, name], check=False)
    sys.exit(status)


# ── on the host ──────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the botui UI in a window on this PC, in Docker.")
    parser.add_argument("--image", help="use this Docker image instead of building ./Dockerfile.desktop")
    parser.add_argument("--codegen", action="store_true",
                        help="run build_runner before starting (the generated *.g.dart files are in git)")
    parser.add_argument(
        "--cache-dir",
        default=str(Path.home() / ".cache" / "raccoon-build" / "botui-desktop"),
        help="pub cache kept between runs (default: %(default)s)",
    )
    parser.add_argument("--in-container", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--owner", default="0:0", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.in_container:
        run_in_container(args.codegen, args.owner)
        return

    if not shutil.which("docker"):
        fail("docker not found.")
    if not os.environ.get("DISPLAY"):
        fail("DISPLAY is not set. This needs an X11 display (Wayland sessions have XWayland).")
    if not (ROOT / CPP_DIR / "bridge" / "build.sh").is_file():
        fail("packages/raccoon-transport is empty. Run `git submodule update --init`.")

    image = args.image
    if not image:
        image = IMAGE
        print(f"▶ Building Docker image {image}")
        subprocess.run(["docker", "build", "-t", image, "-f", str(ROOT / "Dockerfile.desktop"), str(ROOT)], check=True)

    cache = Path(args.cache_dir)
    (cache / "pub").mkdir(parents=True, exist_ok=True)

    command = ["docker", "run", "--rm", "-i"]
    if sys.stdin.isatty():
        command += ["-t"]  # with -i: the hot reload keys
    command += [
        "-e", f"DISPLAY={os.environ['DISPLAY']}",
        "-e", "PUB_CACHE=/cache/pub",
        "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
        "-v", f"{ROOT}:/src",
        "-v", f"{cache}:/cache",
        "-w", "/src",
    ]
    xauthority = Path(os.environ.get("XAUTHORITY") or Path.home() / ".Xauthority")
    if xauthority.is_file():
        command += ["-e", "XAUTHORITY=/tmp/.Xauthority", "-v", f"{xauthority}:/tmp/.Xauthority:ro"]
    if Path("/dev/dri").is_dir():
        command += ["--device", "/dev/dri"]  # GPU; without it Mesa renders in software
    command += [image, "python3", "/src/test-locally.py", "--in-container", "--owner", f"{os.getuid()}:{os.getgid()}"]
    if args.codegen:
        command += ["--codegen"]

    print("▶ Starting the UI (the first run builds the Linux app, later runs are quick)")
    sys.exit(subprocess.run(command).returncode)


if __name__ == "__main__":
    main()
