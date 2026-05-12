import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/features/settings/domain/usecases/manage_lan_only_mode.dart';
import 'package:stpvelox/features/settings/domain/usecases/manage_saved_networks.dart';
import 'package:stpvelox/features/settings/domain/usecases/set_network_mode.dart';
import 'package:stpvelox/features/settings/usecases/get_device_info.dart';
import 'package:stpvelox/features/wifi/application/access_point_notifier.dart';
import 'package:stpvelox/features/wifi/application/lan_only_notifier.dart';
import 'package:stpvelox/features/wifi/data/datasource/raccoon_network_api.dart';
import 'package:stpvelox/features/wifi/data/repositories/wifi_repository_impl.dart';
import 'package:stpvelox/features/wifi/domain/application/access_point_state.dart';
import 'package:stpvelox/features/wifi/domain/application/lan_only_state.dart';
import 'package:stpvelox/features/wifi/domain/repositories/i_wifi_repository.dart';
import 'package:stpvelox/features/wifi/domain/usecases/forget_wifi.dart';
import 'package:stpvelox/features/wifi/domain/usecases/manage_access_point.dart';
import 'package:stpvelox/features/wifi/usecases/connect_to_wifi.dart';
import 'package:stpvelox/features/wifi/usecases/get_available_networks.dart';
import 'package:stpvelox/features/wifi/usecases/get_network_mode.dart';

part 'wifi_provider.g.dart';

@riverpod
RaccoonNetworkApi raccoonNetworkApi(Ref ref) {
  return RaccoonNetworkApi();
}

@riverpod
IWifiRepository wifiRepository(Ref ref) {
  return WifiRepositoryImpl(api: ref.watch(raccoonNetworkApiProvider));
}

@riverpod
ForgetWifi forgetWifi(Ref ref) {
  return ForgetWifi(repository: ref.watch(wifiRepositoryProvider));
}

final accessPointProvider =
    NotifierProvider<AccessPointNotifier, AccessPointState>(
  AccessPointNotifier.new,
);

@riverpod
ManageAccessPoint manageAccessPoint(Ref ref) {
  return ManageAccessPoint(ref.watch(wifiRepositoryProvider));
}

@riverpod
GetNetworkMode getNetworkMode(Ref ref) {
  return GetNetworkMode(ref.watch(wifiRepositoryProvider));
}

@riverpod
GetAvailableNetworks getAvailableNetworks(Ref ref) {
  return GetAvailableNetworks(repository: ref.watch(wifiRepositoryProvider));
}

@riverpod
ConnectToWifi connectToWifi(Ref ref) {
  return ConnectToWifi(repository: ref.watch(wifiRepositoryProvider));
}

@riverpod
GetDeviceInfo getDeviceInfo(Ref ref) {
  return GetDeviceInfo(repository: ref.watch(wifiRepositoryProvider));
}

@riverpod
ManageSavedNetworks manageSavedNetworks(Ref ref) {
  return ManageSavedNetworks(ref.watch(wifiRepositoryProvider));
}

@riverpod
SetNetworkMode setNetworkMode(Ref ref) {
  return SetNetworkMode(ref.watch(wifiRepositoryProvider));
}

@riverpod
ManageLanOnlyMode manageLanOnlyMode(Ref ref) {
  return ManageLanOnlyMode(ref.watch(wifiRepositoryProvider));
}

final lanOnlyProvider = NotifierProvider<LanOnlyNotifier, LanOnlyState>(
  LanOnlyNotifier.new,
);
