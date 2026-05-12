import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_channel_scan_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_channel_scan_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_channel_scan.dart';

class WifiChannelScanScreen extends ConsumerStatefulWidget {
  const WifiChannelScanScreen({super.key});

  @override
  ConsumerState<WifiChannelScanScreen> createState() =>
      _WifiChannelScanScreenState();
}

class _WifiChannelScanScreenState extends ConsumerState<WifiChannelScanScreen> {
  int? _selectedChannel;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(wifiChannelScanProvider.notifier).loadScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WifiChannelScanState>(wifiChannelScanProvider, (previous, next) {
      if (next.errorMessage == null ||
          next.errorMessage == previous?.errorMessage) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: Colors.red[700],
        ),
      );
    });

    final state = ref.watch(wifiChannelScanProvider);
    final notifier = ref.read(wifiChannelScanProvider.notifier);
    final scan = state.scan;

    if (scan != null &&
        (_selectedChannel == null ||
            !scan.channels.any((item) => item.channel == _selectedChannel))) {
      _selectedChannel = scan.recommendedChannel;
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Wi-Fi Channel Graph'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            children: [
              _ControlBar(
                selectedBand: state.selectedBand,
                isLoading: state.isLoading,
                onBandSelected: (band) => notifier.loadScan(band),
                onRefresh: () => notifier.loadScan(),
              ),
              const SizedBox(height: 10),
              if (scan != null)
                _SummaryStrip(
                  scan: scan,
                  selectedChannel: _selectedChannel ?? scan.recommendedChannel,
                )
              else
                const _LoadingStrip(),
              const SizedBox(height: 10),
              Expanded(
                child: scan == null
                    ? const _LoadingPanel()
                    : _GraphLayout(
                        scan: scan,
                        selectedChannel:
                            _selectedChannel ?? scan.recommendedChannel,
                        onChannelSelected: (channel) {
                          setState(() {
                            _selectedChannel = channel;
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.selectedBand,
    required this.isLoading,
    required this.onBandSelected,
    required this.onRefresh,
  });

  final WifiBand selectedBand;
  final bool isLoading;
  final ValueChanged<WifiBand> onBandSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF64B5F6).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_tethering_rounded,
            color: Color(0xFF64B5F6),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final band in WifiBand.values)
                  ChoiceChip(
                    label: Text(band.displayName),
                    selected: selectedBand == band,
                    onSelected: isLoading ? null : (_) => onBandSelected(band),
                    selectedColor:
                        const Color(0xFF64B5F6).withValues(alpha: 0.24),
                    backgroundColor: const Color(0xFF171D24),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color:
                          selectedBand == band ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selectedBand == band
                          ? const Color(0xFF64B5F6)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(isLoading ? 'Scanning' : 'Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.scan,
    required this.selectedChannel,
  });

  final WifiChannelScan scan;
  final int selectedChannel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Recommended',
            value: 'Ch ${scan.recommendedChannel}',
            color: const Color(0xFF66BB6A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Networks',
            value: '${scan.detectedNetworks}',
            color: const Color(0xFFFFA726),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Selected',
            value: 'Ch $selectedChannel',
            color: const Color(0xFF42A5F5),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _LoadingStatTile()),
        SizedBox(width: 8),
        Expanded(child: _LoadingStatTile()),
        SizedBox(width: 8),
        Expanded(child: _LoadingStatTile()),
      ],
    );
  }
}

class _LoadingStatTile extends StatelessWidget {
  const _LoadingStatTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _GraphLayout extends StatelessWidget {
  const _GraphLayout({
    required this.scan,
    required this.selectedChannel,
    required this.onChannelSelected,
  });

  final WifiChannelScan scan;
  final int selectedChannel;
  final ValueChanged<int> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    final selectedInfo = scan.channels.firstWhere(
      (item) => item.channel == selectedChannel,
      orElse: () => scan.channels.first,
    );
    final affectedNetworks = scan.networks
        .where((network) => network.affectedChannels.contains(selectedChannel))
        .toList()
      ..sort((a, b) {
        final signalA = a.signalDbm ?? -120;
        final signalB = b.signalDbm ?? -120;
        return signalB.compareTo(signalA);
      });

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: _cardDecoration(const Color(0xFF42A5F5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Channel Overlap Graph',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a bar to inspect that channel. Curves show overlap span by network.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _ChannelGraph(
                    scan: scan,
                    selectedChannel: selectedChannel,
                    onChannelSelected: onChannelSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: _ChannelDetailCard(
                  channelInfo: selectedInfo,
                  affectedNetworks: affectedNetworks,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _LegendCard(networks: scan.networks),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelGraph extends StatelessWidget {
  const _ChannelGraph({
    required this.scan,
    required this.selectedChannel,
    required this.onChannelSelected,
  });

  final WifiChannelScan scan;
  final int selectedChannel;
  final ValueChanged<int> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (scan.channels.isEmpty) return;
            const chartLeft = 22.0;
            final width = constraints.maxWidth - chartLeft - 8;
            if (width <= 0) return;
            final normalized = ((details.localPosition.dx - chartLeft) / width)
                .clamp(0.0, 0.9999);
            final index = (normalized * scan.channels.length).floor();
            onChannelSelected(scan.channels[index].channel);
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _WifiChannelGraphPainter(
              scan: scan,
              selectedChannel: selectedChannel,
            ),
          ),
        );
      },
    );
  }
}

class _WifiChannelGraphPainter extends CustomPainter {
  _WifiChannelGraphPainter({
    required this.scan,
    required this.selectedChannel,
  });

  final WifiChannelScan scan;
  final int selectedChannel;

  static const _palette = <Color>[
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFFFF7043),
    Color(0xFF7E57C2),
    Color(0xFF9CCC65),
    Color(0xFFFFA726),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (scan.channels.isEmpty) return;

    const leftPad = 22.0;
    const rightPad = 8.0;
    const topPad = 10.0;
    const bottomPad = 28.0;
    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );
    final maxCount = math.max(
        1, scan.channels.map((item) => item.networkCount).fold(0, math.max));
    final step = chartRect.width / scan.channels.length;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 0; i <= maxCount; i++) {
      final y = chartRect.bottom - (chartRect.height * i / maxCount);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    for (var i = 0; i < scan.channels.length; i++) {
      final channel = scan.channels[i];
      final x = chartRect.left + (i * step);
      final barRect = Rect.fromLTWH(
        x + step * 0.12,
        chartRect.bottom - (channel.networkCount / maxCount) * chartRect.height,
        step * 0.76,
        (channel.networkCount / maxCount) * chartRect.height,
      );

      final barColor = channel.isRecommended
          ? const Color(0xFF66BB6A)
          : channel.channel == selectedChannel
              ? const Color(0xFF42A5F5)
              : const Color(0xFF37474F);

      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(6)),
        Paint()..color = barColor.withValues(alpha: 0.42),
      );

      if (channel.channel == selectedChannel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(6)),
          Paint()
            ..color = const Color(0xFF42A5F5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    for (var i = 0; i < scan.channels.length; i++) {
      final centerX = chartRect.left + (i + 0.5) * step;
      final tp = TextPainter(
        text: TextSpan(text: '${scan.channels[i].channel}', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - tp.width / 2, chartRect.bottom + 6));
    }

    final countStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.60),
      fontSize: 10,
    );
    for (var i = 0; i <= maxCount; i++) {
      final y = chartRect.bottom - (chartRect.height * i / maxCount);
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: countStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    for (final network in scan.networks) {
      final color = _colorForSsid(network.ssid);
      final centerIndex = _channelIndex(network.channel);
      if (centerIndex == null) continue;
      final startIndex =
          _channelIndex(network.overlapStartChannel) ?? centerIndex;
      final endIndex = _channelIndex(network.overlapEndChannel) ?? centerIndex;
      final centerX = chartRect.left + (centerIndex + 0.5) * step;
      final startX = chartRect.left + (startIndex + 0.5) * step;
      final endX = chartRect.left + (endIndex + 0.5) * step;
      final peakFactor = _peakFactor(network);
      final peakY = chartRect.bottom - chartRect.height * peakFactor;
      final baseY = chartRect.bottom - 2;

      final path = Path()
        ..moveTo(startX, baseY)
        ..quadraticBezierTo(centerX, peakY, endX, baseY);

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = network.channel == selectedChannel ? 4 : 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  int? _channelIndex(int channel) {
    final index = scan.channels.indexWhere((item) => item.channel == channel);
    return index == -1 ? null : index;
  }

  double _peakFactor(WifiDetectedNetwork network) {
    final signal = network.signalDbm ?? -75;
    return ((signal + 90) / 50).clamp(0.18, 0.92).toDouble();
  }

  Color _colorForSsid(String ssid) {
    return _palette[ssid.hashCode.abs() % _palette.length];
  }

  @override
  bool shouldRepaint(covariant _WifiChannelGraphPainter oldDelegate) {
    return oldDelegate.scan != scan ||
        oldDelegate.selectedChannel != selectedChannel;
  }
}

class _ChannelDetailCard extends StatelessWidget {
  const _ChannelDetailCard({
    required this.channelInfo,
    required this.affectedNetworks,
  });

  final WifiChannelInfo channelInfo;
  final List<WifiDetectedNetwork> affectedNetworks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(const Color(0xFF42A5F5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Channel ${channelInfo.channel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${channelInfo.networkCount} overlapping network${channelInfo.networkCount == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: affectedNetworks.isEmpty
                ? Center(
                    child: Text(
                      'No overlapping networks.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: affectedNetworks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final network = affectedNetworks[index];
                      final color = _legendColor(network.ssid);
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: color.withValues(alpha: 0.28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              network.ssid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Primary ${network.channel} • ${_signalLabel(network)} • ${_widthLabel(network)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Center ${_frequencyLabel(network.centerFrequencyMHz)} • Span ${network.overlapStartChannel}-${network.overlapEndChannel}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.60),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _signalLabel(WifiDetectedNetwork network) {
    if (network.signalDbm != null) return '${network.signalDbm} dBm';
    if (network.qualityPercent != null) {
      return '${network.qualityPercent}% quality';
    }
    return 'signal n/a';
  }

  String _widthLabel(WifiDetectedNetwork network) {
    if (network.channelWidthMHz == null) return 'width n/a';
    return '${network.channelWidthMHz} MHz';
  }

  String _frequencyLabel(int? frequencyMHz) {
    if (frequencyMHz == null) return 'n/a';
    return '${(frequencyMHz / 1000).toStringAsFixed(3)} GHz';
  }

  Color _legendColor(String ssid) {
    return _legendPalette[ssid.hashCode.abs() % _legendPalette.length];
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({required this.networks});

  final List<WifiDetectedNetwork> networks;

  @override
  Widget build(BuildContext context) {
    final uniqueNetworks = <String, WifiDetectedNetwork>{};
    for (final network in networks) {
      uniqueNetworks.putIfAbsent(network.ssid, () => network);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(const Color(0xFFAB47BC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Same SSID, same graph color.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final network in uniqueNetworks.values)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            _legendColor(network.ssid).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _legendColor(network.ssid)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _legendColor(network.ssid),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              network.ssid,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _legendColor(String ssid) {
    return _legendPalette[ssid.hashCode.abs() % _legendPalette.length];
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(const Color(0xFF546E7A)),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

BoxDecoration _cardDecoration(Color accent) {
  return BoxDecoration(
    color: const Color(0xFF11161C),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: accent.withValues(alpha: 0.32), width: 1.3),
  );
}

const _legendPalette = <Color>[
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFFCA28),
  Color(0xFFAB47BC),
  Color(0xFF26C6DA),
  Color(0xFFFF7043),
  Color(0xFF7E57C2),
  Color(0xFF9CCC65),
  Color(0xFFFFA726),
];
