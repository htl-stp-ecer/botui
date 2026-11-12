import 'package:stpvelox/features/program/domain/entities/sync_state.dart';
import 'package:stpvelox/features/sensors/domain/entities/args/arg.dart';

class Program {
  final String name;
  final String parentDir;
  final List<Arg> args;

  /// Last recorded sync metadata (version, fingerprint, timestamp, pusher).
  /// Null when the project has never been synced from a dev machine.
  final SyncState? syncState;

  Program({
    required this.name,
    required this.parentDir,
    required this.args,
    this.syncState,
  });
}
