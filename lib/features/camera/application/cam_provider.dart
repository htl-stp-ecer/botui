import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/lcm/domain/services/lcm_service.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';
import 'package:stpvelox/core/logging/logging.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'cam_provider.g.dart';

final _log = getLogger('CameraViewer');
const _defaultCamFrameProvider = 'udpm://239.255.76.68:7668?ttl=0';
const _camFrameProvider = String.fromEnvironment(
  'CAM_FRAME_LCM_PROVIDER',
  defaultValue: _defaultCamFrameProvider,
);

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
  StreamSubscription<LcmDecoded<CamDetectionsT>>? _subscription;
  CamDetectionData? _currentDetections;

  @override
  CamDetectionData? build() {
    _log.info('CamDetectionStream build() called');
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentDetections;
  }

  void _startSubscription() {
    final lcm = ref.read(lcmServiceProvider);
    _log.info('Starting subscription to channel: ${Channels.camDetections}');

    _subscription = lcm
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
  StreamSubscription<LcmDecoded<CamFrameT>>? _subscription;
  CamFrameData? _currentFrame;
  LcmService? _frameLcm;
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
    _frameLcm = LcmService();
    _frameLcm!.init(provider: _camFrameProvider).then((_) {
      if (_disposed) return;

      _log.info(
          'Starting frame subscription to channel: ${Channels.camFrame} on $_camFrameProvider');
      _subscription = _frameLcm!
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
    }).catchError((error, stackTrace) {
      _log.severe('Failed to initialize frame transport: $error', stackTrace);
    });
  }

  void _dispose() {
    _disposed = true;
    _log.info('Disposing CamFrameStream subscription');
    _subscription?.cancel();
    _subscription = null;
    _frameLcm?.dispose();
    _frameLcm = null;
  }
}

/// Helper to publish stream control messages
Future<void> publishStreamCtl(LcmService lcm, {required bool enabled}) async {
  final msg = CamStreamCtlT(
    timestamp: DateTime.now().microsecondsSinceEpoch,
    enabled: enabled ? 1 : 0,
  );
  await lcm.publish(Channels.camStreamCtl, msg);
  _log.info('Published stream_ctl: enabled=$enabled');
}

/// Helper to publish camera config
Future<void> publishCamConfig(LcmService lcm, String configJson) async {
  final msg = CamConfigT(
    timestamp: DateTime.now().microsecondsSinceEpoch,
    config: configJson,
  );
  await lcm.publish(Channels.camConfig, msg,
      options: const PublishOptions(retained: true));
  _log.info('Published cam_config (retained)');
}
