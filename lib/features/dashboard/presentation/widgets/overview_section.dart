import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/utils/battery_level.dart';
import 'package:stpvelox/core/utils/radii.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';

/// The overview/status half of the main screen: a centered vertical stack.
class OverviewSection extends ConsumerStatefulWidget {
  const OverviewSection({super.key});

  @override
  ConsumerState<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends ConsumerState<OverviewSection> {
  String _hostname = '';
  String? _ssid;
  String? _ipv4;
  bool _networkLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHostname();
    _loadNetwork();
  }

  Future<void> _loadHostname() async {
    final name = await const SystemConfigService().getHostname();
    if (mounted) setState(() => _hostname = name);
  }

  Future<void> _loadNetwork() async {
    String? ssid;
    String? ip;
    try {
      final info = await ref.read(getDeviceInfoProvider)();
      ssid = info.connectedNetwork?.ssid;
      ip = info.ipAddress;
    } catch (_) {/* leave unknown, shown as "not connected" */}
    if (!mounted) return;
    setState(() {
      _ssid = ssid;
      _ipv4 = ip;
      _networkLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = _ssid != null && _ssid!.isNotEmpty;
    final voltage = useBatteryVoltage(ref);
    final hasBattery = voltage != null && voltage > 0;
    final percent = hasBattery ? BatteryLevel.percentFromVoltage(voltage) : 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.all(AppRadii.outerRadius),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/raccoon-logo.png', width: 70, height: 70),
            const SizedBox(height: 16),
            Text(
              _hostname,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Divider(color: Colors.grey[700], height: 1),
            ),
            const SizedBox(height: 16),
            if (_networkLoaded) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.grey[400],
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connected ? _ssid! : 'Not connected',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _ipv4 ?? '',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
            if (hasBattery) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Divider(color: Colors.grey[700], height: 1),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.battery_4_bar_rounded,
                    color: percent < 15 ? Colors.redAccent : Colors.grey[400],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent %',
                    style: TextStyle(
                      color: percent < 15 ? Colors.redAccent : Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${voltage.toStringAsFixed(2)} V',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
