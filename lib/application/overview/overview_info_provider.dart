import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/service/sensors/system_health_sensor.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';

/// What the overview panel shows besides the live sensors.
class OverviewInfo {
  final String? hostname;
  final bool networkLoaded;
  final String? ssid;
  final String? ipv4;

  const OverviewInfo({
    this.hostname,
    this.networkLoaded = false,
    this.ssid,
    this.ipv4,
  });
}

/// Cache for the overview panel. The provider is not auto-disposed, so the
/// values survive navigating away from the main screen and back: the panel
/// shows the last known data immediately and [refresh] updates it in the
/// background.
class OverviewInfoNotifier extends Notifier<OverviewInfo> {
  bool _refreshing = false;

  /// Last system-health reading with real data. A plain field (not state), so
  /// storing a new reading every 250 ms does not rebuild anything.
  SystemHealth? lastHealth;

  @override
  OverviewInfo build() => const OverviewInfo();

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final hostname = await const SystemConfigService().getHostname();
      state = OverviewInfo(
        hostname: hostname,
        networkLoaded: state.networkLoaded,
        ssid: state.ssid,
        ipv4: state.ipv4,
      );

      String? ssid;
      String? ip;
      try {
        final info = await ref.read(getDeviceInfoProvider)();
        ssid = info.connectedNetwork?.ssid;
        ip = info.ipAddress;
      } catch (_) {/* unknown: shown as "not connected" */}
      state = OverviewInfo(
        hostname: state.hostname,
        networkLoaded: true,
        ssid: ssid,
        ipv4: ip,
      );
    } finally {
      _refreshing = false;
    }
  }
}

final overviewInfoProvider =
    NotifierProvider<OverviewInfoNotifier, OverviewInfo>(
  OverviewInfoNotifier.new,
);
