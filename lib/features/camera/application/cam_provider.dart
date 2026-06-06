import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/logging.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'cam_provider.g.dart';

final _log = getLogger('CameraViewer');

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
            Channels.camDetections, CamDetectionsT.decode)
        .listen(
      (decoded) {
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
        .subscribeAs<CamFrameT>(Channels.camFrame, CamFrameT.decode)
        .listen(
      (decoded) {
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
