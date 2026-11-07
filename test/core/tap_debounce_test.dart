import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/input/tap_debounce.dart';

ui.PointerData _event(ui.PointerChange change, int ms, double x, double y,
        {int device = 1}) =>
    ui.PointerData(
      timeStamp: Duration(milliseconds: ms),
      change: change,
      kind: ui.PointerDeviceKind.touch,
      device: device,
      physicalX: x,
      physicalY: y,
    );

List<ui.PointerChange> _changes(List<ui.PointerData> data) =>
    data.map((d) => d.change).toList();

void main() {
  test('a press at the same spot right after another is dropped completely', () {
    final filter = TapDebounceFilter();
    final first = filter.filter([
      _event(ui.PointerChange.down, 0, 100, 100),
      _event(ui.PointerChange.up, 30, 100, 100),
    ], 1);
    expect(_changes(first), [ui.PointerChange.down, ui.PointerChange.up]);

    final bounce = filter.filter([
      _event(ui.PointerChange.down, 80, 104, 98),
      _event(ui.PointerChange.move, 90, 104, 98),
      _event(ui.PointerChange.up, 110, 104, 98),
    ], 1);
    expect(bounce, isEmpty);
  });

  test('after the window the same spot is a new press', () {
    final filter = TapDebounceFilter();
    filter.filter([_event(ui.PointerChange.down, 0, 100, 100)], 1);
    filter.filter([_event(ui.PointerChange.up, 20, 100, 100)], 1);

    final second = filter.filter([_event(ui.PointerChange.down, 350, 100, 100)], 1);
    expect(_changes(second), [ui.PointerChange.down]);
  });

  test('a press elsewhere is not a bounce, even right away', () {
    final filter = TapDebounceFilter();
    filter.filter([_event(ui.PointerChange.down, 0, 100, 100)], 1);
    filter.filter([_event(ui.PointerChange.up, 20, 100, 100)], 1);

    final other = filter.filter([_event(ui.PointerChange.down, 100, 300, 100)], 1);
    expect(_changes(other), [ui.PointerChange.down]);
  });

  test('the radius scales with the pixel ratio', () {
    final filter = TapDebounceFilter(radius: 30);
    filter.filter([_event(ui.PointerChange.down, 0, 100, 100)], 2);
    filter.filter([_event(ui.PointerChange.up, 20, 100, 100)], 2);

    // 50 physical px away: inside 30 logical (60 physical) at ratio 2.
    final near = filter.filter([_event(ui.PointerChange.down, 100, 150, 100)], 2);
    expect(near, isEmpty);
  });

  test('mouse events are never filtered', () {
    final filter = TapDebounceFilter();
    ui.PointerData mouse(ui.PointerChange c, int ms) => ui.PointerData(
          timeStamp: Duration(milliseconds: ms),
          change: c,
          kind: ui.PointerDeviceKind.mouse,
          physicalX: 10,
          physicalY: 10,
        );
    final out = filter.filter([
      mouse(ui.PointerChange.down, 0),
      mouse(ui.PointerChange.up, 10),
      mouse(ui.PointerChange.down, 20),
    ], 1);
    expect(out, hasLength(3));
  });

  test('a swallowed press does not hide the next real one', () {
    final filter = TapDebounceFilter();
    filter.filter([_event(ui.PointerChange.down, 0, 100, 100)], 1);
    filter.filter([_event(ui.PointerChange.up, 20, 100, 100)], 1);
    filter.filter([
      _event(ui.PointerChange.down, 60, 100, 100),
      _event(ui.PointerChange.up, 80, 100, 100),
    ], 1); // swallowed

    final later = filter.filter([_event(ui.PointerChange.down, 500, 100, 100)], 1);
    expect(_changes(later), [ui.PointerChange.down]);
  });
}
