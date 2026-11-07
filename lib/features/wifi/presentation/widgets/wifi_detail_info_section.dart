import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/themed_field.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';

/// The body of the per-network screen: a card with the network's details
/// (SSID, encryption, status) and, for a new network that needs one, the
/// password field. Styled like the manual connect screen; the icon of the
/// n-th row and the password field take the n-th color of the theme.
class WifiDetailInfoSection extends ConsumerStatefulWidget {
  final WifiNetwork network;
  final TextEditingController passwordController;

  const WifiDetailInfoSection({
    super.key,
    required this.network,
    required this.passwordController,
  });

  @override
  ConsumerState<WifiDetailInfoSection> createState() =>
      _WifiDetailInfoSectionState();
}

class _WifiDetailInfoSectionState extends ConsumerState<WifiDetailInfoSection> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final network = widget.network;
    final enc = network.encryptionType;
    final theme = ref.watch(colorThemeProvider);
    final needsPwd =
        _needsPassword(enc) && !network.isKnown && !network.isConnected;

    final (statusIcon, statusText, statusColor) = network.isConnected
        ? (Icons.check_circle_outline_rounded, 'Connected', Colors.greenAccent)
        : network.isKnown
            ? (Icons.bookmark_border_rounded, 'Saved, not connected',
                Colors.orangeAccent)
            : (Icons.help_outline_rounded, 'Not connected',
                Colors.orangeAccent);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kFormCardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailRow(
              color: _slot(theme, 0),
              icon: Icons.wifi,
              label: 'Network name (SSID)',
              value: network.ssid,
            ),
            _DetailRow(
              color: _slot(theme, 1),
              icon: enc == WifiEncryptionType.open
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              label: 'Security',
              value: enc.formatted,
            ),
            _DetailRow(
              color: _slot(theme, 2),
              icon: statusIcon,
              label: 'Status',
              value: statusText,
              valueColor: statusColor,
              last: !needsPwd,
            ),
            if (needsPwd)
              TextField(
                controller: widget.passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: themedFieldDecoration(
                  theme,
                  3,
                  label: 'Password',
                  icon: Icons.lock,
                  hint: 'Enter password',
                  suffix: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _slot(AppTheme theme, int index) =>
      theme.tileColor(TileColor.byIndex(index), index);

  bool _needsPassword(WifiEncryptionType enc) =>
      enc != WifiEncryptionType.open &&
      enc != WifiEncryptionType.wpa2Enterprise &&
      enc != WifiEncryptionType.wpa3Enterprise;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    this.last = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
