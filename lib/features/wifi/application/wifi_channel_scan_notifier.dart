import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_channel_scan_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/usecases/manage_access_point.dart';

class WifiChannelScanNotifier extends Notifier<WifiChannelScanState> {
  late final ManageAccessPoint _manageAccessPoint;

  @override
  WifiChannelScanState build() {
    _manageAccessPoint = ref.read(manageAccessPointProvider);
    return const WifiChannelScanState();
  }

  Future<void> loadScan([WifiBand? band]) async {
    final selectedBand = band ?? state.selectedBand;
    state = state.copyWith(
      isLoading: true,
      selectedBand: selectedBand,
      clearError: true,
    );

    try {
      final scan =
          await _manageAccessPoint.scanAccessPointChannels(selectedBand);
      state = state.copyWith(
        isLoading: false,
        selectedBand: selectedBand,
        scan: scan,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        selectedBand: selectedBand,
        errorMessage: e.toString(),
      );
    }
  }
}

final wifiChannelScanProvider =
    NotifierProvider<WifiChannelScanNotifier, WifiChannelScanState>(
  WifiChannelScanNotifier.new,
);
