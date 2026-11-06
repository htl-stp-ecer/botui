import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/service/sensors/system_health_sensor.dart';
import 'package:stpvelox/core/service/sensors/temperature_sensor.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/presentation/screens/system_health_graph_screen.dart';

class SystemHealthScreen extends HookConsumerWidget {
  const SystemHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(systemHealthSensorProvider);
    final imuTemp = useTemperature(ref);
    final battery = useBatteryVoltage(ref);

    return Scaffold(
      appBar: createTopBar(context, 'System Health'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              _MetricCard(
                icon: Icons.memory,
                label: 'CPU',
                value: '${health.cpuPercent.toStringAsFixed(0)}%',
                progress: health.cpuPercent / 100,
                color: _percentColor(health.cpuPercent),
                onTap: () => context.pushOnce(
                  AppRoutes.systemHealthGraph,
                  extra: SystemHealthMetric.cpu,
                ),
              ),
              _MetricCard(
                icon: Icons.storage,
                label: 'RAM',
                value: '${health.ramUsedMB} / ${health.ramTotalMB} MB',
                progress: health.ramPercent / 100,
                color: _percentColor(health.ramPercent),
                onTap: () => context.pushOnce(
                  AppRoutes.systemHealthGraph,
                  extra: SystemHealthMetric.ram,
                ),
              ),
              _MetricCard(
                icon: Icons.sd_storage,
                label: 'Disk',
                value:
                    '${health.diskUsedGB.toStringAsFixed(1)} / ${health.diskTotalGB.toStringAsFixed(1)} GB',
                progress: health.diskPercent / 100,
                color: _percentColor(health.diskPercent),
                onTap: () => context.pushOnce(AppRoutes.diskUsage),
              ),
              _MetricCard(
                icon: Icons.thermostat,
                label: 'CPU Temp',
                value: '${health.cpuTempC.toStringAsFixed(1)}°C',
                color: _tempColor(health.cpuTempC),
                onTap: () => context.pushOnce(
                  AppRoutes.systemHealthGraph,
                  extra: SystemHealthMetric.temperature,
                ),
              ),
              _MetricCard(
                icon: Icons.device_thermostat,
                label: 'IMU Temp',
                value: imuTemp != null
                    ? '${imuTemp.toStringAsFixed(1)}°C'
                    : '--',
                color: _tempColor(imuTemp ?? 0),
                onTap: () => context.pushOnce(
                  AppRoutes.systemHealthGraph,
                  extra: SystemHealthMetric.temperature,
                ),
              ),
              _MetricCard(
                icon: Icons.battery_full,
                label: 'Battery',
                value: battery != null
                    ? '${battery.toStringAsFixed(2)} V'
                    : '--',
                color: Colors.green,
                onTap: () => context.pushOnce(
                  AppRoutes.systemHealthGraph,
                  extra: SystemHealthMetric.battery,
                ),
              ),
              _MetricCard(
                icon: Icons.timer,
                label: 'Uptime',
                value: _formatUptime(health.uptimeSeconds),
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _percentColor(double percent) {
    if (percent > 85) return Colors.red;
    if (percent > 60) return Colors.orange;
    return Colors.green;
  }

  static Color _tempColor(double tempC) {
    if (tempC > 70) return Colors.red;
    if (tempC > 50) return Colors.orange;
    return Colors.green;
  }

  static String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? progress;
  final Color color;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Row(
          children: [
            if (progress != null)
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress!.clamp(0, 1),
                      strokeWidth: 5,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Icon(icon, color: color, size: 22),
                  ],
                ),
              )
            else
              Icon(icon, color: color, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey[600], size: 24),
          ],
        ),
      ),
    );
  }
}
