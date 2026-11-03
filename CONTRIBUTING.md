# Contributing to StpVelox (BotUI)

---

## Dev setup

```bash
# Install FVM and the pinned Flutter version
dart pub global activate fvm
fvm install

# Get dependencies + run code generation
fvm flutter pub get
fvm flutter pub run build_runner build -d
```

### Run on a connected Pi (profile mode)

```bash
bash debug.sh
```

> **flutter-pi compatibility warning**
> flutter-pi requires a Flutter engine build with embedded Linux support — not every Flutter version ships one. FVM is configured (`.fvmrc`) to use a version that has the required engine binaries, but this needs to be checked whenever upgrading Flutter. If `flutterpi_tool` fails with a missing engine error, the pinned version in `.fvmrc` needs updating to one that has a compatible engine artifact. Check [flutter-pi releases](https://github.com/ardera/flutter-pi) for supported versions before bumping.

### Analyze

```bash
fvm flutter analyze
```

---

## Project layout

```
lib/
├── core/
│   ├── di/                  # GetIt dependency injection (injection.dart)
│   ├── router/              # go_router route definitions
│   └── theme/               # App theme and colors
├── features/                # One folder per feature
│   └── <feature>/
│       ├── application/     # Riverpod providers
│       ├── domain/
│       │   ├── entities/    # Immutable data classes (Freezed)
│       │   ├── repositories/ # Abstract interfaces
│       │   └── usecases/    # Business logic
│       ├── data/
│       │   ├── datasource/  # LCM subscriptions, file system, NetworkManager
│       │   └── repositories/ # Concrete repository implementations
│       └── presentation/
│           ├── screens/     # Full-page widgets
│           └── widgets/     # Feature-specific reusable widgets
├── shared/                  # Widgets and utilities shared across features
└── main.dart
```

Current features: `dashboard`, `program`, `sensors`, `camera`, `wifi`, `settings`, `dynamic_ui`, `screen_renderer`, `dev_menu`

---

## Adding a feature

### 1. Create the folder structure

```
lib/features/my_feature/
├── application/
│   └── my_feature_providers.dart
├── domain/
│   ├── entities/my_entity.dart
│   └── repositories/my_repository.dart
├── data/
│   ├── datasource/my_data_source.dart
│   └── repositories/my_repository_impl.dart
└── presentation/
    └── screens/my_screen.dart
```

### 2. Define the entity (use Freezed for immutability)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'my_entity.freezed.dart';

@freezed
class MyEntity with _$MyEntity {
  const factory MyEntity({
    required String id,
    required double value,
  }) = _MyEntity;
}
```

Run `build_runner` after adding Freezed classes:

```bash
fvm flutter pub run build_runner build -d
```

### 3. Wire up a Riverpod provider

```dart
// application/my_feature_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'my_feature_providers.g.dart';

@riverpod
Stream<MyEntity> myEntity(MyEntityRef ref) {
  final repo = ref.watch(myRepositoryProvider);
  return repo.watch();
}
```

### 4. Register in DI

Add your repository and data source bindings in `lib/core/di/injection.dart`.

### 5. Add a route

Register the screen in `lib/core/router/` and add a navigation entry to the dashboard or sidebar if needed.

---

## Hardware data (LCM)

Sensor values, motor state, and IMU readings come in via LCM through `raccoon-transport`. Data sources in `data/datasource/` subscribe to LCM channels and expose streams. See `features/sensors/data/datasource/sensors_remote_data_source.dart` for an example.

---

## Code generation

The project uses three code generators — run them together after any model/provider change:

```bash
fvm flutter pub run build_runner build -d
```

| Generator | Purpose |
|:----------|:--------|
| `freezed` | Immutable data classes with copyWith, equality |
| `riverpod_generator` | Generates provider boilerplate from `@riverpod` annotations |
| `json_serializable` | JSON encode/decode for data models |

---

## Building & deploying

See [README.md](README.md) for full build and deploy instructions.

```bash
python3 build.py                  # ARM64 .deb in Docker -> builds/
python3 deploy.py --host <pi>     # install it on the Pi
python3 test-locally.py           # the UI in a window on your PC (styling, layout)
bash debug.sh                     # profile mode on connected Pi
```
