import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/core/contract/contract_check.dart';

/// Shows a blocking popup when this UI does not match the installed system
/// (transport contract check). Nothing is shown when everything matches, in dev
/// mode, or when the UI does not run on a Raccoon device; the bundle's values
/// (including `dev`) are on the Versions page.
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
    return const SizedBox.shrink();
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
                  'System mismatch',
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
