import 'dart:ui' as ui;

/// A press that begins within this time of the last accepted press ...
const Duration kTapDebounceWindow = Duration(milliseconds: 300);

/// ... and within this distance of it (logical pixels) is dropped.
const double kTapDebounceRadius = 30;

/// Swallows the contact bounce of the resistive touchscreen.
///
/// One finger press often arrives as several quick presses at the same spot.
/// This filter sits in front of the whole app (see [installTapDebounce]) and
/// drops every press that starts within [window] and [radius] of the last
/// accepted one, together with its moves and release. Time plus position,
/// not time alone: typing on the on-screen keyboard or tapping two different
/// buttons quickly still works, and a bounce that lands on a new screen after
/// a menu change (a different element at the same spot) is still caught.
class TapDebounceFilter {
  TapDebounceFilter({
    this.window = kTapDebounceWindow,
    this.radius = kTapDebounceRadius,
  });

  final Duration window;
  final double radius;

  Duration? _lastTime;
  ui.Offset? _lastPosition;

  /// Devices whose current press is being swallowed until it is released.
  final Set<int> _swallowing = {};

  /// [pixelRatio] converts [radius] (logical) to the physical pixels the
  /// pointer data is in.
  List<ui.PointerData> filter(List<ui.PointerData> input, double pixelRatio) {
    final output = <ui.PointerData>[];
    for (final data in input) {
      if (data.kind != ui.PointerDeviceKind.touch) {
        output.add(data); // mouse and the like are not bouncy
        continue;
      }
      final device = data.device;
      switch (data.change) {
        case ui.PointerChange.down:
          final position = ui.Offset(data.physicalX, data.physicalY);
          final last = _lastTime;
          final lastPosition = _lastPosition;
          final bounce = last != null &&
              lastPosition != null &&
              data.timeStamp - last < window &&
              (position - lastPosition).distance < radius * pixelRatio;
          if (bounce) {
            _swallowing.add(device);
          } else {
            _lastTime = data.timeStamp;
            _lastPosition = position;
            output.add(data);
          }
        case ui.PointerChange.up:
        case ui.PointerChange.cancel:
          // The end of a swallowed press goes with its start.
          if (!_swallowing.remove(device)) output.add(data);
        default:
          if (!_swallowing.contains(device)) output.add(data);
      }
    }
    return output;
  }
}

/// Puts a [TapDebounceFilter] in front of the framework's pointer handling.
/// Call once in `main`, after the binding is initialized.
void installTapDebounce() {
  final dispatcher = ui.PlatformDispatcher.instance;
  final original = dispatcher.onPointerDataPacket;
  if (original == null) return;
  final filter = TapDebounceFilter();
  dispatcher.onPointerDataPacket = (ui.PointerDataPacket packet) {
    final pixelRatio = dispatcher.implicitView?.devicePixelRatio ?? 1.0;
    final data = filter.filter(packet.data, pixelRatio);
    if (data.isEmpty) return;
    original(data.length == packet.data.length
        ? packet
        : ui.PointerDataPacket(data: data));
  };
}
