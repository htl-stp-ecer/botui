#!/usr/bin/env python3
"""install.py — Deploy Flutter UI application to Raspberry Pi.

Usage:
    python install.py
    RPI_HOST=192.168.4.1 python install.py

Env vars:
    RPI_HOST  — Pi IP address (default: 192.168.68.110)
    RPI_USER  — Pi SSH user   (default: pi)
"""

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def _read_pubspec_version(script_dir: Path) -> str:
    pubspec = script_dir / "pubspec.yaml"
    if not pubspec.exists():
        return "unknown"
    for line in pubspec.read_text().splitlines():
        m = re.match(r"^version:\s*([^\s+]+)", line)
        if m:
            return m.group(1)
    return "unknown"


def ssh(host: str, user: str, command: str, check: bool = True) -> int:
    """Run a command on the Pi via SSH."""
    result = subprocess.run(
        ["ssh", "-o", "ConnectTimeout=5", f"{user}@{host}", command],
        capture_output=not check,
    )
    if check and result.returncode != 0:
        print(f"ERROR: SSH command failed: {command}")
        sys.exit(1)
    return result.returncode


def scp(source: str, dest: str, recursive: bool = False) -> None:
    """Copy files to the Pi via SCP."""
    cmd = ["scp"]
    if recursive:
        cmd.append("-r")
    cmd.extend([source, dest])
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"ERROR: SCP failed: {source} -> {dest}")
        sys.exit(1)


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    rpi_host = os.environ.get("RPI_HOST", "192.168.68.110")
    rpi_user = os.environ.get("RPI_USER", "pi")
    remote_app_dir = f"/home/{rpi_user}/stp-velox"
    service_name = "flutter-ui"

    # Support both repo (build output) and release bundle (files at root) layouts
    repo_build_dir = script_dir / "build" / "flutter-pi" / "pi3-64"
    if repo_build_dir.is_dir():
        build_dir = repo_build_dir
    else:
        build_dir = script_dir

    service_file = script_dir / "systemd" / "flutter-ui.service"

    # --- Preflight checks ---
    if not (build_dir / "app.so").is_file():
        print(f"ERROR: No Flutter build found in {build_dir}")
        print("Run build.sh first, or extract a release bundle.")
        sys.exit(1)

    if not service_file.is_file():
        print(f"ERROR: Systemd service file not found: {service_file}")
        sys.exit(1)

    # --- Test SSH connectivity ---
    print(f"Testing SSH connection to {rpi_user}@{rpi_host}...")
    if ssh(rpi_host, rpi_user, "echo ok", check=False) != 0:
        print(f"ERROR: Cannot connect to {rpi_user}@{rpi_host}")
        sys.exit(1)

    remote = f"{rpi_user}@{rpi_host}"

    # --- Stop service ---
    print(f"Stopping {service_name} service...")
    ssh(rpi_host, rpi_user, f"sudo systemctl stop {service_name} || true")

    # --- Upload build ---
    version = _read_pubspec_version(script_dir)
    print(f"Uploading build ({version}) to {rpi_host}:{remote_app_dir}...")
    ssh(rpi_host, rpi_user, f"mkdir -p {remote_app_dir}")
    # Use scp -r as cross-platform replacement for rsync
    scp(f"{build_dir}/.", f"{remote}:{remote_app_dir}", recursive=True)

    # --- Write version file so raccoon-server can report it ---
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as tmp:
        tmp.write(version)
        tmp_path = tmp.name
    scp(tmp_path, f"{remote}:{remote_app_dir}/version")
    Path(tmp_path).unlink(missing_ok=True)

    # --- Install systemd unit ---
    print("Installing systemd service...")
    scp(str(service_file), f"{remote}:/home/{rpi_user}/flutter-ui.service")
    ssh(
        rpi_host,
        rpi_user,
        f"sudo mv /home/{rpi_user}/flutter-ui.service /etc/systemd/system/flutter-ui.service "
        "&& sudo systemctl daemon-reload",
    )

    # --- Enable & start service ---
    print(f"Enabling and starting {service_name}...")
    ssh(rpi_host, rpi_user, f"sudo systemctl enable {service_name}")
    ssh(rpi_host, rpi_user, f"sudo systemctl start {service_name}")

    print("Deploy complete.")


if __name__ == "__main__":
    main()
