import 'package:logging/logging.dart';

const _reset = '\x1B[0m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _green = '\x1B[32m';
const _blue = '\x1B[34m';
const _cyan = '\x1B[36m';
const _gray = '\x1B[90m';

String _color(Level level) {
  if (level >= Level.SEVERE) return _red;
  if (level >= Level.WARNING) return _yellow;
  if (level >= Level.INFO) return _green;
  if (level >= Level.CONFIG) return _blue;
  if (level >= Level.FINE) return _cyan;
  return _gray;
}

Logger getLogger(String name) {
  return Logger(name);
}

void setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    final time = rec.time.toIso8601String().substring(11, 19);
    final color = _color(rec.level);
    final msg = rec.message;
    final err = rec.error != null ? ' | error=${rec.error}' : '';
    final stack = rec.stackTrace != null ? '\n${rec.stackTrace}' : '';

    print('$color[$time] [${rec.level.name}] [${rec.loggerName}]$_reset – $msg$err$stack');
  });
}
