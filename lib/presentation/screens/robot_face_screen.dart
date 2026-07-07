import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/inactivity/inactivity_notifier.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/sensors/digital_sensor.dart';
import 'package:stpvelox/core/utils/colors/device_color_generator.dart';
import 'package:stpvelox/features/program/domain/entities/program_session.dart';
import 'package:stpvelox/features/program/domain/services/program_lifecycle_service.dart';
import 'package:stpvelox/presentation/screens/robot_face/robot_face_animation_manager.dart';
import 'package:stpvelox/presentation/screens/robot_face/robot_face_painter.dart';


class RobotFaceScreen extends ConsumerStatefulWidget {
  const RobotFaceScreen({super.key});

  @override
  ConsumerState<RobotFaceScreen> createState() => _RobotFaceScreenState();
}

class _RobotFaceScreenState extends ConsumerState<RobotFaceScreen>
    with TickerProviderStateMixin {
  late RobotFaceAnimationManager _animationManager;

  // Button 10 irritation tracking
  int _button10PressCount = 0;
  DateTime? _lastButton10Press;
  bool? _previousButton10State;

  @override
  void initState() {
    super.initState();
    _animationManager = RobotFaceAnimationManager(vsync: this);
    final session = ref.read(programLifecycleServiceProvider);
    final isProgramRunning = session != null;
    _animationManager.startAnimations(focusedMode: isProgramRunning);
  }

  @override
  void dispose() {
    _animationManager.dispose();
    super.dispose();
  }

  /// Dismiss the screensaver directly and idempotently.
  ///
  /// The screensaver *is* this pushed route, so it closes itself rather than
  /// relying on an `inactivityProvider` true→false transition to trigger the
  /// pop from InactivityListener. That transition was fragile: if the flag was
  /// already `false` (e.g. cleared via the DynamicUI dismiss path in main.dart)
  /// no listener fired and the route stayed up forever — the "screensaver
  /// freezes and tapping won't dismiss it" bug.
  ///
  /// We clear `screensaverShowing` *first* so InactivityListener._hideScreensaver
  /// early-returns on its `!isShowing` guard and does not double-pop, then pop
  /// this route ourselves. Resetting activity re-arms the inactivity timer.
  void _dismissScreensaver() {
    ref.read(screensaverShowingProvider.notifier).set(false);
    ref.read(inactivityProvider.notifier).userActivityDetected();
    final router = ref.read(appRouterProvider);
    if (router.canPop()) {
      router.pop();
    }
  }

  void _handleButton10Press() {
    final now = DateTime.now();

    // Reset counter if too much time has passed (10 seconds)
    if (_lastButton10Press != null &&
        now.difference(_lastButton10Press!).inSeconds > 10) {
      _button10PressCount = 0;
    }

    _button10PressCount++;
    _lastButton10Press = now;

    // Trigger robot face irritation based on press count
    _animationManager.expressionStateManager.handleButton10Press();

    // Schedule reset after 15 seconds of inactivity
    Future.delayed(const Duration(seconds: 15), () {
      if (_lastButton10Press != null &&
          DateTime.now().difference(_lastButton10Press!).inSeconds >= 15) {
        _button10PressCount = 0;
        _lastButton10Press = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // React to program start/stop → switch focused face on/off
    ref.listen<ProgramSession?>(programLifecycleServiceProvider,
        (previous, next) {
      _animationManager.setFocusedMode(next != null, this);
    });

    // Screensaver dismissal: tap anywhere to dismiss via InactivityListener

    // Watch button 10 directly using useDigitalValue
    final button10State = useDigitalValue(ref, 10);

    // Detect button 10 press (rising edge)
    if (button10State == true && _previousButton10State != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleButton10Press();
      });
    }
    _previousButton10State = button10State;

    final colorSchemeAsync = ref.watch(robotColorSchemeProvider);
    final personalityAsync = ref.watch(robotPersonalityProvider);

    // Push personality into the expression state manager when it resolves
    final personality = personalityAsync.asData?.value;
    if (personality != null &&
        _animationManager.expressionStateManager.personality == null) {
      _animationManager.expressionStateManager.setPersonality(personality);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissScreensaver,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: colorSchemeAsync.when(
        data: (colorScheme) => AnimatedBuilder(
          animation: Listenable.merge([
            _animationManager.blinkAnimation,
            _animationManager.gazeAnimation,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: RobotFacePainter(
                blinkValue: _animationManager.blinkAnimation.value,
                gazeOffset: _animationManager.gazeAnimation.value,
                stateManager: _animationManager.expressionStateManager,
                colorScheme: colorScheme,
                personality: personality,
              ),
              child: Container(),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error loading colors: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      ),
    );
  }
}
