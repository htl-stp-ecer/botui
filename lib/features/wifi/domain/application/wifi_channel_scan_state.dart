import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_channel_scan.dart';

class WifiChannelScanState {
  const WifiChannelScanState({
    this.isLoading = false,
    this.selectedBand = WifiBand.bandAuto,
    this.scan,
    this.errorMessage,
  });

  final bool isLoading;
  final WifiBand selectedBand;
  final WifiChannelScan? scan;
  final String? errorMessage;

  WifiChannelScanState copyWith({
    bool? isLoading,
    WifiBand? selectedBand,
    WifiChannelScan? scan,
    String? errorMessage,
    bool clearScan = false,
    bool clearError = false,
  }) {
    return WifiChannelScanState(
      isLoading: isLoading ?? this.isLoading,
      selectedBand: selectedBand ?? this.selectedBand,
      scan: clearScan ? null : (scan ?? this.scan),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
