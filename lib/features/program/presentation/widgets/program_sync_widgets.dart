import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/features/program/domain/entities/sync_state.dart';

/// Compact version chip. ``v42`` in the theme's green when the project has
/// been verified-synced at least once, ``NOT SYNCED`` in the theme's red
/// otherwise (both slots follow the active color theme). Used in top bars and as an
/// overlay badge on program list tiles so devs can see at a glance which
/// programs on the Pi are up-to-date.
class ProgramVersionChip extends ConsumerWidget {
  final SyncState? syncState;

  /// Smaller variant is used as a tile corner badge, larger variant in top bars.
  final bool compact;

  const ProgramVersionChip({
    super.key,
    required this.syncState,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final synced = syncState?.hasBeenSynced ?? false;
    final label = synced ? 'v${syncState!.version}' : 'NOT SYNCED';
    final theme = ref.watch(colorThemeProvider);
    final background = synced
        ? theme.tileColor(TileColor.green, 0)
        : theme.tileColor(TileColor.red, 1);

    final double fontSize = compact ? 13 : 18;
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Verbose sync-state card showing version, last update time, who pushed,
/// and the full fingerprint. Rendered under the Start button on the program
/// run screen so devs can verify "am I running the latest?" before tapping.
///
/// When the project has never been synced this collapses into a warning box
/// instead, because a never-synced project is the exact state you want devs
/// to notice before they hit Start.
class ProgramSyncDetailsCard extends StatelessWidget {
  final SyncState? syncState;

  const ProgramSyncDetailsCard({super.key, required this.syncState});

  @override
  Widget build(BuildContext context) {
    final state = syncState;
    if (state == null || !state.hasBeenSynced) {
      return Card(
        color: Colors.red.shade900.withValues(alpha: 0.4),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'This program has never been pushed from a dev machine. '
                  'The files on the Pi may be stale or edited by hand.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done,
                    color: Colors.greenAccent, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Version ${state.version}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.schedule,
              label: 'Last update',
              value: formatSyncTimestamp(state.syncedAt),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Updated by',
              value: state.syncedBy ?? '—',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.fingerprint,
              label: 'Fingerprint',
              value: state.fingerprint ?? '—',
              monospace: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Format an ISO timestamp as ``"3 min ago  ·  2026-04-10 14:03"``.
/// Public so other widgets (tile subtitles, compact info rows) can reuse it.
String formatSyncTimestamp(DateTime? ts) {
  if (ts == null) return '—';
  final local = ts.toLocal();
  final now = DateTime.now();
  final delta = now.difference(local);
  final absolute = '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';

  String relative;
  if (delta.inSeconds < 60) {
    relative = 'just now';
  } else if (delta.inMinutes < 60) {
    relative = '${delta.inMinutes} min ago';
  } else if (delta.inHours < 24) {
    relative = '${delta.inHours} h ago';
  } else if (delta.inDays < 30) {
    relative = '${delta.inDays} d ago';
  } else {
    relative = '';
  }

  return relative.isEmpty ? absolute : '$relative  ·  $absolute';
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: monospace ? 'monospace' : null,
              letterSpacing: monospace ? 0.5 : null,
            ),
          ),
        ),
      ],
    );
  }
}
