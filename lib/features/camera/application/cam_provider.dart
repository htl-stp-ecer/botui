import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart';
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

/// Provider that streams camera detections from LCM (always active)
@riverpod
class CamDetectionStream extends _$CamDetectionStream {
  StreamSubscription<TransportDecoded<CamDetectionsT>>? _subscription;
  CamDetectionData? _currentDetections;

  @override
  CamDetectionData? build() {
    _log.info('CamDetectionStream build() called');
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentDetections;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _log.info('Starting subscription to channel: ${Channels.camDetections}');

    _subscription = transport
        .subscribeAs<CamDetectionsT>(
            Channels.camDetections, CamDetectionsT.decode)
        .listen(
      (decoded) {
        _log.fine(
            'Received detections: ${decoded.value.num_detections} detections');
        _currentDetections = CamDetectionData(decoded.value);
        state = _currentDetections;
      },
      onError: (error, stackTrace) {
        _log.severe('Error in detection subscription: $error', stackTrace);
      },
    );
    _log.info('Detection subscription created successfully');
  }

  void _dispose() {
    _log.info('Disposing CamDetectionStream subscription');
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Provider that streams camera frames from LCM (active only when viewer is open)
@riverpod
class CamFrameStream extends _$CamFrameStream {
  StreamSubscription<TransportDecoded<CamFrameT>>? _subscription;
  CamFrameData? _currentFrame;
  bool _disposed = false;

  @override
  CamFrameData? build() {
    _log.info('CamFrameStream build() called');
    _disposed = false;
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentFrame;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);

    _log.info(
        'Starting frame subscription to channel: ${Channels.camFrame}');
    _subscription = transport
        .subscribeAs<CamFrameT>(Channels.camFrame, CamFrameT.decode)
        .listen(
      (decoded) {
        _log.fine(
            'Received frame: ${decoded.value.frame_width}x${decoded.value.frame_height}, ${decoded.value.num_detections} detections');
        _currentFrame = CamFrameData(decoded.value);
        state = _currentFrame;
      },
      onError: (error, stackTrace) {
        _log.severe('Error in frame subscription: $error', stackTrace);
      },
    );
    _log.info('Frame subscription created successfully');
  }

  void _dispose() {
    _disposed = true;
    _log.info('Disposing CamFrameStream subscription');
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Helper to publish stream control messages
Future<void> publishStreamCtl(TransportService transport, {required bool enabled}) async {
  final msg = CamStreamCtlT(
    timestamp: DateTime.now().microsecondsSinceEpoch,
    enabled: enabled ? 1 : 0,
  );
  await transport.publish(Channels.camStreamCtl, msg);
  _log.info('Published stream_ctl: enabled=$enabled');
}

/// Helper to publish camera config
Future<void> publishCamConfig(TransportService transport, String configJson) async {
  final msg = CamConfigT(
    timestamp: DateTime.now().microsecondsSinceEpoch,
    config: configJson,
  );
  await transport.publish(Channels.camConfig, msg,
      options: const PublishOptions(retained: true));
  _log.info('Published cam_config (retained)');
}
