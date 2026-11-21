import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/features/sensors/presentation/services/sensor_data_processor.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/density_chart_widget.dart';

class SensorMetricsPanel extends ConsumerWidget {
  final SensorStatistics statistics;
  final List<double> data;
  final double? currentValue;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final int maxPoints;
  final ValueChanged<int> onMaxPointsChanged;

  const SensorMetricsPanel({
    super.key,
    required this.statistics,
    required this.data,
    required this.currentValue,
    required this.expanded,
    required this.onExpandedChanged,
    required this.maxPoints,
    required this.onMaxPointsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(colorThemeProvider).tileColor(TileColor.blue, 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed row — full-width tap target, min 48px tall
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildMetricChip('Current', currentValue),
                  const SizedBox(width: 20),
                  _buildMetricChip('Avg', statistics.average),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[500],
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Stats on the left
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricColumn('Min', statistics.minimum),
                        _buildMetricColumn('Max', statistics.maximum),
                        _buildMetricColumn('Med', statistics.median),
                        _buildMetricColumn('Std', statistics.standardDeviation),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Density chart on the right
                  Expanded(
                    flex: 4,
                    child: DensityChartWidget(
                      data: data,
                      statistics: statistics,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Samples: $maxPoints',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: accent,
                        inactiveTrackColor: Colors.grey[800],
                        thumbColor: accent,
                        overlayColor: accent.withValues(alpha: 0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                      ),
                      child: Slider(
                        value: maxPoints.toDouble(),
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        onChanged: (v) => onMaxPointsChanged(v.round()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, double? value) {
    final display = value != null ? value.toStringAsFixed(2) : '—';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
        Text(
          display,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, double value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
