import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/core/contract/contract_check.dart';

/// Shows the result of the transport contract check on top of the UI:
/// a blocking popup when this UI does not match the installed system, and a
/// small "DEV TRANSPORT" badge while the bundle is in dev mode (mismatches are
/// then not enforced anywhere). Nothing is shown when everything matches or the
/// UI does not run on a Raccoon device.
class ContractOverlay extends ConsumerWidget {
  const ContractOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(contractCheckResultProvider);
    if (result == null) return const SizedBox.shrink();

    if (result.refuse) {
      final dismissed = ref.watch(contractPopupDismissedProvider);
      if (dismissed) return const SizedBox.shrink();
      return _MismatchPopup(
        message: contractPopupMessage(result),
        onAcknowledge: () => ref.read(contractPopupDismissedProvider.notifier).dismiss(),
      );
    }
    if (result.result == contractDevWarning) return const _DevBadge();
    return const SizedBox.shrink();
  }
}

class _DevBadge extends StatelessWidget {
  const _DevBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4,
      right: 4,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber[800],
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'DEV TRANSPORT',
            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _MismatchPopup extends StatelessWidget {
  const _MismatchPopup({required this.message, required this.onAcknowledge});

  final String message;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Transport mismatch',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[300], fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onAcknowledge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Acknowledge', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
