import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';

/// A color range entry for HSV-based blob detection calibration.
class _ColorRange {
  String name;
  double hMin;
  double hMax;
  double sMin;
  double sMax;
  double vMin;
  double vMax;

  _ColorRange({
    required this.name,
    this.hMin = 0,
    this.hMax = 179,
    this.sMin = 50,
    this.sMax = 255,
    this.vMin = 50,
    this.vMax = 255,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'h_min': hMin.round(),
        'h_max': hMax.round(),
        's_min': sMin.round(),
        's_max': sMax.round(),
        'v_min': vMin.round(),
        'v_max': vMax.round(),
      };
}

class CamCalibrationPanel extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const CamCalibrationPanel({super.key, required this.scrollController});

  @override
  ConsumerState<CamCalibrationPanel> createState() =>
      _CamCalibrationPanelState();
}

class _CamCalibrationPanelState extends ConsumerState<CamCalibrationPanel> {
  final List<_ColorRange> _colors = [
    _ColorRange(name: 'orange', hMin: 5, hMax: 25, sMin: 100, sMax: 255, vMin: 100, vMax: 255),
  ];
  int _selectedIndex = 0;
  double _minArea = 100;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Text(
          'Camera Calibration',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Color selector chips
        _buildColorSelector(),
        const SizedBox(height: 16),

        // HSV sliders for selected color
        if (_colors.isNotEmpty) ...[
          _buildRangeSlider(
            'Hue',
            _colors[_selectedIndex].hMin,
            _colors[_selectedIndex].hMax,
            0,
            179,
            (min, max) => setState(() {
              _colors[_selectedIndex].hMin = min;
              _colors[_selectedIndex].hMax = max;
            }),
          ),
          _buildRangeSlider(
            'Saturation',
            _colors[_selectedIndex].sMin,
            _colors[_selectedIndex].sMax,
            0,
            255,
            (min, max) => setState(() {
              _colors[_selectedIndex].sMin = min;
              _colors[_selectedIndex].sMax = max;
            }),
          ),
          _buildRangeSlider(
            'Value',
            _colors[_selectedIndex].vMin,
            _colors[_selectedIndex].vMax,
            0,
            255,
            (min, max) => setState(() {
              _colors[_selectedIndex].vMin = min;
              _colors[_selectedIndex].vMax = max;
            }),
          ),
        ],

        const SizedBox(height: 16),

        // Min area slider
        _buildSlider(
          'Min Area',
          _minArea,
          0,
          5000,
          (value) => setState(() => _minArea = value),
        ),

        const SizedBox(height: 24),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
            label: const Text('Save Config', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Colors',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _addColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_colors.length, (index) {
            final color = _colors[index];
            final isSelected = index == _selectedIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              onLongPress: () => _removeColor(index),
              child: Chip(
                label: Text(
                  color.name,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                backgroundColor: isSelected ? Colors.amber : Colors.grey[700],
                deleteIcon: isSelected
                    ? const Icon(Icons.close, size: 18, color: Colors.black54)
                    : null,
                onDeleted: isSelected ? () => _removeColor(index) : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRangeSlider(
    String label,
    double min,
    double max,
    double sliderMin,
    double sliderMax,
    void Function(double min, double max) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text('${min.round()} - ${max.round()}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        RangeSlider(
          values: RangeValues(min, max),
          min: sliderMin,
          max: sliderMax,
          divisions: (sliderMax - sliderMin).round(),
          activeColor: Colors.amber,
          inactiveColor: Colors.grey[700],
          onChanged: (values) => onChanged(values.start, values.end),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text('${value.round()}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: Colors.amber,
          inactiveColor: Colors.grey[700],
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _addColor() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Add Color',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Color name (e.g. green)',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.amber),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _colors.add(_ColorRange(name: name));
                  _selectedIndex = _colors.length - 1;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _removeColor(int index) {
    if (_colors.length <= 1) return;
    setState(() {
      _colors.removeAt(index);
      if (_selectedIndex >= _colors.length) {
        _selectedIndex = _colors.length - 1;
      }
    });
  }

  void _saveConfig() {
    final config = {
      'colors': _colors.map((c) => c.toJson()).toList(),
      'min_area': _minArea.round(),
    };
    final configJson = jsonEncode(config);
    final transport = ref.read(transportServiceProvider);
    publishCamConfig(transport, configJson);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Config saved'),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
