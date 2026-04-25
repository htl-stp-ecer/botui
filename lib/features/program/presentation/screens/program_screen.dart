import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:stpvelox/features/program/domain/entities/program_session.dart';
import 'package:stpvelox/features/program/domain/services/program_lifecycle_service.dart';
import 'package:stpvelox/features/program/presentation/providers/program_providers.dart';
import 'package:stpvelox/features/program/presentation/widgets/program_sync_widgets.dart';
import 'package:stpvelox/features/sensors/domain/entities/args/arg.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:xterm/xterm.dart';

final _log = Logger('ProgramScreen');

class ProgramScreen extends HookConsumerWidget {
  final Program program;

  const ProgramScreen({super.key, required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayEntry = useState<OverlayEntry?>(null);
    final state = ref.watch(programLifecycleServiceProvider);

    // Navigate to dashboard when a running program stops.
    ref.listen<ProgramSession?>(programLifecycleServiceProvider,
        (previous, next) {
      if (previous != null && next == null) {
        _log.info('[listen] Program stopped — navigating to dashboard');
        context.go(AppRoutes.dashboard);
      }
    });

    // Watch the programs list so file-watcher updates flow in automatically.
    // Resolve the current entry by parentDir (the stable on-disk identifier)
    // and fall back to the route argument until the list has loaded.
    final listAsync = ref.watch(programSelectionProvider);
    final current = listAsync.maybeWhen(
      data: (programs) => programs.firstWhere(
        (p) => p.parentDir == program.parentDir,
        orElse: () => program,
      ),
      orElse: () => program,
    );
    final syncState = current.syncState;

    useEffect(() {
      _log.info('[useEffect] ProgramScreen mounted');
      return () {
        _log.warning(
            '[useEffect cleanup] ProgramScreen unmounting — isRunning=${state?.isRunning}');
        removeOverlay(overlayEntry);
        if (state != null && state.isRunning) {
          _log.warning(
              '[useEffect cleanup] Stopping program because screen is unmounting');
          ref.read(programLifecycleServiceProvider.notifier).stopProgram();
        }
      };
    }, []);

    return Scaffold(
      appBar: createTopBar(
        context,
        current.name,
        trailing: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ProgramVersionChip(syncState: syncState),
        ),
      ),
      body: Stack(
        children: [
          if (state != null)
            TerminalView(
              state.terminal,
              controller: state.terminalController,
              textStyle: const TerminalStyle(
                fontSize: 14,
                fontFamily: 'DejaVu Sans Mono',
              ),
            ),
          if (state == null)
            Container(
              color: Colors.black,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: ResponsiveGridTile(
                              label: 'Start',
                              icon: Icons.play_arrow,
                              color: Colors.green,
                              onPressed: () {
                                createArgOverlay(
                                    context,
                                    overlayEntry,
                                    {},
                                    current,
                                    0,
                                    current.args.firstOrNull,
                                    ref,
                                    const []);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: ResponsiveGridTile(
                              label: 'Advanced',
                              icon: Icons.tune,
                              color: Colors.blueGrey,
                              onPressed: () {
                                createAdvancedOverlay(
                                    context, overlayEntry, current, ref);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ProgramSyncDetailsCard(syncState: syncState),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void createArgOverlay(
    BuildContext context,
    ValueNotifier<OverlayEntry?> overlayEntry,
    Map<String, String> args,
    Program program,
    int idx,
    Arg? arg,
    WidgetRef ref,
    List<String> extraFlags) {
  removeOverlay(overlayEntry);
  assert(overlayEntry.value == null);

  if (arg == null) {
    ref
        .read(programLifecycleServiceProvider.notifier)
        .startProgram(program, args, extraFlags: extraFlags);
    return;
  }

  overlayEntry.value = OverlayEntry(
    builder: (BuildContext context) {
      return GestureDetector(
        child: Material(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        arg.name,
                        style: const TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      arg.build(context, (value) {
                        args[arg.name] = value;
                      }),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: ResponsiveGridTile(
                    label: 'Submit',
                    icon: Icons.hide_image_rounded,
                    color: Colors.blue,
                    onPressed: () {
                      if (idx + 1 >= program.args.length) {
                        createArgOverlay(context, overlayEntry, args, program,
                            idx + 1, null, ref, extraFlags);
                        return;
                      }

                      createArgOverlay(context, overlayEntry, args, program,
                          idx + 1, program.args[idx + 1], ref, extraFlags);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Overlay.of(context).insert(overlayEntry.value!);
}

void createAdvancedOverlay(
    BuildContext context,
    ValueNotifier<OverlayEntry?> overlayEntry,
    Program program,
    WidgetRef ref) {
  removeOverlay(overlayEntry);
  assert(overlayEntry.value == null);

  var devEnabled = false;
  var noCalibrateEnabled = false;

  overlayEntry.value = OverlayEntry(
    builder: (BuildContext context) {
      return Material(
        color: Colors.black87,
        child: StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Advanced options',
                      style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AdvancedFlagRow(
                      label: '--dev',
                      value: devEnabled,
                      onChanged: (v) => setState(() => devEnabled = v),
                    ),
                    const SizedBox(height: 8),
                    _AdvancedFlagRow(
                      label: '--no-calibrate',
                      value: noCalibrateEnabled,
                      onChanged: (v) => setState(() => noCalibrateEnabled = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: ResponsiveGridTile(
                            label: 'Cancel',
                            icon: Icons.close,
                            color: Colors.redAccent,
                            onPressed: () => removeOverlay(overlayEntry),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: ResponsiveGridTile(
                            label: 'Start',
                            icon: Icons.play_arrow,
                            color: Colors.green,
                            onPressed: () {
                              final flags = <String>[
                                if (devEnabled) '--dev',
                                if (noCalibrateEnabled) '--no-calibrate',
                              ];
                              createArgOverlay(
                                  context,
                                  overlayEntry,
                                  {},
                                  program,
                                  0,
                                  program.args.firstOrNull,
                                  ref,
                                  flags);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Overlay.of(context).insert(overlayEntry.value!);
}

void removeOverlay(ValueNotifier<OverlayEntry?> overlayEntry) {
  overlayEntry.value?.remove();
  overlayEntry.value?.dispose();
  overlayEntry.value = null;
}

class _AdvancedFlagRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AdvancedFlagRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 360,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'DejaVu Sans Mono',
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
