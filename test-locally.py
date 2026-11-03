#!/usr/bin/env python3
"""test-locally.py — run the botui UI in a window on this PC (flutter run -d linux).

For trying out styling, margins and layout without a robot. Everything runs in Docker,
so you need neither Flutter nor GTK on the host. Hot reload works: press `r` in this
terminal (`R` for a hot restart, `q` to quit).

There is no robot behind it: the raccoon server, the sensors and the hardware are not
there, so those screens stay empty or show errors. That is expected.

Nothing may change your PC. The app is started with LOCAL_TEST=true, in which
SudoProcess runs nothing (shutdown, reboot, service restarts, Wi-Fi changes, ... are only
printed as `[local-test] not running: ...`), and the container has no sudo anyway.

Usage:
    python3 test-locally.py
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
BRIDGE_DIR = Path("packages/raccoon-transport/cpp/bridge")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def run(command: list[str], **kwargs) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, check=True, **kwargs)


# ── inside the container ─────────────────────────────────────────────────


def run_in_container() -> None:
    sys.path.insert(0, "/src")
    import build  # the sources are copied the same way as for the Pi build

    work = build.copy_sources(Path("/src"), Path("/tmp/work"))
    os.chdir(work)

    run(["flutter", "pub", "get"])
    run(["flutter", "pub", "run", "build_runner", "build", "-d"])

    # The ring bridge for this machine (x86_64); the Pi build cross compiles it for aarch64.
    run(["bash", "build.sh"], cwd=work / BRIDGE_DIR, env={**os.environ, "CXX": "g++", "CC_CROSS": "gcc"})
    os.environ["LD_LIBRARY_PATH"] = str(work / BRIDGE_DIR) + os.pathsep + os.environ.get("LD_LIBRARY_PATH", "")

    os.execvp("flutter", ["flutter", "run", "-d", "linux", "--dart-define=LOCAL_TEST=true"])


# ── on the host ──────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the botui UI in a window on this PC, in Docker.")
    parser.add_argument("--image", help="use this Docker image instead of building ./Dockerfile.desktop")
    parser.add_argument(
        "--cache-dir",
        default=str(Path.home() / ".cache" / "raccoon-build" / "botui-desktop"),
        help="pub cache kept between runs (default: %(default)s)",
    )
    parser.add_argument("--in-container", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.in_container:
        run_in_container()
        return

    if not shutil.which("docker"):
        fail("docker not found.")
    if not os.environ.get("DISPLAY"):
        fail("DISPLAY is not set. This needs an X11 display (Wayland sessions have XWayland).")
    if not (ROOT / BRIDGE_DIR / "build.sh").is_file():
        fail("packages/raccoon-transport is empty. Run `git submodule update --init`.")

    image = args.image
    if not image:
        image = IMAGE
        print(f"▶ Building Docker image {image}")
        subprocess.run(["docker", "build", "-t", image, "-f", str(ROOT / "Dockerfile.desktop"), str(ROOT)], check=True)

    cache = Path(args.cache_dir)
    (cache / "pub").mkdir(parents=True, exist_ok=True)

    command = ["docker", "run", "--rm"]
    if sys.stdin.isatty():
        command += ["-it"]  # needed for hot reload keys
    command += [
        "-e", f"DISPLAY={os.environ['DISPLAY']}",
        "-e", "PUB_CACHE=/cache/pub",
        "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
        "-v", f"{ROOT}:/src:ro",
        "-v", f"{cache}:/cache",
    ]
    xauthority = Path(os.environ.get("XAUTHORITY") or Path.home() / ".Xauthority")
    if xauthority.is_file():
        command += ["-e", "XAUTHORITY=/tmp/.Xauthority", "-v", f"{xauthority}:/tmp/.Xauthority:ro"]
    if Path("/dev/dri").is_dir():
        command += ["--device", "/dev/dri"]  # GPU; without it Mesa renders in software
    command += [image, "python3", "/src/test-locally.py", "--in-container"]

    print("▶ Starting the UI (first run downloads packages, this takes a while)")
    sys.exit(subprocess.run(command).returncode)


if __name__ == "__main__":
    main()
