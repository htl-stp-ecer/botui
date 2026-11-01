import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:stpvelox/features/program/presentation/providers/program_providers.dart';
import 'package:stpvelox/features/program/presentation/widgets/program_sync_widgets.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

class ProgramActionScreen extends HookConsumerWidget {
  final Program program;

  const ProgramActionScreen({super.key, required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(programSelectionProvider);
    final current = listAsync.maybeWhen(
      data: (programs) => programs.firstWhere(
        (p) => p.parentDir == program.parentDir,
        orElse: () => program,
      ),
      orElse: () => program,
    );
    final syncState = current.syncState;

    return Scaffold(
      appBar: createTopBar(
        context,
        current.name,
        trailing: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ProgramVersionChip(syncState: syncState),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveGrid(
              children: [
                ResponsiveGridTile(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  color: TileColor.green,
                  onPressed: () =>
                      context.push(AppRoutes.programRun, extra: current),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ProgramSyncDetailsCard(syncState: syncState),
            ),
          ],
        ),
      ),
    );
  }
}
