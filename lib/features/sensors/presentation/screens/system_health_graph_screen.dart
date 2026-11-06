import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/cpu_temperature_sensor.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/service/sensors/system_health_sensor.dart';
import 'package:stpvelox/core/service/sensors/temperature_sensor.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/presentation/services/sensor_data_processor.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/auto_scale_action.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/dual_sensor_graph_widget.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/sensor_graph_widget.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/sensor_metrics_panel.dart';

enum SystemHealthMetric {
  cpu('CPU Usage', '%', 0, 100),
  ram('RAM Usage', '%', 0, 100),
  cpuTemp('CPU Temperature', '°C', 0, 100),
  temperature('Temperature', '°C', -10, 100),
  battery('Battery Voltage', 'V', 0, 20);

  final String title;
  final String unit;
  final double defaultMin;
  final double defaultMax;

  const SystemHealthMetric(this.title, this.unit, this.defaultMin, this.defaultMax);
}

class SystemHealthGraphScreen extends HookConsumerWidget {
  final SystemHealthMetric metric;

  const SystemHealthGraphScreen({super.key, required this.metric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (metric == SystemHealthMetric.temperature) {
      return _buildDualTemperatureGraph(context, ref);
    }
    return _buildSingleGraph(context, ref);
  }

  Widget _buildSingleGraph(BuildContext context, WidgetRef ref) {
    const sampleInterval = Duration(milliseconds: 100);
    const defaultMaxPoints = 250;
    const movingAvgWindow = 10;

    final maxPoints = useState<int>(defaultMaxPoints);
    final frozen = useState<bool>(false);
    final metricsExpanded = useState<bool>(false);

    final dataPoints = useState<List<double>>([]);
    final movingAvgPoints = useState<List<double>>([]);
    final lastValue = useState<double?>(null);
    final autoScale = useState<bool>(false);

    final health = ref.watch(systemHealthSensorProvider);

    final reading = _extractValue(health, ref);

    useEffect(() {
      if (reading != null) {
        lastValue.value = reading;
      }
      return null;
    }, [reading]);

    useEffect(() {
      final timer = Timer.periodic(sampleInterval, (_) {
        if (frozen.value) return;
        final v = lastValue.value;
        if (v == null) return;

        final proc = SensorDataProcessor(
          maxPoints: maxPoints.value,
          movingAvgWindow: movingAvgWindow,
        );
        dataPoints.value = proc.appendToRawData(dataPoints.value, v);
        movingAvgPoints.value = proc.appendToMovingAverage(
            movingAvgPoints.value, dataPoints.value);
      });
      return timer.cancel;
    }, const []);

    useEffect(() {
      final mp = maxPoints.value;
      if (dataPoints.value.length > mp) {
        dataPoints.value = dataPoints.value.sublist(dataPoints.value.length - mp);
      }
      if (movingAvgPoints.value.length > mp) {
        movingAvgPoints.value =
            movingAvgPoints.value.sublist(movingAvgPoints.value.length - mp);
      }
      return null;
    }, [maxPoints.value]);

    final statistics = SensorDataProcessor(
      maxPoints: maxPoints.value,
      movingAvgWindow: movingAvgWindow,
    ).calculateStatistics(dataPoints.value);

    return Scaffold(
      appBar: createTopBar(
        context,
        '${metric.title} Graph',
        actions: [
          SizedBox(
            width: 56,
            height: 56,
            child: IconButton(
              icon: Icon(
                frozen.value ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () => frozen.value = !frozen.value,
            ),
          ),
          AutoScaleAction(
            value: autoScale.value,
            onChanged: (v) => autoScale.value = v,
          ),
        ],
      ),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SensorGraphWidget(
                  data: dataPoints.value,
                  movingAvg: movingAvgPoints.value,
                  graphMin: metric.defaultMin,
                  graphMax: metric.defaultMax,
                  maxPoints: maxPoints.value,
                  autoScale: autoScale.value,
                ),
              ),
              const SizedBox(height: 8),
              SensorMetricsPanel(
                statistics: statistics,
                data: dataPoints.value,
                currentValue: lastValue.value,
                expanded: metricsExpanded.value,
                onExpandedChanged: (v) => metricsExpanded.value = v,
                maxPoints: maxPoints.value,
                onMaxPointsChanged: (v) => maxPoints.value = v,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDualTemperatureGraph(BuildContext context, WidgetRef ref) {
    const sampleInterval = Duration(milliseconds: 100);
    const maxPoints = 250;
    const movingAvgWindow = 10;

    final imuProcessor = useMemoized(
      () => SensorDataProcessor(
        maxPoints: maxPoints,
        movingAvgWindow: movingAvgWindow,
      ),
    );

    final cpuProcessor = useMemoized(
      () => SensorDataProcessor(
        maxPoints: maxPoints,
        movingAvgWindow: movingAvgWindow,
      ),
    );

    final imuDataPoints = useState<List<double>>([]);
    final imuMovingAvgPoints = useState<List<double>>([]);
    final lastImuValue = useState<double?>(null);

    final cpuDataPoints = useState<List<double>>([]);
    final cpuMovingAvgPoints = useState<List<double>>([]);
    final lastCpuValue = useState<double?>(null);

    final autoScale = useState<bool>(false);

    final imuReading = useTemperature(ref);
    final cpuReading = useCpuTemperature(ref);

    useEffect(() {
      if (imuReading != null) {
        lastImuValue.value = imuReading;
      }
      return null;
    }, [imuReading]);

    useEffect(() {
      if (cpuReading != null) {
        lastCpuValue.value = cpuReading;
      }
      return null;
    }, [cpuReading]);

    useEffect(() {
      final timer = Timer.periodic(sampleInterval, (_) {
        final imuV = lastImuValue.value;
        if (imuV != null) {
          imuDataPoints.value =
              imuProcessor.appendToRawData(imuDataPoints.value, imuV);
          imuMovingAvgPoints.value = imuProcessor.appendToMovingAverage(
              imuMovingAvgPoints.value, imuDataPoints.value);
        }
        final cpuV = lastCpuValue.value;
        if (cpuV != null) {
          cpuDataPoints.value =
              cpuProcessor.appendToRawData(cpuDataPoints.value, cpuV);
          cpuMovingAvgPoints.value = cpuProcessor.appendToMovingAverage(
              cpuMovingAvgPoints.value, cpuDataPoints.value);
        }
      });
      return timer.cancel;
    }, const []);

    final imuStats = imuProcessor.calculateStatistics(imuDataPoints.value);
    final cpuStats = cpuProcessor.calculateStatistics(cpuDataPoints.value);

    return Scaffold(
      appBar: createTopBar(
        context,
        'Temperature Graph',
        actions: [
          AutoScaleAction(
            value: autoScale.value,
            onChanged: (v) => autoScale.value = v,
          ),
        ],
      ),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: DualSensorGraphWidget(
                  imuData: imuDataPoints.value,
                  imuMovingAvg: imuMovingAvgPoints.value,
                  cpuData: cpuDataPoints.value,
                  cpuMovingAvg: cpuMovingAvgPoints.value,
                  graphMin: metric.defaultMin,
                  graphMax: metric.defaultMax,
                  maxPoints: maxPoints,
                  autoScale: autoScale.value,
                ),
              ),
              const SizedBox(height: 16),
              _buildDualMetricsPanel(imuStats.average, cpuStats.average),
            ],
          ),
        ),
      ),
    );
  }

  double? _extractValue(SystemHealth health, WidgetRef ref) {
    switch (metric) {
      case SystemHealthMetric.cpu:
        return health.cpuPercent;
      case SystemHealthMetric.ram:
        return health.ramPercent;
      case SystemHealthMetric.cpuTemp:
        return health.cpuTempC;
      case SystemHealthMetric.battery:
        return useBatteryVoltage(ref);
      case SystemHealthMetric.temperature:
        return null; // Handled by dual graph
    }
  }

  Widget _buildDualMetricsPanel(double imuAvg, double cpuAvg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
              'IMU Temp Avg', imuAvg.toStringAsFixed(2), Colors.cyan),
          _buildMetricItem(
              'CPU Temp Avg', cpuAvg.toStringAsFixed(2), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
