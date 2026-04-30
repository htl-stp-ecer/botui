import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/quaternion_sensor.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

/// Simple tilt‑controlled maze powered by the robot's IMU quaternion stream.
class TiltMazeScreen extends HookConsumerWidget {
  const TiltMazeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useMemoized(TiltMazeController.new);
    final latestQuaternion = useRef<Quaternion?>(null);
    latestQuaternion.value = ref.watch(quaternionSensorProvider);

    final frameTick = useState(0);
    final ticker = useAnimationController(
      duration: const Duration(milliseconds: 16),
    );

    final lastFrame = useRef<DateTime?>(null);

    useEffect(() {
      void onTick() {
        final now = DateTime.now();
        final dtMs = lastFrame.value == null
            ? 0.0
            : now.difference(lastFrame.value!).inMilliseconds.toDouble();
        lastFrame.value = now;

        final q = latestQuaternion.value;
        final euler = q?.toEulerAngles();
        controller.update(
          dt: dtMs / 1000.0,
          roll: euler?.roll ?? 0,
          pitch: euler?.pitch ?? 0,
          imuAvailable: q != null,
        );

        frameTick.value++;
      }

      ticker.addListener(onTick);
      ticker.repeat();
      return () {
        ticker.removeListener(onTick);
        ticker.stop();
      };
    }, []);

    return Scaffold(
      appBar: createTopBar(context, 'Tilt Maze'),
      backgroundColor: const Color(0xFF0B1221),
      body: LayoutBuilder(
        builder: (context, constraints) {
          controller.configure(Size(constraints.maxWidth, constraints.maxHeight));

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF111827)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _TiltMazePainter(controller: controller),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _InfoBar(
                  roll: controller.rollDeg,
                  pitch: controller.pitchDeg,
                  imuAvailable: controller.imuAvailable,
                  onReset: controller.reset,
                  onCalibrate: () {
                    controller.calibrate();
                    controller.reset();
                  },
                  onNewMaze: () {
                    controller.regenerate();
                  },
                ),
              ),
              if (!controller.biasInitialized)
                _StartOverlay(
                  onCalibrate: () {
                    controller.calibrate();
                    controller.reset();
                  },
                  imuAvailable: controller.imuAvailable,
                ),
              if (controller.reachedGoal)
                _CompletedOverlay(
                  onReset: controller.reset,
                  onCalibrate: () {
                    controller.calibrate();
                    controller.reset();
                  },
                ),
              if (controller.biasInitialized && !controller.imuAvailable)
                const _OverlayBanner(
                  title: 'Waiting for IMU…',
                  subtitle: 'No orientation data yet from raccoon/imu/quaternion',
                ),
            ],
          );
        },
      ),
    );
  }
}

class TiltMazeController {
  // Rendering / physics params
  static const double _padding = 16.0;
  static const double _maxTiltDeg = 45.0;
  static const double _deadZoneDeg = 3.0; // ignore tiny jitters
  static const double _gravityPx = 650.0; // pixels / s^2 (reduced sensitivity)
  static const double _drag = 0.985;
  static const double _wallBounce = 0.55;
  static const double _maxSpeed = 900.0;

  // Maze state
  List<String> _layout = [];
  int _rows = 0;
  int _cols = 0;
  bool _needsRebuild = true;

  Size? _canvasSize;
  late double _cellSize;
  late double _radius;
  late Rect _goalRect;
  late Offset _startPos;
  late List<Rect> _walls;

  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  bool reachedGoal = false;
  bool imuAvailable = false;
  double rollDeg = 0;
  double pitchDeg = 0;
  double _rawRoll = 0;
  double _rawPitch = 0;
  double _rollBias = 0;
  double _pitchBias = 0;
  bool _biasInitialized = false;

  void configure(Size size) {
    final sizeChanged = _canvasSize != size;
    _canvasSize = size;

    if (_layout.isEmpty || _needsRebuild) {
      _generateAndBuild(size);
    } else if (sizeChanged) {
      _rebuildGeometry(size);
    }
  }

  void regenerate({int rows = 19, int cols = 29}) {
    _rows = rows;
    _cols = cols;
    _needsRebuild = true;
    if (_canvasSize != null) {
      _generateAndBuild(_canvasSize!);
    }
  }

  void update({
    required double dt,
    required double roll,
    required double pitch,
    required bool imuAvailable,
  }) {
    if (_canvasSize == null) return;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05; // clamp large frame gaps

    this.imuAvailable = imuAvailable;
    _rawRoll = roll;
    _rawPitch = pitch;
    if (!_biasInitialized) {
      // Don't move until the user calibrates
      return;
    }

    final rollZeroed = _normalizeAngle(roll - _rollBias);
    final pitchZeroed = _normalizeAngle(pitch - _pitchBias);
    rollDeg = rollZeroed;
    pitchDeg = pitchZeroed;

    final cappedRoll =
        _applyDeadZone(rollZeroed.clamp(-_maxTiltDeg, _maxTiltDeg));
    final cappedPitch =
        _applyDeadZone(pitchZeroed.clamp(-_maxTiltDeg, _maxTiltDeg));

    // Roll positive -> move right (no inversion after bias)
    final ax = (cappedRoll / _maxTiltDeg) * _gravityPx;
    final ay = -(cappedPitch / _maxTiltDeg) * _gravityPx;

    velocity = Offset(
      (velocity.dx + ax * dt) * _drag,
      (velocity.dy + ay * dt) * _drag,
    );

    // Clamp max speed to keep control comfortable
    final speed = velocity.distance;
    if (speed > _maxSpeed) {
      velocity = velocity / speed * _maxSpeed;
    }

    var proposed = position + velocity * dt;

    for (final wall in _walls) {
      final expanded = wall.inflate(_radius);
      if (expanded.contains(proposed)) {
        final left = proposed.dx - expanded.left;
        final right = expanded.right - proposed.dx;
        final top = proposed.dy - expanded.top;
        final bottom = expanded.bottom - proposed.dy;

        final minPen = math.min(math.min(left, right), math.min(top, bottom));

        if (minPen == left) {
          proposed = Offset(expanded.left, proposed.dy);
          velocity = Offset(velocity.dx.abs() * _wallBounce, velocity.dy);
        } else if (minPen == right) {
          proposed = Offset(expanded.right, proposed.dy);
          velocity = Offset(-velocity.dx.abs() * _wallBounce, velocity.dy);
        } else if (minPen == top) {
          proposed = Offset(proposed.dx, expanded.top);
          velocity = Offset(velocity.dx, velocity.dy.abs() * _wallBounce);
        } else {
          proposed = Offset(proposed.dx, expanded.bottom);
          velocity = Offset(velocity.dx, -velocity.dy.abs() * _wallBounce);
        }
      }
    }

    position = proposed;

    // Win detection
    if (_goalRect.contains(position)) {
      reachedGoal = true;
      velocity = Offset.zero;
    }
  }

  void reset() {
    position = _startPos;
    velocity = Offset.zero;
    reachedGoal = false;
  }

  List<Rect> get walls => _walls;
  Rect get goalRect => _goalRect;
  double get cellSize => _cellSize;
  double get radius => _radius;
  Size? get size => _canvasSize;
  Offset get start => _startPos;
  bool get biasInitialized => _biasInitialized;
  int get rows => _rows;
  int get cols => _cols;

  double _applyDeadZone(double value) {
    final abs = value.abs();
    if (abs <= _deadZoneDeg) return 0;
    final sign = value.sign;
    // Re-scale so full deflection past deadzone still reaches max effect
    final adjusted = (abs - _deadZoneDeg) / (_maxTiltDeg - _deadZoneDeg) * _maxTiltDeg;
    return sign * adjusted;
  }

  double _normalizeAngle(double angle) {
    var a = angle % 360;
    if (a > 180) a -= 360;
    if (a < -180) a += 360;
    return a;
  }

  /// Capture current IMU orientation as zero reference.
  void calibrate([double? roll, double? pitch]) {
    if (!imuAvailable && (roll == null || pitch == null)) return;
    final r = roll ?? _rawRoll;
    final p = pitch ?? _rawPitch;
    _rollBias = _normalizeAngle(r);
    _pitchBias = _normalizeAngle(p);
    _biasInitialized = true;
  }

  void _generateAndBuild(Size size) {
    if (_rows == 0 || _cols == 0) {
      _rows = 19;
      _cols = 29;
    }
    _layout = _generateMaze(_rows, _cols);
    _needsRebuild = false;
    _rebuildGeometry(size);
  }

  void _rebuildGeometry(Size size) {
    final rows = _layout.length;
    final cols = _layout.first.length;
    _cellSize = math.min(
      (size.width - 2 * _padding) / cols,
      (size.height - 2 * _padding) / rows,
    );
    _radius = _cellSize * 0.32;

    _walls = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final char = _layout[r][c];
        final rect = Rect.fromLTWH(
          _padding + c * _cellSize,
          _padding + r * _cellSize,
          _cellSize,
          _cellSize,
        );
        if (char == '#') {
          _walls.add(rect);
        } else if (char == 'S') {
          _startPos = rect.center;
        } else if (char == 'G') {
          _goalRect = rect.deflate(_cellSize * 0.18);
        }
      }
    }

    reset();
  }

  List<String> _generateMaze(int rows, int cols) {
    // Require odd dimensions for walls/cells separation
    rows = rows.isEven ? rows + 1 : rows;
    cols = cols.isEven ? cols + 1 : cols;
    final rand = math.Random();

    // Initialize grid with walls
    final grid = List.generate(rows, (_) => List.generate(cols, (_) => '#'));

    bool inBounds(int r, int c) => r > 0 && c > 0 && r < rows - 1 && c < cols - 1;

    void carve(int r, int c) {
      grid[r][c] = ' ';
      final dirs = [
        (dr: -2, dc: 0),
        (dr: 2, dc: 0),
        (dr: 0, dc: -2),
        (dr: 0, dc: 2),
      ]..shuffle(rand);

      for (final dir in dirs) {
        final nr = r + dir.dr;
        final nc = c + dir.dc;
        if (inBounds(nr, nc) && grid[nr][nc] == '#') {
          grid[r + dir.dr ~/ 2][c + dir.dc ~/ 2] = ' ';
          carve(nr, nc);
        }
      }
    }

    carve(1, 1);

    // Set start/goal
    grid[1][1] = 'S';
    grid[rows - 2][cols - 2] = 'G';

    return grid.map((row) => row.join()).toList();
  }
}

class _TiltMazePainter extends CustomPainter {
  final TiltMazeController controller;

  _TiltMazePainter({required this.controller});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    // Maze walls
    paint
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.fill;
    for (final rect in controller.walls) {
      final r = RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(6));
      canvas.drawRRect(r, paint);
    }

    // Goal area
    paint
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    final goalRRect = RRect.fromRectAndRadius(controller.goalRect, const Radius.circular(8));
    canvas.drawRRect(goalRRect, paint);

    // Start marker
    paint..color = const Color(0xFFF59E0B);
    final startRect = Rect.fromCircle(center: controller.start, radius: controller.radius * 1.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(startRect, const Radius.circular(8)),
      paint,
    );

    // Ball shadow
    final ballPos = controller.position;
    final radius = controller.radius;
    paint
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(ballPos.translate(0, radius * 0.35), radius * 0.95, paint);

    // Ball
    paint
      ..maskFilter = null
      ..shader = const RadialGradient(
        colors: [Color(0xFF93C5FD), Color(0xFF1D4ED8)],
        center: Alignment.topLeft,
      ).createShader(Rect.fromCircle(center: ballPos, radius: radius));
    canvas.drawCircle(ballPos, radius, paint);

    // Ball outline
    paint
      ..shader = null
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(ballPos, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _TiltMazePainter oldDelegate) => true;
}

class _InfoBar extends StatelessWidget {
  final double roll;
  final double pitch;
  final bool imuAvailable;
  final VoidCallback onReset;
  final VoidCallback onCalibrate;
  final VoidCallback onNewMaze;

  const _InfoBar({
    required this.roll,
    required this.pitch,
    required this.imuAvailable,
    required this.onReset,
    required this.onCalibrate,
    required this.onNewMaze,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip('Roll', roll),
                _chip('Pitch', pitch),
                Row(
                  children: [
                    Icon(
                      imuAvailable ? Icons.sensors : Icons.sensors_off,
                      color: imuAvailable ? Colors.greenAccent : Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      imuAvailable ? 'IMU live' : 'No IMU',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onNewMaze,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.shuffle),
          label: const Text('New Maze'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onCalibrate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF14B8A6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.center_focus_strong),
          label: const Text('Calibrate'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _chip(String label, double value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Text(
          '${value.toStringAsFixed(1)}°',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _OverlayBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OverlayBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartOverlay extends StatelessWidget {
  final VoidCallback onCalibrate;
  final bool imuAvailable;

  const _StartOverlay({
    required this.onCalibrate,
    required this.imuAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1221), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 24,
                  offset: Offset(0, 14),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Calibrate to Start',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hold the robot level, then tap Calibrate.\nThis zeros the IMU (roll/pitch) so tilt feels natural.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: imuAvailable ? onCalibrate : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(imuAvailable ? 'Calibrate & Start' : 'Waiting for IMU'),
                ),
                const SizedBox(height: 10),
                if (!imuAvailable)
                  const Text(
                    'No IMU data yet (raccoon/imu/quaternion).',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedOverlay extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onCalibrate;

  const _CompletedOverlay({
    required this.onReset,
    required this.onCalibrate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.55),
              Colors.blue.withOpacity(0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, 12),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 56, color: Color(0xFFf59e0b)),
                const SizedBox(height: 8),
                const Text(
                  'Maze Complete!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Nice tilt control. Want another run?',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.replay),
                      label: const Text('Play Again'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onCalibrate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14B8A6),
                        side: const BorderSide(color: Color(0xFF14B8A6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Recalibrate'),
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
