import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart';
import 'package:stpvelox/core/logging/logging.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
TransportService transportService(Ref ref) {
  final service = TransportService();

  service.init().catchError((e) {
    getLogger("Transport").severe('Failed to initialize transport service: $e');
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
