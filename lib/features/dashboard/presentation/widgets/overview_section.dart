import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/overview/overview_info_provider.dart';
import 'package:stpvelox/core/router/route_observer.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/service/sensors/system_health_sensor.dart';
import 'package:stpvelox/core/utils/radii.dart';

/// The overview/status half of the main screen: a centered vertical stack.
class OverviewSection extends ConsumerStatefulWidget {
  const OverviewSection({super.key});

  @override
  ConsumerState<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends ConsumerState<OverviewSection> with RouteAware {
  ModalRoute<void>? _route;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    // The data is cached (see overviewInfoProvider): the panel shows the last
    // known values right away and this refreshes them in the background.
    _refresh();
    // On boot the network is often not up yet when the first lookup runs, so
    // keep retrying until a connection shows up.
    _retryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final info = ref.read(overviewInfoProvider);
      final connected = info.ssid != null && info.ssid!.isNotEmpty;
      final hasIp = info.ipv4 != null && info.ipv4!.isNotEmpty;
      if (!connected || !hasIp) _refresh();
    });
  }

  void _refresh() {
    Future.microtask(() {
      if (mounted) ref.read(overviewInfoProvider.notifier).refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The main screen stays mounted under the pages opened from it (they are pushed),
    // so initState does not run again when one is closed: refresh on didPopNext.
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route = route;
      appRouteObserver.unsubscribe(this);
      if (route != null) appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _refresh();

  @override
  void dispose() {
    _retryTimer?.cancel();
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(overviewInfoProvider);
    final ssid = info.ssid;
    final ipv4 = info.ipv4;
    final connected = ssid != null && ssid.isNotEmpty;
    // In hotspot mode there is no client network; show the hotspot's name.
    final hotspotSsid = connected ? null : info.hotspotSsid;
    final voltage = useBatteryVoltage(ref);
    final hasBattery = voltage != null && voltage > 0;

    // The health sensor is recreated (and starts at zeros) every time the main
    // screen is shown, so fall back to the last real reading until new data
    // arrives. Nothing is shown before the very first reading.
    final live = ref.watch(systemHealthSensorProvider);
    final notifier = ref.read(overviewInfoProvider.notifier);
    if (live.ramTotalMB > 0) notifier.lastHealth = live;
    final health = live.ramTotalMB > 0 ? live : notifier.lastHealth;

    // Divider between sections, inset from the panel edge.
    const section = [
      SizedBox(height: 14),
      _InsetDivider(),
      SizedBox(height: 14),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.all(AppRadii.outerRadius),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Identity
            Image.asset('assets/raccoon-logo.png', width: 70, height: 70),
            const SizedBox(height: 16),
            Text(
              info.hostname ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),

            // 2. Network (N/A while unknown)
            ...[
              ...section,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected
                        ? Icons.wifi
                        : hotspotSsid != null
                            ? Icons.wifi_tethering
                            : Icons.wifi_off,
                    color: Colors.grey[400],
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !info.networkLoaded
                        ? 'N/A'
                        : (connected
                            ? ssid
                            : (hotspotSsid ?? 'Not connected')),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                (ipv4 != null && ipv4.isNotEmpty) ? ipv4 : 'N/A',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],

            // 3. Stats: battery, CPU, RAM and disk stacked
            ...[
              ...section,
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _StatRow(
                      icon: Icons.battery_4_bar_rounded,
                      label: 'Battery',
                      value: hasBattery
                          ? '${voltage.toStringAsFixed(2)} V'
                          : 'N/A',
                    ),
                    if (health != null) const SizedBox(height: 6),
                    if (health != null) ...[
                      _StatRow(
                        icon: Icons.memory,
                        label: 'CPU',
                        value: '${health.cpuPercent.toStringAsFixed(0)} %',
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.storage,
                        label: 'RAM',
                        value: '${health.ramPercent.toStringAsFixed(0)} %',
                        detail: '${health.ramUsedMB} / ${health.ramTotalMB} MB',
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.sd_storage,
                        label: 'Disk',
                        value: '${health.diskPercent.toStringAsFixed(0)} %',
                        detail:
                            '${health.diskUsedGB.toStringAsFixed(1)} / ${health.diskTotalGB.toStringAsFixed(1)} GB',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Divider(color: Colors.grey[700], height: 1),
    );
  }
}

/// One stat line: icon and label on the left, the value on the right,
/// optionally a grey detail (e.g. "1234 / 4096 MB") before it.
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ),
        if (detail != null) ...[
          Text(
            detail!,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(width: 10),
        ],
        // Fixed width so the values line up in a column.
        SizedBox(
          width: 58,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
