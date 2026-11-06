import 'package:flutter/material.dart';

// Every popup in the app is one of these. There are two kinds, plus one for
// the rare dialog that closes itself:
//
//  * one button  -> [showRaccoonMessageDialog] / [showRaccoonErrorDialog]
//  * two buttons -> [showRaccoonConfirmDialog]  (returns true on confirm)
//  * no button   -> [showRaccoonDialog] with a [RaccoonDialog] that has no
//                   actions (e.g. the low battery warning, closed from code)
//
// All of them are drawn by [RaccoonDialog], so the look (dark card, big icon,
// large rounded buttons) is defined in exactly one place.

const Color _confirmRed = Color(0xFFD32F2F); // red 700

/// A button of a [RaccoonDialog].
class RaccoonDialogAction {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const RaccoonDialogAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });
}

/// The dialog itself: icon, title, message and up to two buttons (one button
/// fills the width, two share it).
class RaccoonDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<RaccoonDialogAction> actions;

  const RaccoonDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    this.actions = const [],
  }) : assert(actions.length <= 2, 'A dialog has at most two buttons.');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: _DialogButton(action: actions[i])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows [builder]'s dialog with the app's backdrop. With [dismissible] false
/// the dialog can only be closed by its buttons or from code (not by tapping
/// outside or the back gesture).
Future<T?> showRaccoonDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black87,
    builder: (ctx) =>
        dismissible ? builder(ctx) : PopScope(canPop: false, child: builder(ctx)),
  );
}

/// Two-button question. Returns true when confirmed, false on cancel.
///
/// [onConfirm] runs before the dialog closes when the user confirms (e.g. to
/// apply a setting), so the caller can just act on the returned true.
Future<bool> showRaccoonConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.warning_amber_rounded,
  Color iconColor = Colors.orange,
  Color confirmColor = _confirmRed,
  String cancelLabel = 'Cancel',
  Future<void> Function()? onConfirm,
}) async {
  final result = await showRaccoonDialog<bool>(
    context,
    builder: (ctx) => RaccoonDialog(
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      actions: [
        RaccoonDialogAction(
          label: cancelLabel,
          color: Colors.grey[700]!,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        RaccoonDialogAction(
          label: confirmLabel,
          color: confirmColor,
          onPressed: () async {
            await onConfirm?.call();
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          },
        ),
      ],
    ),
  );
  return result == true;
}

/// One-button message (information, notice, ...).
Future<void> showRaccoonMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'OK',
  IconData icon = Icons.info_outline,
  Color iconColor = Colors.lightBlueAccent,
  Color buttonColor = _confirmRed,
  bool dismissible = true,
}) {
  return showRaccoonDialog<void>(
    context,
    dismissible: dismissible,
    builder: (ctx) => RaccoonDialog(
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      actions: [
        RaccoonDialogAction(
          label: buttonLabel,
          color: buttonColor,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// One-button error popup that has to be acknowledged.
Future<void> showRaccoonErrorDialog(BuildContext context, String message) {
  return showRaccoonMessageDialog(
    context,
    title: 'Error',
    message: message,
    buttonLabel: 'Acknowledge',
    icon: Icons.error_outline,
    iconColor: Colors.redAccent,
    dismissible: false,
  );
}

class _DialogButton extends StatelessWidget {
  final RaccoonDialogAction action;

  const _DialogButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: action.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: action.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          action.label,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}
