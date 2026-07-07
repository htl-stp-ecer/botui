import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/application/inactivity/inactivity_listener.dart';
import 'package:stpvelox/application/inactivity/inactivity_notifier.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/core/framerate/frame_stall_watchdog.dart';
import 'package:stpvelox/core/logging/logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/error_message_service.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/service/shutdown_status_service.dart';
import 'package:stpvelox/features/settings/domain/usecases/reboot.dart';
import 'package:stpvelox/core/service/button10_monitor_widget.dart';
import 'package:stpvelox/core/service/sensors/imu_accuracy_sensor.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/features/dev_menu/presentation/dev_menu_active_provider.dart';
import 'package:stpvelox/features/dev_menu/presentation/screens/dev_menu_screen.dart';
import 'package:stpvelox/features/dynamic_ui/presentation/dynamic_ui_screen.dart';
import 'package:stpvelox/features/screen_renderer/application/screen_renderer_provider.dart';

import 'core/di/injection.dart';
import 'core/utils/touch_calibrator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureImageCache();
  setupLogging();

  // Guard against flutter-pi render-pipeline wedges that freeze the display
  // while logic keeps running. Soft-recovers, then self-restarts via systemd
  // if the pipeline is truly stuck. See FrameStallWatchdog for the full why.
  FrameStallWatchdog.instance.start();

  // Initialize providers
  final (sharedPreferences, touchCalibrator) = await initializeProviders();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      touchCalibratorProvider.overrideWithValue(touchCalibrator),
    ],
    child: const StpVeloxApp(),
  ));
}

void _configureImageCache() {
  final imageCache = PaintingBinding.instance.imageCache;
  // The default cache is sized for desktop/mobile-class devices. On the Pi,
  // live camera JPEGs can quickly fill that with decoded frames that are
  // never revisited. Keep the cache intentionally small so camera streaming
  // does not hoard tens of MiB inside flutter-pi.
  imageCache.maximumSize = 20;
  imageCache.maximumSizeBytes = 24 << 20;
}

class CalibratedTapGestureRecognizer extends TapGestureRecognizer {
  final TouchCalibrator calibrator;

  CalibratedTapGestureRecognizer({required this.calibrator, super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final Offset calibratedLocalPosition =
        calibrator.applyCalibration(event.position);

    final PointerDownEvent calibratedEvent = event.copyWith(
      position: calibratedLocalPosition,
    );
    super.addAllowedPointer(calibratedEvent);
  }
}

class CalibratedGestureRecognizerFactory
    extends GestureRecognizerFactory<CalibratedTapGestureRecognizer> {
  final TouchCalibrator calibrator;

  CalibratedGestureRecognizerFactory({required this.calibrator});

  @override
  CalibratedTapGestureRecognizer constructor() {
    return CalibratedTapGestureRecognizer(calibrator: calibrator);
  }

  @override
  void initializer(CalibratedTapGestureRecognizer instance) {}
}

final _log = Logger('StpVeloxApp');

class StpVeloxApp extends HookConsumerWidget {
  const StpVeloxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorService = ref.watch(errorMessageServiceProvider.notifier);
    final router = ref.watch(appRouterProvider);

    // Initialize IMU accuracy sensor early so data is always available
    // Use ref.read to initialize without causing rebuilds on every value change
    ref.read(imuAccuracySensorProvider);

    // Force-initialize the screen render provider. ref.listen below DOES
    // subscribe in Riverpod 2.x, but the provider's build() — which opens
    // the transport subscription to raccoon/screen_render — does not run
    // until the first publisher delivers a frame. That creates a
    // chicken-and-egg: nothing ever arrives because nobody is listening
    // yet on the SHM ring, so build() never fires, so we never subscribe.
    // Calling ref.read eagerly here matches the imuAccuracySensorProvider
    // pattern and ensures the transport subscription is up before any
    // dynamic_ui message is published. Verified 2026-06-02: without this,
    // /proc/<flutter-pi>/fd never contained raccoon_ring_…screen_render.
    ref.read(screenRenderProviderProvider);

    // Dynamic UI rendering is handled by _AppServicesStarter's top-level
    // Stack (paints DynamicUIScreen above `child` whenever screenData !=
    // null). No router push/pop needed — and trying to do both caused a
    // "nothing to pop" race when backlog frames replayed open→close
    // cycles, leaving the navigator stuck on an empty /calibration route
    // that rendered as a blank screen above the dashboard.
    //
    // This listener now only mirrors open/close into dynamicUiActiveProvider
    // (read by ProgramScreen to hide its tap-blocking overlay) and dismisses
    // the screensaver on open.
    ref.listen<Map<String, dynamic>?>(screenRenderProviderProvider,
        (previous, next) {
      final wasOpen = previous != null;
      final shouldBeOpen = next != null;
      if (wasOpen == shouldBeOpen) return;

      if (shouldBeOpen) {
        _log.info('[DynamicUI] Opening dynamic UI screen');
        final screensaverUp = ref.read(screensaverShowingProvider);
        if (screensaverUp) {
          _log.info(
              '[DynamicUI] Dismissing screensaver before opening dynamic UI');
          ref.read(inactivityProvider.notifier).userActivityDetected();
        }
        ref.read(dynamicUiActiveProvider.notifier).set(true);
      } else {
        _log.info('[DynamicUI] Closing dynamic UI screen');
        ref.read(dynamicUiActiveProvider.notifier).set(false);
      }
    });

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        errorService.start(context);
      });
      return () {
        errorService.stop();
      };
    }, []);

    final calibrator = ref.watch(touchCalibratorProvider);

    return RawGestureDetector(
      gestures: {
        CalibratedTapGestureRecognizer:
            CalibratedGestureRecognizerFactory(calibrator: calibrator),
      },
      child: InactivityListener(
        child: MaterialApp.router(
          title: 'BotUI',
          // debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) {
            return _AppServicesStarter(
              child: Button10MonitorWidget(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppColors.programs,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.programs,
              secondary: AppColors.settings,
              surface: AppColors.surface,
              error: Colors.redAccent,
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onSurface: Colors.white,
              onError: Colors.white,
            ),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(color: Colors.white),
              bodyLarge: TextStyle(color: Colors.white70),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(150, 80),
                textStyle: const TextStyle(fontSize: 24),
                foregroundColor: Colors.white,
                backgroundColor: AppColors.programs,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final lowBatteryIgnoredProvider =
    NotifierProvider<_LowBatteryIgnored, bool>(_LowBatteryIgnored.new);

/// True while the DynamicUI screen is pushed on top — ProgramScreen uses this
/// to hide its overlay so touches can reach the DynamicUI.
final dynamicUiActiveProvider =
    NotifierProvider<_DynamicUiActive, bool>(_DynamicUiActive.new);

class _DynamicUiActive extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

class _LowBatteryIgnored extends Notifier<bool> {
  @override
  bool build() => false;

  void ignore() => state = true;
}

class _AppServicesStarter extends ConsumerWidget {
  final Widget child;

  const _AppServicesStarter({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select so the app shell only rebuilds when the BOOLEAN condition
    // flips, not every voltage frame (battery publishes at ~10 Hz; a
    // top-level rebuild per tick churns the whole subtree).
    final isLow = ref.watch(batteryVoltageSensorProvider
        .select((v) => v != null && v > 0 && v < 5.5));
    final ignored = ref.watch(lowBatteryIgnoredProvider);
    final showWarning = isLow && !ignored;

    // Show the hardware-shutdown overlay whenever motors OR servos are
    // latched off — regardless of source. Previously this only fired on
    // the watchdog branch, which meant a user-initiated shutdown (e.g.
    // emergency stop, or implicitly from `raccoon run` exiting) left the
    // hardware silent with no UI hint. Operators sliding servo sliders
    // were getting acks but no movement and no explanation. The dialog
    // text now branches on source so it stays informative.
    final shutdownStatus = ref.watch(shutdownStatusProvider);
    final showShutdown = shutdownStatus.isAnyShutdown;

    // When the user program has pushed a custom (dynamic-UI) screen, it
    // owns the full display. Local overlays — battery warning, hardware
    // shutdown — must NOT cover it, otherwise operators staring at a
    // custom screen during a run see an opaque dialog instead. The
    // program controls when it pops the dynamic UI; until then we stay
    // out of its way.
    //
    // Gate on the screen-render *state* directly (not the dynamicUiActive
    // flag) so we don't depend on the listen→push→provider chain in
    // StpVeloxApp.build running first. If a custom screen arrives while
    // the shutdown overlay is already painted, this widget rebuilds the
    // instant ScreenRenderProvider notifies, hiding the overlay and
    // letting the pushed dynamic UI route show through underneath.
    final hasCustomScreen = ref.watch(screenRenderProviderProvider) != null;

    // The Dev Menu is painted as the top-most child below (above the dynamic
    // UI), so it is the only UI that stays on top of a program's dynamic UI —
    // making its Stop button reachable even while a custom screen is up.
    final devMenuActive = ref.watch(devMenuActiveProvider);

    return Stack(
      children: [
        child,
        if (!hasCustomScreen && showWarning) const _LowBatteryOverlay(),
        if (!hasCustomScreen && showShutdown)
          _WatchdogShutdownOverlay(status: shutdownStatus),
        // Render the dynamic UI at the global Stack level so it is
        // guaranteed to sit above every other overlay. We previously
        // depended on go_router pushing the calibration route under the
        // MaterialApp navigator, but that route lives inside `child` —
        // and Stack-level overlays painted above `child` (battery /
        // shutdown) covered it. Painting the dynamic UI here as the
        // top-most child wins regardless of router state, and the
        // existing router.push in StpVeloxApp.build still runs in
        // parallel for backward-compat (e.g. pop semantics, debug
        // navigation).
        if (hasCustomScreen) const DynamicUIScreen(),
        // Top-most: the Dev Menu overlay wins over the dynamic UI and every
        // other overlay so its controls (notably Stop Program) are reachable.
        if (devMenuActive) const Positioned.fill(child: DevMenuScreen()),
      ],
    );
  }
}

class _WatchdogShutdownOverlay extends ConsumerWidget {
  const _WatchdogShutdownOverlay({required this.status});

  final ShutdownStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byWatchdog = status.triggeredByWatchdog;
    final title =
        byWatchdog ? 'Hardware Watchdog Tripped' : 'Hardware Shutdown Active';
    final reason = byWatchdog
        ? 'No heartbeat from the user program — motors and servos '
            'have been shut off as a safety measure.'
        : 'Motors and servos have been latched off (user-initiated '
            'shutdown). Servo and motor commands will be acknowledged '
            'but will not move the hardware until you recover.';
    final outputs = [
      if (status.servoShutdown) 'servos',
      if (status.motorShutdown) 'motors',
    ].join(' + ');

    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Material(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  byWatchdog
                      ? Icons.shield_moon_rounded
                      : Icons.power_off_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$reason\n'
                  'Latched outputs: ${outputs.isEmpty ? "(none)" : outputs}.\n'
                  'Recovering will re-enable outputs and re-arm the watchdog.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  width: 220,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(shutdownStatusServiceProvider.notifier)
                          .setShutdown(false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Recover',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LowBatteryOverlay extends ConsumerStatefulWidget {
  const _LowBatteryOverlay();

  @override
  ConsumerState<_LowBatteryOverlay> createState() => _LowBatteryOverlayState();
}

class _LowBatteryOverlayState extends ConsumerState<_LowBatteryOverlay> {
  bool _ignoreConfirmPending = false;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Material(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.battery_alert_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Low Battery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer(builder: (context, ref, _) {
                  final voltage =
                      ref.watch(batteryVoltageSensorProvider) ?? 0.0;
                  return Text(
                    'Battery voltage is ${voltage.toStringAsFixed(2)}V.\n'
                    'The robot may restart at any time.\n'
                    'Please switch the battery now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  );
                }),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 56,
                      width: 160,
                      child: ElevatedButton(
                        onPressed: _ignoreConfirmPending
                            ? () {
                                ref
                                    .read(lowBatteryIgnoredProvider.notifier)
                                    .ignore();
                              }
                            : () {
                                setState(() => _ignoreConfirmPending = true);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _ignoreConfirmPending ? 'Confirm Ignore' : 'Ignore',
                          style: const TextStyle(
                              fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 56,
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () async {
                          final reboot = ref.read(rebootDeviceProvider);
                          await reboot.call(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Shutdown',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
