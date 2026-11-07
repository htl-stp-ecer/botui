import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/service/sensors/system_health_sensor.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

/// What the overview panel shows besides the live sensors.
class OverviewInfo {
  final String? hostname;
  final bool networkLoaded;
  final String? ssid;
  final String? ipv4;

  /// Name of the robot's own hotspot while it is active, else null.
  final String? hotspotSsid;

  const OverviewInfo({
    this.hostname,
    this.networkLoaded = false,
    this.ssid,
    this.ipv4,
    this.hotspotSsid,
  });

  // Value equality: a refresh that returns the same data does not notify
  // listeners, so nothing rebuilds or flickers.
  @override
  bool operator ==(Object other) =>
      other is OverviewInfo &&
      other.hostname == hostname &&
      other.networkLoaded == networkLoaded &&
      other.ssid == ssid &&
      other.ipv4 == ipv4 &&
      other.hotspotSsid == hotspotSsid;

  @override
  int get hashCode => Object.hash(hostname, networkLoaded, ssid, ipv4, hotspotSsid);
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

  /// Stale-while-revalidate: the cached [state] stays on screen while the
  /// fresh data is fetched. It is only replaced by data that was actually
  /// read, so a failed or empty fetch never turns the old values into
  /// "Not connected" / blank, and identical data causes no rebuild.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        const SystemConfigService().getHostname().then<String?>((v) => v),
        ref
            .read(getDeviceInfoProvider)()
            .then<DeviceInfo?>((v) => v)
            .catchError((_) => null as DeviceInfo?),
        _hotspotSsid(),
      ]);
      final hostname = results[0] as String?;
      final device = results[1] as DeviceInfo?;
      // (known, ssid): a failed lookup keeps the old value.
      final hotspot = results[2] as (bool, String?);

      state = OverviewInfo(
        hostname: (hostname != null && hostname.isNotEmpty)
            ? hostname
            : state.hostname,
        // Keep the old network data if the lookup failed.
        networkLoaded: state.networkLoaded || device != null,
        ssid: device != null ? device.connectedNetwork?.ssid : state.ssid,
        ipv4: device != null ? device.ipAddress : state.ipv4,
        hotspotSsid: hotspot.$1 ? hotspot.$2 : state.hotspotSsid,
      );
    } finally {
      _refreshing = false;
    }
  }
}

extension on OverviewInfoNotifier {
  /// The hotspot's SSID if it is running: (true, ssid) / (true, null) when it
  /// is off, (false, null) if the robot could not be asked.
  Future<(bool, String?)> _hotspotSsid() async {
    try {
      final manage = ref.read(manageAccessPointProvider);
      if (!await manage.isAccessPointActive()) return (true, null);
      final config = await manage.getAccessPointConfig();
      final ssid = config?.ssid;
      return (true, (ssid != null && ssid.isNotEmpty) ? ssid : null);
    } catch (_) {
      return (false, null);
    }
  }
}

final overviewInfoProvider =
    NotifierProvider<OverviewInfoNotifier, OverviewInfo>(
  OverviewInfoNotifier.new,
);
