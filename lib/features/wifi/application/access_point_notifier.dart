import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/access_point_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/usecases/manage_access_point.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

class AccessPointNotifier extends Notifier<AccessPointState> {
  late final ManageAccessPoint manageAccessPoint;

  @override
  AccessPointState build() {
    manageAccessPoint = ref.read(manageAccessPointProvider);
    return AccessPointState();
  }

  Future<bool> isStarted() async {
    try {
      return await manageAccessPoint.isAccessPointActive();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> refreshStatus() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isActive = await manageAccessPoint.isAccessPointActive();
      final config = await manageAccessPoint.getAccessPointConfig();
      final deviceInfo = await ref.read(wifiRepositoryProvider).getDeviceInfo();
      state = state.copyWith(
        isStarted: isActive,
        config: config,
        ipAddress: _hotspotIpAddress(deviceInfo),
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startAccessPoint(AccessPointConfig config) async {
    state = state.copyWith(isLoading: true);
    try {
      await manageAccessPoint.startAccessPoint(config);
      final deviceInfo = await ref.read(wifiRepositoryProvider).getDeviceInfo();
      state = state.copyWith(
        config: config,
        isLoading: false,
        isStarted: true,
        ipAddress: _hotspotIpAddress(deviceInfo),
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> stopAccessPoint() async {
    state = state.copyWith(isLoading: true);
    try {
      await manageAccessPoint.stopAccessPoint();
      state = state.copyWith(
        isStarted: false,
        ipAddress: null,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> loadAccessPointConfig() async {
    await refreshStatus();
  }

  Future<void> startAccessPointWithLastConfig() async {
    state = state.copyWith(isLoading: true);
    try {
      final config = await manageAccessPoint.getAccessPointConfig();
      if (config != null) {
        await manageAccessPoint.startAccessPoint(config);
        final deviceInfo =
            await ref.read(wifiRepositoryProvider).getDeviceInfo();
        state = state.copyWith(
          config: config,
          isStarted: true,
          isLoading: false,
          ipAddress: _hotspotIpAddress(deviceInfo),
          errorMessage: null,
        );
      } else {
        final defaultBand = await manageAccessPoint.findBestWifiBand();
        final defaultConfig = AccessPointConfig(
          ssid: 'STP-Velox-Robot',
          password: 'Robot123!',
          band: defaultBand,
        );
        await manageAccessPoint.startAccessPoint(defaultConfig);
        final deviceInfo =
            await ref.read(wifiRepositoryProvider).getDeviceInfo();
        state = state.copyWith(
          isStarted: true,
          config: defaultConfig,
          isLoading: false,
          ipAddress: _hotspotIpAddress(deviceInfo),
          errorMessage: null,
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  String? _hotspotIpAddress(DeviceInfo deviceInfo) {
    return deviceInfo.wifiIpAddress ?? deviceInfo.ipAddress;
  }

  // Alias methods for UI compatibility
  Future<void> startHotspot(AccessPointConfig config) async {
    await startAccessPoint(config);
  }

  Future<void> stopHotspot() async {
    await stopAccessPoint();
  }
}
