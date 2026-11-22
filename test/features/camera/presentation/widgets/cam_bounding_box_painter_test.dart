import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_frame_view.dart';

/// A detection of raccoon-cam: the centre and the size as fractions of the frame.
CamBlobT blob(double x, double y, double w, double h) => CamBlobT(
      timestamp: 0,
      label: 'x',
      x: x,
      y: y,
      width: w,
      height: h,
      area: 0,
      confidence: 1,
    );

void main() {
  const frame = Size(320, 240); // 4:3

  group('pictureRect', () {
    test('a picture of the shape of the box fills it', () {
      final rect = CamBoundingBoxPainter.pictureRect(
          frame, const Size(640, 480), BoxFit.contain, Alignment.center);
      expect(rect, const Rect.fromLTWH(0, 0, 640, 480));
    });

    test('contain leaves bars where the shapes differ', () {
      // A wide box: the picture is as high as the box and centred.
      final rect = CamBoundingBoxPainter.pictureRect(
          frame, const Size(800, 240), BoxFit.contain, Alignment.center);
      expect(rect, const Rect.fromLTWH(240, 0, 320, 240));
    });

    test('cover fills the box and the picture sticks out', () {
      final rect = CamBoundingBoxPainter.pictureRect(
          frame, const Size(320, 120), BoxFit.cover, Alignment.center);
      expect(rect, const Rect.fromLTWH(0, -60, 320, 240));
    });
  });

  group('boxRect', () {
    test('x and y are the centre, width and height the size, all as fractions', () {
      const picture = Rect.fromLTWH(0, 0, 320, 240);
      final rect =
          CamBoundingBoxPainter.boxRect(blob(0.5, 0.5, 0.25, 0.5), picture);
      expect(rect, const Rect.fromLTWH(120, 60, 80, 120));
    });

    test('the box follows the picture, not the box it is shown in', () {
      // Contain in a wide box: the picture starts at x = 240.
      const picture = Rect.fromLTWH(240, 0, 320, 240);
      final rect =
          CamBoundingBoxPainter.boxRect(blob(0.5, 0.5, 0.5, 0.5), picture);
      expect(rect, const Rect.fromLTWH(320, 60, 160, 120));
    });
  });

  test('the colour of a detection is the one the processor set, or none', () {
    expect(CamBoundingBoxPainter.detectionColor(0), isNull);
    expect(CamBoundingBoxPainter.detectionColor(0xFFFF3B30 - (1 << 32)),
        const Color(0xFFFF3B30)); // the wire carries ARGB as a signed 32-bit integer
    expect(CamBoundingBoxPainter.detectionColor(0xFF00FF00 - (1 << 32)),
        const Color(0xFF00FF00));
  });
}
