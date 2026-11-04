# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Development
- **Debug/Development**: `./debug.sh` - Runs the app in profile mode on a connected Raspberry Pi device
- **Build**: `python3 build.py` - builds the `.deb` in Docker (Flutter, flutterpi_tool, bridge), result in `builds/`
- **Try on the PC**: `python3 test-locally.py` - the UI in a window (`flutter run -d linux` in Docker, `LOCAL_TEST=true`: `SudoProcess` runs nothing)
- **Deploy**: `python3 deploy.py --host <pi>` - installs the `.deb` from `builds/` on the Pi and marks botui `dev` in its bundle file
- **Flutter Commands**: Standard Flutter commands work (`flutter run`, `flutter build`, `flutter test`)
- **Analysis**: `flutter analyze` - Static analysis using flutter_lints

### Deployment Target
The app runs on Raspberry Pi hardware (wombat robotics platform). `build.py` builds with `flutterpi_tool build --arch=arm64 --cpu=pi3 --release` inside Docker and packs the result into a `.deb`. The package installs the app to `/home/pi/stp-velox` and restarts `flutter-ui.service`; `deploy.py` copies and installs it.

## Architecture Overview

### Project Structure
StpVelox follows **Clean Architecture** with three main layers:

**Domain Layer** (`lib/domain/`):
- **Entities**: Core business objects (Program, Sensor, Setting, WiFi networks)
- **Repositories**: Abstract interfaces for data access
- **Use Cases**: Business logic operations (GetSensors, StartProgram, ConnectToWifi)
- **Services**: Program lifecycle management

**Data Layer** (`lib/data/`):
- **Data Sources**: Platform-specific implementations (Linux network manager, file system)
- **Repositories**: Concrete implementations of domain interfaces
- **Native Plugin**: `KiprPlugin` - Method channel interface to robotics hardware

**Presentation Layer** (`lib/presentation/`):
- **BLoC Pattern**: State management using flutter_bloc
- **Screens**: Main UI screens (Dashboard, Programs, Sensors, Settings, WiFi)
- **Widgets**: Reusable UI components

### Key Components

**Dependency Injection** (`lib/core/di/injection.dart`):
- Uses GetIt service locator
- Registers all repositories, use cases, and BLoCs
- Must call `await di.init()` before app starts

**Hardware Integration** (`lib/data/native/kipr_plugin.dart`):
- Native method channel to robotics hardware
- Sensor data: IMU (gyro, accel, magnetometer), analog/digital ports
- Motor/servo control methods
- Battery monitoring

**Program Management**:
- Programs stored in `programs/` directory with `project.json` and `run.sh`
- `ProgramLifecycleManager` handles execution via pseudoterminal
- Terminal UI for program output using xterm package

**Touch Calibration**:
- Custom touch calibration system for embedded displays
- `TouchCalibrator` applies calibration transforms globally
- Calibration data persisted in SharedPreferences

**WiFi Management**:
- Linux NetworkManager integration for WiFi connectivity
- Support for multiple encryption types and enterprise networks
- Device info and network scanning capabilities

### State Management
Uses BLoC pattern throughout:
- `SensorBloc`: Real-time sensor data streams
- `ProgramBloc`: Program execution state
- `SettingsBloc`: Device settings and configuration
- `WifiBloc`: Network connectivity management
- `ProgramSelectionBloc`: Available programs list

### Special Features
- **Battery Monitoring**: `BatteryCheckService` with low battery warnings
- **Easter Egg**: Flappy Bird game controlled by digital sensor input (port 10)
- **Responsive UI**: Grid-based dashboard optimized for 800x480 display
- **Dark Theme**: Consistent dark theme with custom colors

### Testing
No specific test configuration found. Use standard Flutter testing:
- `flutter test` for unit tests
- `flutter integration_test` for integration tests

### Platform Specifics
- Target: Linux ARM64 (Raspberry Pi)
- Display: 800x480 resolution
- Requires KIPR robotics hardware libraries
- Uses flutterpi for embedded deployment