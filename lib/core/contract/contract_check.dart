import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

/// Where the Bot UI package records its own version (also read by raccoon-server).
const _versionFile = '/home/pi/stp-velox/version';

/// Runs the transport contract check once at startup (semantics:
/// `contract/CHECK_SPEC.md` in raccoon-transport) and records the result in
/// `/run/raccoon/botui.json` for the Pi server. A broken check must never keep
/// the UI from starting, so any failure here yields `null` (no popup, no badge).
ContractCheckResult? runContractCheck() {
  try {
    var version = 'unknown';
    try {
      final text = File(_versionFile).readAsStringSync().trim();
      if (text.isNotEmpty) version = text;
    } on FileSystemException {
      // Not installed from the package (dev machine): the check is skipped there anyway.
    }
    return startupCheck('botui', version, persistent: true);
  } catch (_) {
    return null;
  }
}

/// The startup check result; overridden with the real result in `main()`.
final contractCheckResultProvider = Provider<ContractCheckResult?>((ref) => null);

/// True once the user acknowledged the mismatch popup.
final contractPopupDismissedProvider =
    NotifierProvider<ContractPopupDismissed, bool>(ContractPopupDismissed.new);

class ContractPopupDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// The text of the popup for a refused check.
String contractPopupMessage(ContractCheckResult result) {
  const advice = 'Please flash the latest Raccoon image.';
  if (result.result == contractMismatch) {
    return "This UI was built for a different transport than the installed system "
        "(UI: ${result.ownHash}, transport ${result.ownTransportVersion}; "
        "system expects ${result.expectedHash}, transport ${result.expectedTransportVersion ?? 'unknown'}). "
        "$advice";
  }
  // Version mismatch or a broken bundle file: the check's own message says what is wrong.
  return '${result.message}. $advice';
}
