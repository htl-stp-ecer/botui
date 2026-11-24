<div align="center">

<img src="https://raw.githubusercontent.com/htl-stp-ecer/.github/main/profile/raccoon-logo.svg" alt="botui" width="100"/>

# botui

**The Flutter desktop environment for the KIPR Wombat — dashboard, programs, sensors, and more.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](COPYING)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%20ARM64-A22846?logo=raspberrypi&logoColor=white)
![Display](https://img.shields.io/badge/Display-800x480-555)
[![Build & Release](https://github.com/htl-stp-ecer/botui/actions/workflows/build-release.yml/badge.svg)](https://github.com/htl-stp-ecer/botui/actions/workflows/build-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/htl-stp-ecer/botui)](https://github.com/htl-stp-ecer/botui/releases/latest)

> 📖 **Full documentation at [raccoon-docs.pages.dev](https://raccoon-docs.pages.dev/)**

</div>

---

botui is the graphical environment that runs directly on the [KIPR Wombat](https://www.kipr.org/kipr/hardware-software) controller. It replaces the default Wombat UI with a fast, touch-friendly Flutter interface purpose-built for Botball competition — real-time sensor graphs, a program runner with live terminal output, WiFi management, and a camera feed, all on an 800×480 display.

---

## Features

| Screen | What it does |
|:-------|:-------------|
| **Dashboard** | Live sensor overview grid — IMU, analog/digital ports, battery |
| **Programs** | Browse, launch, and monitor robot programs with a live terminal |
| **Sensors** | Real-time charts for gyro, accelerometer, magnetometer, and analog inputs, plus motor, servo and bus servo screens |
| **Camera** | Live camera feed from the robot's vision system, choice of backend and of the processor that runs for the UI, with the detections drawn in the colour the processor set |
| **WiFi** | Scan, connect, and manage networks via Linux NetworkManager |
| **Settings** | Display, theme, hostname, keyboard layout, screen rotation, touch calibration, service status and logs, program run logs |
| **Screen renderer / dynamic UI** | Screens that the robot program requests at runtime (`screen_render` messages) and the answers go back to it; a screen can contain the camera picture (`CamFeed`) |
| **Messages** | Errors and warnings of the robot (`messages/error`, `messages/warn`) appear as dialogs with a title and a text; a repeated message updates the open dialog |
| **Calibration board** | Guided calibration with the calibration board |
| **Dev menu** | Developer tools, plus the small games Tilt Maze and Flappy Wombat |

---

## Building & deploying

The build runs in a Docker container, so you only need Docker and Python 3 on your machine — no Flutter, Dart or cross compiler. Flutter and [flutterpi_tool](https://pub.dev/packages/flutterpi_tool) are in the image (see `Dockerfile`).

### Build

```bash
python3 build.py                 # local build, version 0.0
python3 build.py --version 81    # release build (what CI does)
```

Result in `builds/`: `botui_<version>_arm64.deb` and `manifest.json`. The build runs `build_runner` for code generation (Riverpod, Freezed, JSON serialization), cross-compiles for `arm64 / pi3`, builds the `raccoon_ring` bridge and packs everything into the package.

### Deploy to the Pi

```bash
python3 deploy.py --host <your-pi-ip>
```

Copies the `.deb` from `builds/` to the Pi and installs it with `apt`. It sets `botui` to `dev` in the Pi's `/etc/raccoon-bundle.json`, because a deployed local build is a custom build. Releases are installed by `raccoon update`.

### Try the UI on your PC

```bash
python3 test-locally.py
```

Opens the UI in a window on your PC (`flutter run -d linux` in Docker, 800x480 like the Pi display). Use it to try out styling, margins and layout. The repository is mounted into the container, so what you edit is what runs: press `r` in the terminal for a hot reload, `R` for a hot restart, `q` to quit. The window is up in about 5 to 15 seconds once the image exists. Add `--codegen` after changing annotated code (`@riverpod`, `@freezed`, ...): the generated `*.g.dart` files are in git, so `build_runner` does not run by default. There is no robot behind it, so screens that need the raccoon server or sensors stay empty or show errors. Nothing changes your PC: the app runs with `LOCAL_TEST=true`, where shutdown, reboot, service and Wi-Fi commands are only printed as `[local-test] not running: ...`. Needs an X11 display (Wayland sessions have XWayland).

### Local development

[FVM](https://fvm.app/) pins the Flutter version (`.fvmrc`) for your IDE, `flutter analyze` and `flutter test`:

```bash
dart pub global activate fvm
fvm install   # picks up version from .fvmrc
```

### Debug (profile mode on connected Pi)

```bash
dart pub global activate flutterpi_tool
bash debug.sh
```

---

## Architecture

botui follows **Clean Architecture** with three layers and [Riverpod](https://riverpod.dev/) for state management throughout.

```
lib/
├── core/           # DI (GetIt), routing (go_router), theme, transport, contract check, logging, shared utilities
├── application/    # App-wide behaviour (overview, screensaver, inactivity, ethernet prompt, theme)
├── presentation/   # Top-level screens
├── features/       # One folder per feature (dashboard, program, sensors, camera, wifi, settings, ...)
│   └── <feature>/
│       ├── domain/       # Entities, repository interfaces, use cases
│       ├── data/         # Repository implementations, data sources
│       └── presentation/ # Riverpod providers, screens, widgets
├── shared/         # Shared widgets and helpers used across features
└── main.dart
```

**Hardware data** flows in via [raccoon-transport](https://github.com/htl-stp-ecer/raccoon-transport) (shared-memory rings under `/dev/shm`, reached through the `raccoon_ring` bridge). Every channel is an entry of the transport's channel table: sensor values, motor state and IMU readings are published by stm32-data-reader and consumed by the UI in real time, and commands for the camera service go out on the camera channels of the table. At startup botui checks that its transport contract matches the installed bundle.

**Program execution** uses a pseudoterminal so program stdout/stderr stream live into the terminal widget (`xterm`).

**Rendering** uses [flutter-pi](https://github.com/ardera/flutter-pi) to render directly to the Linux framebuffer — no desktop environment, no compositor overhead. This gives high frame rates at almost no system cost on the Pi.

---

## Requirements

- [FVM](https://fvm.app/) — Flutter version manager
- Dart SDK ^3.5.4 (Flutter 3.38.7, pinned in `.fvmrc`)
- `flutterpi_tool` for ARM64 builds
- KIPR Wombat with Raspberry Pi (ARM64, 800×480 display)

---

## License

Copyright (C) 2026 Tobias Madlberger  
Licensed under the GNU General Public License v3.0 — see [COPYING](COPYING) for details.
