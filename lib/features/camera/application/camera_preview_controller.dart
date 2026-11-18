import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/logging/logging.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/features/camera/data/cam_command_client.dart';

final _log = getLogger('CameraPreview');

enum CameraPreviewPhase { idle, starting, running, failed }

class CameraPreviewStatus {
  const CameraPreviewStatus(this.phase, [this.message]);

  final CameraPreviewPhase phase;

  /// Why it failed, in words for the user.
  final String? message;
}

/// Keeps the camera open and streaming while the camera menu is shown.
///
/// The camera service opens the camera only while somebody holds a lease, and
/// publishes frames only while its stream is on. So the preview takes a lease
/// (renewing it every two seconds), turns the stream on, and on leaving
/// restores the stream setting it found and gives the lease back. A program
/// that uses the camera at the same time keeps working: leases add up.
class CameraPreviewController extends ValueNotifier<CameraPreviewStatus> {
  CameraPreviewController(this._commands)
      : super(const CameraPreviewStatus(CameraPreviewPhase.idle));

  static const int streamFps = 10;
  static const int streamQuality = 60;
  static const double leaseSeconds = 6.0;
  static const Duration renewEvery = Duration(seconds: 2);

  final CamCommandClient _commands;
  final Random _random = Random.secure();
  Timer? _renewTimer;
  String? _lease;
  Map<String, dynamic>? _previousStream;
  bool _wanted = false;
  bool _renewing = false;
  bool _disposed = false;
  int _generation = 0;

  bool _current(int generation) => _wanted && generation == _generation;

  void _set(CameraPreviewStatus status) {
    if (!_disposed) value = status;
  }

  String _newLease() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  Future<Map<String, dynamic>> _acquire(String lease) => _commands.call(
        'acquire',
        {'lease': lease, 'ttl': leaseSeconds, 'retries': 5, 'delay': 1.0},
      );

  Future<void> start() async {
    if (_wanted) return;
    _wanted = true;
    final generation = ++_generation;
    _set(const CameraPreviewStatus(CameraPreviewPhase.starting));
    try {
      final status = await _commands.call('status');
      if (!_current(generation)) return;
      final streaming = status['streaming'];
      _previousStream =
          streaming is Map ? Map<String, dynamic>.from(streaming) : null;
      final lease = _newLease();
      _lease = lease;
      await _acquire(lease);
      if (!_current(generation)) return;
      // Renew from here on: the commands below can take seconds while the
      // service starts the camera, and the lease only lasts [leaseSeconds].
      _renewTimer = Timer.periodic(renewEvery, (_) => _renew(generation));
      await _commands.call(
        'stream',
        {'fps': streamFps, 'quality': streamQuality},
      );
      if (!_current(generation)) return;
      _set(const CameraPreviewStatus(CameraPreviewPhase.running));
    } on CamCommandException catch (error) {
      _log.warning('Preview could not start: ${error.message}');
      await _failed(generation, _friendly(error.message));
    } catch (error, stack) {
      _log.severe('Preview could not start: $error', error, stack);
      await _failed(generation, 'The preview could not be started.');
    }
  }

  Future<void> _failed(int generation, String message) async {
    if (!_current(generation)) return;
    _set(CameraPreviewStatus(CameraPreviewPhase.failed, message));
    await _release();
  }

  Future<void> _renew(int generation) async {
    final lease = _lease;
    if (_renewing || lease == null || !_current(generation)) return;
    _renewing = true;
    try {
      await _commands.call(
        'renew',
        {'lease': lease, 'ttl': leaseSeconds},
        const Duration(seconds: 2),
        1,
      );
    } on CamCommandException catch (error) {
      // The service forgot the lease (it restarted, or it ran out): take it again.
      if (error.message.contains('unknown lease') && _current(generation)) {
        try {
          await _acquire(lease);
        } on CamCommandException catch (again) {
          _log.warning('Could not take the lease again: ${again.message}');
        }
      }
    } finally {
      _renewing = false;
    }
  }

  /// The backend was changed: the service restarts the camera. Shows "starting"
  /// until the new one delivers, so the last picture of the old backend is not
  /// shown meanwhile. [clear] drops the pictures that are held (called at the
  /// start and again just before the preview runs).
  Future<void> waitForRestart({VoidCallback? clear}) async {
    if (!_wanted) return;
    final generation = _generation;
    clear?.call();
    _set(const CameraPreviewStatus(CameraPreviewPhase.starting));
    // The service looks at the saved choice twice a second, then restarts the camera.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (_current(generation) && DateTime.now().isBefore(deadline)) {
      try {
        final status = await _commands.call(
          'status',
          const {},
          const Duration(seconds: 3),
          1,
        );
        final failed = status['failed'];
        if (failed is String && failed.isNotEmpty) {
          await _failed(generation, _friendly(failed));
          return;
        }
        if (status['ready'] == true) break;
      } on CamCommandException {
        // Busy starting: ask again.
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!_current(generation)) return;
    clear?.call();
    _set(const CameraPreviewStatus(CameraPreviewPhase.running));
  }

  /// Leaves the camera as it was found. Safe to call when it never started.
  Future<void> stop() async {
    if (!_wanted) return;
    _wanted = false;
    _generation++;
    await _release();
    _set(const CameraPreviewStatus(CameraPreviewPhase.idle));
  }

  Future<void> _release() async {
    _renewTimer?.cancel();
    _renewTimer = null;
    final lease = _lease;
    final previous = _previousStream;
    _lease = null;
    _previousStream = null;
    if (lease == null) return;
    try {
      await _commands.call(
        'stream',
        {
          'fps': previous?['fps'] ?? 0,
          'quality': previous?['quality'] ?? streamQuality,
        },
        const Duration(seconds: 2),
        1,
      );
      await _commands.call(
        'release',
        {'lease': lease},
        const Duration(seconds: 2),
        1,
      );
    } on CamCommandException catch (error) {
      // The service gives the camera back by itself when the lease runs out.
      _log.fine('Release: ${error.message}');
    }
  }

  static String _friendly(String message) {
    if (message.contains('no camera backend is selected')) {
      return 'No camera backend is selected.\n'
          'Open "Configure backend" and choose one.';
    }
    if (message.contains('did not answer')) {
      return 'The camera service does not answer.';
    }
    return message;
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _renewTimer?.cancel();
    super.dispose();
  }
}

/// One controller for the whole app: the camera menu starts and stops it.
final cameraPreviewControllerProvider = Provider<CameraPreviewController>((ref) {
  final commands = CamCommandClient(ref.read(transportServiceProvider));
  final controller = CameraPreviewController(commands);
  ref.onDispose(() {
    controller.dispose();
    commands.close();
  });
  return controller;
});
