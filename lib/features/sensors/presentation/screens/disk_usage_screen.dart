import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/system_health_sensor.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/core/utils/local_test.dart';

class DirUsage {
  final String name;
  final int bytes;

  const DirUsage(this.name, this.bytes);

  double get gb => bytes / (1024 * 1024 * 1024);
  double get mb => bytes / (1024 * 1024);

  String get sizeLabel {
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }
}

const _colors = [
  Colors.blue,
  Colors.orange,
  Colors.teal,
  Colors.red,
  Colors.purple,
  Colors.amber,
  Colors.cyan,
  Colors.pink,
  Colors.indigo,
  Colors.lime,
];

class DiskUsageScreen extends HookConsumerWidget {
  const DiskUsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(systemHealthSensorProvider);
    final entries = useState<List<DirUsage>>([]);
    final loading = useState(true);
    final touchedIndex = useState(-1);

    useEffect(() {
      _scanDisk().then((result) {
        entries.value = result;
        loading.value = false;
      });
      return null;
    }, const []);

    final totalBytes = (health.diskTotalGB * 1024 * 1024 * 1024).toInt();
    final usedBytes = (health.diskUsedGB * 1024 * 1024 * 1024).toInt();
    final freeBytes = totalBytes - usedBytes;

    return Scaffold(
      appBar: createTopBar(context, 'Disk Usage'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: loading.value
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Scanning directories...',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              )
            : Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    // Pie chart — left side
                    SizedBox(
                      width: 280,
                      child: _buildPieChart(
                          entries.value, freeBytes, touchedIndex),
                    ),
                    const SizedBox(width: 8),
                    // Legend — right side, scrollable
                    Expanded(
                      child: _buildLegend(
                          entries.value, freeBytes, totalBytes, touchedIndex),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPieChart(List<DirUsage> entries, int freeBytes,
      ValueNotifier<int> touchedIndex) {
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final isTouched = i == touchedIndex.value;
      sections.add(PieChartSectionData(
        value: e.bytes.toDouble(),
        color: _colors[i % _colors.length],
        radius: isTouched ? 90 : 80,
        title: isTouched ? e.sizeLabel : '',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        titlePositionPercentageOffset: 0.6,
      ));
    }

    // Free space slice
    final isFree = touchedIndex.value == entries.length;
    sections.add(PieChartSectionData(
      value: freeBytes.toDouble().clamp(0, double.infinity),
      color: Colors.grey[800]!,
      radius: isFree ? 90 : 80,
      title: isFree ? DirUsage('', freeBytes).sizeLabel : '',
      titleStyle: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      titlePositionPercentageOffset: 0.6,
    ));

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.touchedSection == null) {
              touchedIndex.value = -1;
              return;
            }
            touchedIndex.value =
                response.touchedSection!.touchedSectionIndex;
          },
        ),
      ),
    );
  }

  Widget _buildLegend(List<DirUsage> entries, int freeBytes, int totalBytes,
      ValueNotifier<int> touchedIndex) {
    // Center + shrinkWrap: a short list sits in the vertical middle instead of
    // at the top; a long one fills the height and scrolls as before.
    return Center(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: entries.length + 1, // +1 for free space
      itemBuilder: (context, i) {
        if (i == entries.length) {
          // Free space row
          final pct = totalBytes > 0
              ? (freeBytes / totalBytes * 100).toStringAsFixed(1)
              : '0';
          return _LegendRow(
            color: Colors.grey[800]!,
            label: 'Free',
            size: DirUsage('', freeBytes).sizeLabel,
            percent: '$pct%',
            highlighted: touchedIndex.value == i,
            onTap: () => touchedIndex.value = i,
          );
        }
        final e = entries[i];
        final pct = totalBytes > 0
            ? (e.bytes / totalBytes * 100).toStringAsFixed(1)
            : '0';
        return _LegendRow(
          color: _colors[i % _colors.length],
          label: e.name,
          size: e.sizeLabel,
          percent: '$pct%',
          highlighted: touchedIndex.value == i,
          onTap: () => touchedIndex.value = i,
        );
      },
      ),
    );
  }

  static Future<List<DirUsage>> _scanDisk() async {
    try {
      // Scan known real directories individually via sudo du -sxb
      // -s: summary per arg, -x: stay on same filesystem, -b: bytes
      const dirs = [
        '/usr', '/var', '/home', '/opt', '/etc', '/boot',
        '/root', '/srv', '/lib', '/snap', '/bin', '/sbin',
        '/media', '/mnt', '/tmp',
      ];

      final result = kLocalTest
          ? ProcessResult(0, 0, '', '')
          : await Process.run(
              'sudo',
              ['du', '-sxb', ...dirs],
              environment: {'LC_ALL': 'C'},
            );

      final lines = result.stdout.toString().split('\n');
      final entries = <DirUsage>[];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final tab = line.indexOf('\t');
        if (tab < 0) continue;

        final bytes = int.tryParse(line.substring(0, tab).trim());
        final path = line.substring(tab + 1).trim();
        if (bytes == null || bytes == 0) continue;

        final name = path.startsWith('/') ? path.substring(1) : path;
        if (name.isEmpty) continue;
        entries.add(DirUsage(name, bytes));
      }

      // Sort descending by size, keep top slices
      entries.sort((a, b) => b.bytes.compareTo(a.bytes));

      const maxSlices = 8;
      if (entries.length > maxSlices) {
        final top = entries.sublist(0, maxSlices - 1);
        final otherBytes = entries
            .sublist(maxSlices - 1)
            .fold<int>(0, (sum, e) => sum + e.bytes);
        top.add(DirUsage('other', otherBytes));
        return top;
      }

      return entries;
    } catch (_) {
      return [];
    }
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String size;
  final String percent;
  final bool highlighted;
  final VoidCallback onTap;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.size,
    required this.percent,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: highlighted ? Colors.grey[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '/$label',
                style: TextStyle(
                  color: highlighted ? Colors.white : Colors.grey[400],
                  fontSize: 12,
                  fontWeight:
                      highlighted ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              size,
              style: TextStyle(
                color: highlighted ? color : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 40,
              child: Text(
                percent,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: highlighted ? Colors.white70 : Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
