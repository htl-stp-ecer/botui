import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/sensors/presentation/services/sensor_data_processor.dart';

void main() {
  group('SensorDataProcessor.appendToRawData', () {
    final p = const SensorDataProcessor(maxPoints: 4, movingAvgWindow: 3);

    test('appends without exceeding maxPoints', () {
      var data = <double>[];
      for (final v in [1.0, 2.0, 3.0, 4.0]) {
        data = p.appendToRawData(data, v);
      }
      expect(data, [1.0, 2.0, 3.0, 4.0]);
    });

    test('drops oldest sample when maxPoints exceeded (FIFO window)', () {
      var data = <double>[];
      for (final v in [1.0, 2.0, 3.0, 4.0, 5.0]) {
        data = p.appendToRawData(data, v);
      }
      expect(data, [2.0, 3.0, 4.0, 5.0]);
    });

    test('does not mutate the input list', () {
      final original = <double>[1.0, 2.0];
      final result = p.appendToRawData(original, 3.0);
      expect(original, [1.0, 2.0]);
      expect(result, [1.0, 2.0, 3.0]);
    });
  });

  group('SensorDataProcessor.appendToMovingAverage', () {
    final p = const SensorDataProcessor(maxPoints: 10, movingAvgWindow: 3);

    test('returns empty when rawData is empty', () {
      expect(p.appendToMovingAverage([1.0, 2.0], []), isEmpty);
    });

    test('appends mean of last movingAvgWindow samples', () {
      // raw = [1,2,3,4,5], window=3 → last 3 = [3,4,5] mean=4
      final ma = p.appendToMovingAverage([], [1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(ma, [4.0]);
    });

    test('uses entire raw window when shorter than movingAvgWindow', () {
      final ma = p.appendToMovingAverage([], [2.0, 4.0]);
      expect(ma, [3.0]);
    });
  });

  group('SensorDataProcessor.calculateStatistics', () {
    final p = const SensorDataProcessor(maxPoints: 100, movingAvgWindow: 5);

    test('returns zeroed statistics for empty input', () {
      final s = p.calculateStatistics(const []);
      expect(s.average, 0);
      expect(s.minimum, 0);
      expect(s.maximum, 0);
      expect(s.median, 0);
      expect(s.standardDeviation, 0);
    });

    test('computes mean / min / max / median / stddev for odd-length data',
        () {
      final s = p.calculateStatistics(const [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]);
      // wikipedia stddev textbook example: mean 5, popStdDev 2
      expect(s.average, closeTo(5.0, 1e-9));
      expect(s.minimum, 2.0);
      expect(s.maximum, 9.0);
      expect(s.standardDeviation, closeTo(2.0, 1e-9));
    });

    test('median for even-length data averages the two middle values', () {
      final s = p.calculateStatistics(const [1.0, 2.0, 3.0, 4.0]);
      expect(s.median, closeTo(2.5, 1e-9));
    });

    test('stddev of constant series is zero', () {
      final s = p.calculateStatistics(const [7.0, 7.0, 7.0, 7.0]);
      expect(s.standardDeviation, closeTo(0, 1e-12));
      expect(s.average, 7.0);
    });

    test('does not mutate the input list when sorting for median', () {
      final input = <double>[3.0, 1.0, 2.0];
      p.calculateStatistics(input);
      expect(input, [3.0, 1.0, 2.0]);
    });

    test('stddev matches a hand-computed value via sqrt(variance)', () {
      const data = [1.0, 2.0, 3.0];
      final s = p.calculateStatistics(data);
      // variance = mean of squared diffs from mean(2): (1+0+1)/3 = 2/3
      expect(s.standardDeviation, closeTo(sqrt(2 / 3), 1e-12));
    });
  });
}
