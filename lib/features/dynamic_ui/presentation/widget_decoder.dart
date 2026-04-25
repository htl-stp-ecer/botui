import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/widgets/large_checkbox.dart';
import 'package:stpvelox/core/widgets/large_dropdown.dart';

import 'widgets/index.dart';

final _log = Logger('WidgetDecoder');

/// Callback when a value changes in an input widget
typedef OnValueChanged = void Function(String widgetId, dynamic value);

/// Callback when a button is clicked
typedef OnButtonClicked = void Function(String buttonId);

/// Callback for keypad input
typedef OnKeypadInput = void Function(String key);

/// Decodes JSON widget definitions into Flutter widgets
class WidgetDecoder {
  final OnValueChanged onValueChanged;
  final OnButtonClicked onButtonClicked;
  final OnKeypadInput onKeypadInput;
  final WidgetRef ref;

  int _decodeCounter = 0;

  WidgetDecoder({
    required this.onValueChanged,
    required this.onButtonClicked,
    required this.onKeypadInput,
    required this.ref,
  }) {
    _log.fine('[WidgetDecoder] Instance created');
  }

  /// Decode a JSON widget/layout definition into a Flutter widget
  Widget decode(Map<String, dynamic> json) {
    _decodeCounter++;
    final decodeId = _decodeCounter;

    // Check if it's a layout (has children) or a widget
    final widgetType = json['widget'] as String?;

    if (widgetType != null) {
      _log.fine('[DECODE #$decodeId] Decoding widget type="$widgetType"');
      try {
        final result = _decodeWidget(json, widgetType.toLowerCase());
        _log.fine('[DECODE #$decodeId] Successfully decoded widget type="$widgetType"');
        return result;
      } catch (e, stackTrace) {
        _log.severe('[DECODE #$decodeId] Error decoding widget type="$widgetType": $e');
        _log.severe('[DECODE #$decodeId] Stack trace: $stackTrace');
        _log.severe('[DECODE #$decodeId] JSON was: $json');
        return Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12));
      }
    }

    // Might be a layout without explicit widget type
    if (json.containsKey('children')) {
      _log.fine('[DECODE #$decodeId] Decoding implicit layout with ${(json['children'] as List?)?.length ?? 0} children');
      return _decodeLayout(json);
    }

    _log.warning('[DECODE #$decodeId] Unknown JSON structure, returning SizedBox.shrink. Keys: ${json.keys.toList()}');
    return const SizedBox.shrink();
  }

  Widget _decodeWidget(Map<String, dynamic> json, String type) {
    switch (type) {
      // Display widgets
      case 'text':
        return _buildText(json);
      case 'icon':
        return _buildIcon(json);
      case 'spacer':
        return SizedBox(height: (json['height'] as int? ?? 16).toDouble());
      case 'divider':
        return Divider(
          thickness: (json['thickness'] as int? ?? 1).toDouble(),
          color: json['color'] != null ? _parseColor(json['color']) : null,
        );
      case 'statusbadge':
        return StatusBadgeWidget(
          text: json['text'] as String? ?? '',
          color: json['color'] as String? ?? 'grey',
          glow: json['glow'] as bool? ?? false,
        );
      case 'statusicon':
        return StatusIconWidget(
          icon: json['icon'] as String? ?? 'check',
          color: json['color'] as String? ?? 'green',
          animated: json['animated'] as bool? ?? true,
        );
      case 'hintbox':
        return HintBoxWidget(
          text: json['text'] as String? ?? '',
          icon: json['icon'] as String? ?? 'touch_app',
          prominent: (json['style'] as String?) == 'prominent',
        );
      case 'distancebadge':
        return DistanceBadgeWidget(
          value: (json['value'] as num?)?.toDouble() ?? 0,
          unit: json['unit'] as String? ?? 'cm',
          color: json['color'] as String? ?? 'blue',
        );
      case 'resultstable':
        return ResultsTableWidget(
          rows: (json['rows'] as List?)?.cast<List>() ?? [],
        );

      // Input widgets
      case 'button':
        return _buildButton(json);
      case 'slider':
        return _buildSlider(json);
      case 'checkbox':
        return _buildCheckbox(json);
      case 'dropdown':
        return _buildDropdown(json);
      case 'numerickeypad':
        return NumericKeypadWidget(onKeyPress: onKeypadInput);
      case 'numericinput':
        return _buildNumericInput(json);
      case 'textinput':
        return _buildTextInput(json);

      // Visualization widgets
      case 'sensorvalue':
        return SensorValueWidget(
          port: json['port'] as int? ?? 0,
          sensorType: json['sensor_type'] as String? ?? 'analog',
          ref: ref,
        );
      case 'sensorgraph':
        return SensorGraphWidget(
          port: json['port'] as int? ?? 0,
          sensorType: json['sensor_type'] as String? ?? 'analog',
          maxPoints: json['max_points'] as int? ?? 50,
          ref: ref,
        );
      case 'lightbulb':
        return LightBulbWidget(isOn: json['is_on'] as bool? ?? false);
      case 'animatedrobot':
        return AnimatedRobotWidget(
          moving: json['moving'] as bool? ?? false,
          size: (json['size'] as int? ?? 120).toDouble(),
        );
      case 'circularslider':
        return _buildCircularSlider(json);
      case 'progressspinner':
        return SizedBox(
          width: (json['size'] as int? ?? 24).toDouble(),
          height: (json['size'] as int? ?? 24).toDouble(),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: json['color'] != null ? _parseColor(json['color']) : Colors.orange,
          ),
        );
      case 'pulsingarrow':
        return const PulsingArrowWidget();
      case 'robotdrivinganimation':
        return RobotDrivingAnimationWidget(
          targetDistance: (json['target_distance'] as num?)?.toDouble() ?? 30.0,
        );
      case 'measuringtape':
        return MeasuringTapeWidget(
          distance: (json['distance'] as num?)?.toDouble() ?? 30.0,
        );
      case 'calibrationchart':
        return CalibrationChartWidget(
          rawSamples: json['samples'] as List? ?? [],
          rawThresholds: json['thresholds'] as List? ?? [],
          height: (json['height'] as int? ?? 200).toDouble(),
        );
      case 'camfeed':
        final camId = json['id'] as String? ?? 'cam_feed';
        return CamFeedWidget(
          id: camId,
          showFps: json['show_fps'] as bool? ?? false,
          showDetections: json['show_detections'] as bool? ?? true,
          onTap: json['tappable'] as bool? ?? false
              ? (x, y) => onValueChanged(camId, {'x': x, 'y': y})
              : null,
        );

      // Layout widgets
      case 'row':
        return _buildRow(json);
      case 'column':
        return _buildColumn(json);
      case 'center':
        return _buildCenter(json);
      case 'container':
        return _buildContainer(json);
      case 'card':
        return _buildCard(json);
      case 'split':
        return _buildSplit(json);
      case 'expanded':
        return _buildExpanded(json);

      default:
        return Text('Unknown widget: $type', style: const TextStyle(color: Colors.red));
    }
  }

  Widget _decodeLayout(Map<String, dynamic> json) {
    // Default to column layout
    return _buildColumn(json);
  }

  // --- Display Widgets ---

  Widget _buildText(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    final size = json['size'] as String? ?? 'medium';
    final bold = json['bold'] as bool? ?? false;
    final muted = json['muted'] as bool? ?? false;
    final align = json['align'] as String? ?? 'left';

    final fontSize = switch (size) {
      'small' => 14.0,
      'medium' => 18.0,
      'large' => 24.0,
      'title' => 48.0,
      'xlarge' => 72.0,
      'xxlarge' => 96.0,
      _ => 18.0,
    };

    Color? textColor;
    if (json['color'] != null) {
      textColor = _parseColor(json['color']);
    } else if (muted) {
      textColor = Colors.white.withOpacity(0.6);
    }

    return Text(
      text,
      textAlign: _parseTextAlign(align),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: textColor,
      ),
    );
  }

  Widget _buildIcon(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'help';
    final size = (json['size'] as int? ?? 24).toDouble();
    final color = json['color'] != null ? _parseColor(json['color']) : null;

    return Icon(_parseIcon(name), size: size, color: color);
  }

  // --- Input Widgets ---

  Widget _buildButton(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final label = json['label'] as String? ?? '';
    final style = json['style'] as String? ?? 'primary';
    final iconName = json['icon'] as String?;
    final disabled = json['disabled'] as bool? ?? false;

    final color = switch (style) {
      'primary' => Colors.blue,
      'secondary' => Colors.grey.shade700,
      'success' => Colors.green,
      'danger' => Colors.red,
      'warning' => Colors.orange,
      _ => Colors.blue,
    };

    final button = ElevatedButton.icon(
      onPressed: disabled ? null : () => onButtonClicked(id),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: iconName != null ? Icon(_parseIcon(iconName), size: 20) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );

    return button;
  }

  Widget _buildSlider(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final min = (json['min'] as num?)?.toDouble() ?? 0;
    final max = (json['max'] as num?)?.toDouble() ?? 100;
    final value = (json['value'] as num?)?.toDouble() ?? min;
    final label = json['label'] as String?;
    final showValue = json['show_value'] as bool? ?? true;

    return SliderInputWidget(
      id: id,
      min: min,
      max: max,
      value: value,
      label: label,
      showValue: showValue,
      onChanged: (v) => onValueChanged(id, v),
    );
  }

  Widget _buildCheckbox(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final label = json['label'] as String? ?? '';
    final value = json['value'] as bool? ?? false;

    return LargeCheckbox(
      label: label,
      initialValue: value,
      onChanged: (v) => onValueChanged(id, v),
    );
  }

  Widget _buildDropdown(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final options = (json['options'] as List?)?.cast<String>() ?? [];
    final value = json['value'] as String?;
    final label = json['label'] as String?;

    return LargeDropdown(
      options: options,
      initialSelected: value,
      label: label,
      onChanged: (v) => onValueChanged(id, v),
    );
  }

  Widget _buildNumericInput(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final value = (json['value'] as num?)?.toDouble() ?? 0;
    final unit = json['unit'] as String? ?? '';
    final showAdjust = json['show_adjust_buttons'] as bool? ?? true;

    return NumericInputWidget(
      id: id,
      value: value,
      unit: unit,
      showAdjustButtons: showAdjust,
      onChanged: (v) => onValueChanged(id, v),
    );
  }

  Widget _buildTextInput(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final value = json['value'] as String? ?? '';
    final label = json['label'] as String?;
    final placeholder = json['placeholder'] as String? ?? '';

    return TextInputWidget(
      id: id,
      value: value,
      label: label,
      placeholder: placeholder,
      onChanged: (v) => onValueChanged(id, v),
    );
  }

  Widget _buildCircularSlider(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final min = (json['min'] as num?)?.toDouble() ?? 0;
    final max = (json['max'] as num?)?.toDouble() ?? 100;
    final value = (json['value'] as num?)?.toDouble() ?? 0;
    final label = json['label'] as String?;

    return CircularSliderWidget(
      id: id,
      min: min,
      max: max,
      value: value,
      label: label,
      onChanged: (v) => onValueChanged(id, v),
    );
  }

  // --- Layout Widgets ---

  Widget _buildRow(Map<String, dynamic> json) {
    final children = (json['children'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final align = json['align'] as String? ?? 'center';
    final spacing = (json['spacing'] as int? ?? 8).toDouble();

    return Row(
      mainAxisAlignment: _parseMainAxisAlignment(align),
      mainAxisSize: MainAxisSize.min,
      children: _addSpacing(children, spacing, Axis.horizontal),
    );
  }

  Widget _buildColumn(Map<String, dynamic> json) {
    final children = (json['children'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final align = json['align'] as String? ?? 'stretch';
    final spacing = (json['spacing'] as int? ?? 12).toDouble();

    // If any child is Expanded, the Column must fill available space
    final hasExpanded = children.any((c) => c is Expanded);

    return Column(
      crossAxisAlignment: _parseCrossAxisAlignment(align),
      mainAxisSize: hasExpanded ? MainAxisSize.max : MainAxisSize.min,
      children: _addSpacing(children, spacing, Axis.vertical),
    );
  }

  Widget _buildCenter(Map<String, dynamic> json) {
    final children = (json['children'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final spacing = (json['spacing'] as int? ?? 12).toDouble();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _addSpacing(children, spacing, Axis.vertical),
      ),
    );
  }

  Widget _buildContainer(Map<String, dynamic> json) {
    final children = (json['children'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final bgColor = json['bg_color'] != null ? _parseColor(json['bg_color']) : null;
    final padding = (json['padding'] as int? ?? 0).toDouble();

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(padding),
      color: bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> json) {
    final children = (json['children'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final title = json['title'] as String?;
    final padding = (json['padding'] as int? ?? 16).toDouble();

    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade700),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSplit(Map<String, dynamic> json) {
    final leftChildren = (json['left'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final rightChildren = (json['right'] as List?)
        ?.map((c) => decode(c as Map<String, dynamic>))
        .toList() ?? [];
    final ratio = json['ratio'] as List?;
    final leftFlex = (ratio?[0] as int?) ?? 1;
    final rightFlex = (ratio?[1] as int?) ?? 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: leftFlex,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: leftChildren,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: rightFlex,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rightChildren,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(Map<String, dynamic> json) {
    final child = json['child'] as Map<String, dynamic>?;
    final flex = json['flex'] as int? ?? 1;

    if (child == null) return const SizedBox.shrink();

    return Expanded(
      flex: flex,
      child: decode(child),
    );
  }

  // --- Helper Methods ---

  List<Widget> _addSpacing(List<Widget> children, double spacing, Axis axis) {
    if (children.isEmpty) return children;

    final spacer = axis == Axis.horizontal
        ? SizedBox(width: spacing)
        : SizedBox(height: spacing);

    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(spacer);
      }
    }
    return result;
  }

  MainAxisAlignment _parseMainAxisAlignment(String align) => switch (align) {
    'start' => MainAxisAlignment.start,
    'center' => MainAxisAlignment.center,
    'end' => MainAxisAlignment.end,
    'space_between' => MainAxisAlignment.spaceBetween,
    'space_around' => MainAxisAlignment.spaceAround,
    _ => MainAxisAlignment.center,
  };

  CrossAxisAlignment _parseCrossAxisAlignment(String align) => switch (align) {
    'start' => CrossAxisAlignment.start,
    'center' => CrossAxisAlignment.center,
    'end' => CrossAxisAlignment.end,
    'stretch' => CrossAxisAlignment.stretch,
    _ => CrossAxisAlignment.stretch,
  };

  TextAlign _parseTextAlign(String align) => switch (align) {
    'left' => TextAlign.left,
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };

  Color _parseColor(dynamic colorValue) {
    if (colorValue is String) {
      // Named colors
      return switch (colorValue.toLowerCase()) {
        'grey' || 'gray' => Colors.grey,
        'green' => Colors.green,
        'amber' => Colors.amber,
        'orange' => Colors.orange,
        'red' => Colors.red,
        'blue' => Colors.blue,
        'white' => Colors.white,
        'black' => Colors.black,
        _ => _parseHexColor(colorValue),
      };
    }
    return Colors.white;
  }

  Color _parseHexColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  IconData _parseIcon(String name) => switch (name.toLowerCase()) {
    'check' => Icons.check,
    'close' => Icons.close,
    'warning' => Icons.warning,
    'error' => Icons.error,
    'info' => Icons.info,
    'help' || 'help_outline' => Icons.help_outline,
    'touch_app' => Icons.touch_app,
    'lightbulb' => Icons.lightbulb,
    'lightbulb_outline' => Icons.lightbulb_outline,
    'play' || 'play_arrow' => Icons.play_arrow,
    'stop' => Icons.stop,
    'refresh' => Icons.refresh,
    'settings' => Icons.settings,
    'arrow_forward' => Icons.arrow_forward,
    'arrow_back' => Icons.arrow_back,
    'arrow_upward' => Icons.arrow_upward,
    'arrow_downward' => Icons.arrow_downward,
    'add' => Icons.add,
    'remove' => Icons.remove,
    'edit' => Icons.edit,
    'delete' => Icons.delete,
    'save' => Icons.save,
    'cancel' => Icons.cancel,
    'done' => Icons.done,
    'sensor' || 'sensors' => Icons.sensors,
    'speed' => Icons.speed,
    'timer' => Icons.timer,
    'tune' => Icons.tune,
    'dashboard' => Icons.dashboard,
    'check_circle' => Icons.check_circle,
    'camera' || 'camera_alt' => Icons.camera_alt,
    'visibility_off' => Icons.visibility_off,
    _ => Icons.help_outline,
  };
}
