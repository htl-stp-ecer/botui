import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

class WifiClientState {
  bool isLoading;
  List<WifiNetwork> networks;
  late String? errorMessage;
  late String? connectedSsid;
  late String? forgottenSsid;
  late DeviceInfo? deviceInfo;

  WifiClientState({
    this.isLoading = false,
    this.networks = const [],
    this.errorMessage,
    this.connectedSsid,
    this.forgottenSsid,
    this.deviceInfo,
  });

  WifiClientState copyWith({
    bool? isLoading,
    List<WifiNetwork>? networks,
    String? errorMessage,
    String? connectedSsid,
    String? forgottenSsid,
    DeviceInfo? deviceInfo,

    /// Forget the result of the previous operation (error, connected network,
    /// forgotten network). Passing null for them does not, because
    /// `errorMessage ?? this.errorMessage` keeps the old value.
    bool clearResult = false,

    /// Forget only the error (a new load starts: an old error must not make
    /// the Device Info page show its error panel).
    bool clearError = false,
  }) {
    return WifiClientState(
      isLoading: isLoading ?? this.isLoading,
      networks: networks ?? this.networks,
      errorMessage: (clearResult || clearError)
          ? errorMessage
          : (errorMessage ?? this.errorMessage),
      connectedSsid:
          clearResult ? connectedSsid : (connectedSsid ?? this.connectedSsid),
      forgottenSsid:
          clearResult ? forgottenSsid : (forgottenSsid ?? this.forgottenSsid),
      deviceInfo: deviceInfo ?? this.deviceInfo,
    );
  }
}
