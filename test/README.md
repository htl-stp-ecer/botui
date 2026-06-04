# Tests

Mirror of `lib/`. Each test sits next to the production file it covers.

## Run
```bash
flutter test                       # everything
flutter test test/features/sensors # one feature
flutter test --name "stddev"       # one test by description
```

## Helpers (`test/helpers/`)

| File | Use for |
|------|---------|
| `pump_app.dart` | `pumpScreen(tester, widget, overrides: [...])` — wraps in `ProviderScope` + dark `MaterialApp`, sizes the test view to the 800×480 Wombat panel. Call `resetScreen()` in `tearDown`. |
| `fake_lcm.dart` | `fakeLcmOverrides()` — replaces `lcmServiceProvider` with an in-memory `FakeLcmService`. **Required** for any widget that uses `createTopBar` (its `BatteryStatus` indirectly subscribes to LCM) or any screen watching LCM-backed providers. Without it the real service tries to `dlopen` `libraccoon_ring_bridge.so` and the test errors out. |
| `mocks.dart` | `MockSensorRepository`, `MockWifiRepository` (mocktail). Call `registerCommonFallbacks()` in `setUpAll` when stubbing methods that take non-nullable enums. |

## Patterns

**Use case / repository tests** — instantiate the mock, stub with `when(...).thenAnswer(...)`, exercise the use case, assert with `verify`.

**Provider tests with LCM** — `ProviderContainer(overrides: [lcmServiceProvider.overrideWith((ref) => fake)])`. Force eager build with `container.listen(provider, (_, __) {}, fireImmediately: true)` before emitting events; broadcast streams drop events that fire before the listener attaches.

**Widget tests** — use `pumpScreen()`; pass `settle: false` if you want to assert a `CircularProgressIndicator` before the FutureProvider resolves.

## What's NOT covered yet

- `raccoon_transport` FFI / ring-buffer layer — explicitly out of scope while the transport is being stabilized.
- `ProgramLifecycleService` / `ProgramSession` — spawn real subprocesses; would need a process abstraction.
- Pages that depend on hardware (`touch_calibration_screen`, `screen_rotation_screen`, sensor graph screens) — rendered via `SensorStrategyFactory` and watch LCM channels per sensor.

When adding tests for one of those, start by extracting the side-effecting bit (process spawn, FFI call) behind an interface so the test can inject a fake.
