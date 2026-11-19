import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/logging.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'cam_provider.g.dart';

final _log = getLogger('CameraViewer');
const Duration _kUiCameraFrameThrottle = Duration(milliseconds: 66);
const Duration _kUiCameraDetectionThrottle = Duration(milliseconds: 100);

/// Pictures and detections that were published before [notBefore] are not
/// shown.
///
/// The transport keeps the last few messages of a channel in shared memory
/// after the camera stopped, and a new subscriber is handed them first. So
/// after a backend change (or when the screen is opened again) the last
/// pictures of the old backend would flash up. The service stamps every
/// message with the time it was published, on the same clock as the UI.
class CamMessageGate {
  CamMessageGate._();

  /// Microseconds since the epoch.
  static int notBefore = 0;

  /// From now on only what is published from this moment is shown.
  static void openNow() => notBefore = DateTime.now().microsecondsSinceEpoch;

  static bool allows(int timestampMicros) => timestampMicros >= notBefore;
}

/// Wrapper class for camera detection data
class CamDetectionData {
  final CamDetectionsT data;

  CamDetectionData(this.data);
}

/// Wrapper class for camera frame data
class CamFrameData {
  final CamFrameT data;

  CamFrameData(this.data);
}

/// Provider that streams camera detections from the vision daemon.
@riverpod
class CamDetectionStream extends _$CamDetectionStream {
  StreamSubscription<TransportDecoded<CamDetectionsT>>? _subscription;
  CamDetectionData? _currentDetections;

  @override
  CamDetectionData? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentDetections;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<CamDetectionsT>(
      Channels.camDetections,
      CamDetectionsT.decode,
      throttle: _kUiCameraDetectionThrottle,
    )
        .listen(
      (decoded) {
        if (!CamMessageGate.allows(decoded.value.timestamp)) return;
        _currentDetections = CamDetectionData(decoded.value);
        state = _currentDetections;
      },
      onError: (error, stackTrace) {
        _log.severe('Error in detection subscription: $error', stackTrace);
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Provider that streams camera JPEG frames from the vision daemon.
@riverpod
class CamFrameStream extends _$CamFrameStream {
  StreamSubscription<TransportDecoded<CamFrameT>>? _subscription;
  CamFrameData? _currentFrame;

  @override
  CamFrameData? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentFrame;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<CamFrameT>(
      Channels.camFrame,
      CamFrameT.decode,
      throttle: _kUiCameraFrameThrottle,
    )
        .listen(
      (decoded) {
        if (!CamMessageGate.allows(decoded.value.timestamp)) return;
        _currentFrame = CamFrameData(decoded.value);
        state = _currentFrame;
      },
      onError: (error, stackTrace) {
        _log.severe('Error in frame subscription: $error', stackTrace);
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
