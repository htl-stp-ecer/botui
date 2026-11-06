import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';

class AccessPointState {
  bool isStarted;
  AccessPointConfig? config;
  String? errorMessage;
  String? ipAddress;
  int connectedClients;
  bool isLoading;

  static const Object _unset = Object();

  AccessPointState({
    this.isStarted = false,
    this.config,
    this.errorMessage,
    this.ipAddress,
    this.connectedClients = 0,
    this.isLoading = false,
  });

  AccessPointState copyWith({
    bool? isStarted,
    Object? config = _unset,
    Object? errorMessage = _unset,
    Object? ipAddress = _unset,
    int? connectedClients,
    bool? isLoading,
  }) {
    return AccessPointState(
      isStarted: isStarted ?? this.isStarted,
      config: identical(config, _unset)
          ? this.config
          : config as AccessPointConfig?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      ipAddress:
          identical(ipAddress, _unset) ? this.ipAddress : ipAddress as String?,
      connectedClients: connectedClients ?? this.connectedClients,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
