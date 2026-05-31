import 'dart:typed_data';
import 'package:raccoon_transport/raccoon_transport.dart';

typedef TransportDecoder<T> = T Function(LcmBuffer buffer);

class TransportDecoded<T> {
  final String topic;
  final int utime;
  final Uint8List raw;
  final T value;

  const TransportDecoded({
    required this.topic,
    required this.utime,
    required this.raw,
    required this.value,
  });

  @override
  String toString() =>
      'TransportDecoded<$T>(topic: $topic, utime: $utime, value: $value)';
}
