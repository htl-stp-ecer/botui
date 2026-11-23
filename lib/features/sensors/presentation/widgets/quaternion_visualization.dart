import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/imu_accuracy_sensor.dart';
import 'package:stpvelox/core/service/sensors/quaternion_sensor.dart';
import 'package:stpvelox/core/service/sensors/temperature_sensor.dart';
import 'package:stpvelox/core/widgets/imu_accuracy_display.dart';

class QuaternionVisualization extends HookConsumerWidget {
  static const int maxPoints = 250;
  static const Duration sampleInterval = Duration(milliseconds: 20);
  static const double graphMin = -180;
  static const double graphMax = 180;

  const QuaternionVisualization({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quaternion = useQuaternion(ref);
    final accuracy = useImuAccuracy(ref);
    final temperature = useTemperature(ref);

    final rollData = useState<List<double>>([]);
    final pitchData = useState<List<double>>([]);
    final yawData = useState<List<double>>([]);

    // The reader publishes a value only while it changes, so the graph is driven
    // by a timer that appends the latest known orientation. It keeps scrolling
    // while the robot stands still.
    final latest = useRef<Quaternion?>(null);
    latest.value = quaternion;

    useEffect(() {
      final timer = Timer.periodic(sampleInterval, (_) {
        final q = latest.value;
        if (q == null) return;
        final euler = q.toEulerAngles();

        // Add new data and keep only the last maxPoints
        final newRoll = [...rollData.value, euler.roll];
        final newPitch = [...pitchData.value, euler.pitch];
        final newYaw = [...yawData.value, euler.yaw];

        rollData.value = newRoll.length > maxPoints
            ? newRoll.sublist(newRoll.length - maxPoints)
            : newRoll;
        pitchData.value = newPitch.length > maxPoints
            ? newPitch.sublist(newPitch.length - maxPoints)
            : newPitch;
        yawData.value = newYaw.length > maxPoints
            ? newYaw.sublist(newYaw.length - maxPoints)
            : newYaw;
      });
      return timer.cancel;
    }, const []);

    if (quaternion == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for quaternion data...'),
          ],
        ),
      );
    }

    final euler = quaternion.toEulerAngles();

    return Column(
      children: [
        // Current values row
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ValueChip(label: 'Roll', value: euler.roll, color: Colors.red),
              _ValueChip(label: 'Pitch', value: euler.pitch, color: Colors.green),
              _ValueChip(label: 'Yaw', value: euler.yaw, color: Colors.blue),
              _AccuracyChip(accuracy: accuracy.quaternion),
              _TemperatureChip(temperature: temperature),
            ],
          ),
        ),
        // Graph
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
            child: _EulerGraph(
              rollData: rollData.value,
              pitchData: pitchData.value,
              yawData: yawData.value,
              maxPoints: maxPoints,
              graphMin: graphMin,
              graphMax: graphMax,
            ),
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Colors.red, label: 'Roll'),
              const SizedBox(width: 24),
              _LegendItem(color: Colors.green, label: 'Pitch'),
              const SizedBox(width: 24),
              _LegendItem(color: Colors.blue, label: 'Yaw'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ValueChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            '${value.toStringAsFixed(1)}°',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _AccuracyChip extends StatelessWidget {
  final int? accuracy;

  const _AccuracyChip({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final color = ImuAccuracyDisplay.getAccuracyColor(accuracy);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Acc', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            '${accuracy ?? "?"}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _TemperatureChip extends StatelessWidget {
  final double? temperature;

  const _TemperatureChip({required this.temperature});

  Color _getColor() {
    if (temperature == null) return Colors.grey;
    if (temperature! < 20) return Colors.blue;
    if (temperature! < 30) return Colors.green;
    if (temperature! < 45) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thermostat, color: color, size: 16),
          Text(
            temperature != null ? '${temperature!.toStringAsFixed(1)}°' : '--',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EulerGraph extends StatelessWidget {
  final List<double> rollData;
  final List<double> pitchData;
  final List<double> yawData;
  final int maxPoints;
  final double graphMin;
  final double graphMax;

  const _EulerGraph({
    required this.rollData,
    required this.pitchData,
    required this.yawData,
    required this.maxPoints,
    required this.graphMin,
    required this.graphMax,
  });

  @override
  Widget build(BuildContext context) {
    if (rollData.isEmpty) {
      return const Center(
        child: Text("Collecting data...", style: TextStyle(color: Colors.white70)),
      );
    }

    final rollSpots = _createSpots(rollData);
    final pitchSpots = _createSpots(pitchData);
    final yawSpots = _createSpots(yawData);

    return RepaintBoundary(
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          clipData: const FlClipData.all(),
          minX: 0,
          maxX: (maxPoints - 1).toDouble(),
          minY: graphMin,
          maxY: graphMax,
          gridData: _buildGridData(),
          titlesData: _buildTitlesData(),
          borderData: _buildBorderData(),
          lineBarsData: [
            _buildLineData(rollSpots, Colors.red),
            _buildLineData(pitchSpots, Colors.green),
            _buildLineData(yawSpots, Colors.blue),
          ],
          lineTouchData: _buildTouchData(),
        ),
      ),
    );
  }

  List<FlSpot> _createSpots(List<double> data) {
    return List<FlSpot>.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i]),
    );
  }

  FlGridData _buildGridData() {
    const samplesPerSecond = 50;
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: 45,
      verticalInterval: samplesPerSecond.toDouble(),
      getDrawingHorizontalLine: (value) => FlLine(
        color: Colors.grey.withOpacity(0.3),
        strokeWidth: 1,
      ),
      getDrawingVerticalLine: (value) => FlLine(
        color: Colors.grey.withOpacity(0.2),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    const samplesPerSecond = 50;
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: 90,
          getTitlesWidget: (value, _) => Text(
            '${value.toInt()}°',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: samplesPerSecond.toDouble(),
          getTitlesWidget: (value, _) {
            final idx = value.toInt();
            if (idx % samplesPerSecond == 0) {
              final seconds = (idx / samplesPerSecond).toStringAsFixed(0);
              return Text('${seconds}s', style: const TextStyle(color: Colors.white70, fontSize: 12));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: const Border(
        left: BorderSide(color: Colors.white),
        bottom: BorderSide(color: Colors.white),
        right: BorderSide(color: Colors.transparent),
        top: BorderSide(color: Colors.transparent),
      ),
    );
  }

  LineChartBarData _buildLineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final labels = ['Roll', 'Pitch', 'Yaw'];
            final colors = [Colors.red, Colors.green, Colors.blue];
            return LineTooltipItem(
              '${labels[spot.barIndex]}: ${spot.y.toStringAsFixed(1)}°',
              TextStyle(color: colors[spot.barIndex]),
            );
          }).toList();
        },
      ),
    );
  }
}
