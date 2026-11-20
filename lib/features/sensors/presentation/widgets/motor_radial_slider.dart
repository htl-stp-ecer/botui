import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

class MotorRadialSlider extends ConsumerWidget {
  final bool mounted;
  final double value, min, max;
  final String label, valueStr;
  final ValueChanged<double> onChange, onChangeEnd;

  const MotorRadialSlider({
    super.key,
    required this.mounted,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.valueStr,
    required this.onChange,
    required this.onChangeEnd,
  });

  static const double _size = 400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return LayoutBuilder(builder: (context, constraints) {
      // The visible half dial is _size / 2 high; centre it vertically in the
      // available area (the dial's centre line sits _size / 2 above the
      // bottom of the square the slider paints into).
      final bottom = (constraints.maxHeight - _size / 2) / 2 - _size / 2;
      return Stack(
        alignment: Alignment.center,
        children: [
          if (mounted)
            Positioned(
              bottom: bottom,
              child: SleekCircularSlider(
                min: min,
                max: max,
                initialValue: value,
                onChange: onChange,
                onChangeEnd: onChangeEnd,
                appearance: CircularSliderAppearance(
                  startAngle: 180,
                  angleRange: 180,
                  size: _size,
                  animationEnabled: false,
                  customWidths: CustomSliderWidths(
                    trackWidth: 60,
                    progressBarWidth: 65,
                    handlerSize: 26,
                  ),
                  customColors: CustomSliderColors(
                    trackColor: Colors.grey.shade800,
                    progressBarColor: theme.tileColor(TileColor.blue, null),
                    dotColor: Colors.white,
                    shadowMaxOpacity: 0.0,
                  ),
                  infoProperties: InfoProperties(modifier: (_) => ''),
                ),
                // The dial's centre sits on the bottom edge of the half ring,
                // so lift the text into the ring.
                innerWidget: (_) => Transform.translate(
                  offset: const Offset(0, -45),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        valueStr,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        label,
                        style:
                            TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
