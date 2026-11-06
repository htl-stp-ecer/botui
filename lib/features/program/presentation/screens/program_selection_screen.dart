import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:stpvelox/features/program/presentation/providers/program_providers.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

class ProgramSelectionScreen extends HookConsumerWidget {
  const ProgramSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(programSelectionProvider);

    useEffect(() {
      Future.microtask(() {
        ref.read(programSelectionProvider.notifier).loadPrograms();
      });
      return null;
    }, []);

    return Scaffold(
        appBar: createTopBar(context, 'Program Selection'),
        body: state.when(
          data: (programs) {
            if (programs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No programs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      // scale > 1 shows the image slightly smaller.
                      child: Image.asset("assets/racoon.png", scale: 1.15),
                    ),
                  ],
                ),
              );
            }
            return ResponsiveGrid(
              children: [
                for (var i = 0; i < programs.length; i++)
                  _buildProgramTile(context, ref, i, programs[i]),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              e.toString(),
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ));
  }

  Widget _buildProgramTile(
      BuildContext context, WidgetRef ref, int index, Program program) {
    final synced = program.syncState?.hasBeenSynced ?? false;
    final versionLabel =
        synced ? 'v${program.syncState!.version}' : 'NOT SYNCED';

    final theme = ref.watch(colorThemeProvider);
    final tileColor = theme.tileColor(TileColor.byIndex(index), index);
    final fg = theme.textColor;

    return GestureDetector(
      onTap: () => context.pushOnce(AppRoutes.programRun, extra: program),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, color: fg, size: 88),
            const SizedBox(height: 8),
            Text(
              program.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              versionLabel,
              style: TextStyle(
                color: synced ? fg : Colors.red.shade100,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}