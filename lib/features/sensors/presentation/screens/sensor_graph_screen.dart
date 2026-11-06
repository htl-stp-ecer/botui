import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_type.dart';
import 'package:stpvelox/features/sensors/presentation/services/sensor_data_processor.dart';
import 'package:stpvelox/features/sensors/presentation/utils/sensor_strategy_factory.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/auto_scale_action.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/sensor_graph_widget.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/sensor_metrics_panel.dart';

class SensorGraphScreen extends HookConsumerWidget {
  final Sensor sensor;
  final double graphMin;
  final double graphMax;
  final SensorType sensorType;
  final int? port;

  const SensorGraphScreen({
    super.key,
    required this.sensor,
    required this.graphMin,
    required this.graphMax,
    required this.sensorType,
    this.port,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const sampleInterval = Duration(milliseconds: 20);
    const defaultMaxPoints = 250;
    const movingAvgWindow = 10;

    final maxPoints = useState<int>(defaultMaxPoints);
    final frozen = useState<bool>(false);
    final autoScale = useState<bool>(false);
    final metricsExpanded = useState<bool>(false);

    final dataPoints = useState<List<double>>([]);
    final movingAvgPoints = useState<List<double>>([]);
    final lastValue = useState<double?>(null);

    final strategy = useMemoized(
      () => SensorStrategyFactory.createStrategy(sensorType),
      [sensorType],
    );
    final reading = strategy.readValue(ref, port);

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

        final mp = maxPoints.value;
        final proc = SensorDataProcessor(
          maxPoints: mp,
          movingAvgWindow: movingAvgWindow,
        );
        dataPoints.value = proc.appendToRawData(dataPoints.value, v);
        movingAvgPoints.value =
            proc.appendToMovingAverage(movingAvgPoints.value, dataPoints.value);
      });
      return timer.cancel;
    }, const []);

    // Trim data when maxPoints decreases
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
        "${sensor.name} Graph",
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
                  graphMin: graphMin,
                  graphMax: graphMax,
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
}
