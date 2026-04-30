import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/lcm/domain/services/lcm_service.dart';
import 'package:stpvelox/core/logging/logging.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
LcmService lcmService(Ref ref) {
  final service = LcmService();

  service.init().catchError((e) {
    getLogger("LCM").severe('Failed to initialize LCM service: $e');
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
