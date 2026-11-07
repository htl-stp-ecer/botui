import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/features/wifi/application/saved_networks_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/domain/enities/saved_network.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';

class SavedNetworkListItem extends ConsumerStatefulWidget {
  final SavedNetwork network;

  const SavedNetworkListItem({super.key, required this.network});

  @override
  ConsumerState<SavedNetworkListItem> createState() => _SavedNetworkListItemState();
}

class _SavedNetworkListItemState extends ConsumerState<SavedNetworkListItem> {
  bool _showPassword = false;
  // Fetched from the robot the first time the eye is tapped; the list itself
  // never carries passwords.
  String? _password;
  bool _loadingPassword = false;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(colorThemeProvider);
    // Left to right; the color comes from the theme by position in this row.
    final buttons = [
      if (widget.network.credentials is PersonalCredentials)
        (
          slot: TileColor.blue,
          icon: _showPassword ? Icons.visibility_off : Icons.visibility,
          onPressed: _togglePassword,
        ),
      (
        slot: TileColor.green,
        icon: Icons.wifi,
        onPressed: () {
          ref.read(wifiClientProvider.notifier).connectToNetwork(
              widget.network.ssid,
              widget.network.encryptionType,
              widget.network.credentials);
        },
      ),
      (
        slot: TileColor.red,
        icon: Icons.delete,
        onPressed: () {
          _showRemoveDialog(context, widget.network.ssid);
        },
      ),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          widget.network.ssid,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last connected: ${_formatDateTime(widget.network.lastConnected)}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (widget.network.credentials is PersonalCredentials) ...[
              const SizedBox(height: 4),
              Text(
                'Password: ${_getPasswordText()}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ] else if (widget.network.credentials is EnterpriseCredentials) ...[
              const SizedBox(height: 4),
              const Text(
                'Enterprise Network',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        leading: Icon(
          Icons.bookmark,
          color: widget.network.autoConnect ? Colors.green : Colors.grey,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, button) in buttons.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              ElevatedButton(
                onPressed: button.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.tileColor(button.slot, i),
                  foregroundColor: theme.textColor,
                  minimumSize: const Size(75, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Icon(button.icon, size: 30),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPasswordText() {
    if (!_showPassword) return '••••••••';
    if (_loadingPassword) return 'Loading...';
    final password = _password ?? '';
    return password.isEmpty ? '(not stored)' : password;
  }

  Future<void> _togglePassword() async {
    if (_showPassword) {
      setState(() => _showPassword = false);
      return;
    }
    setState(() => _showPassword = true);
    if (_password != null) return;
    setState(() => _loadingPassword = true);
    try {
      final password = await ref
          .read(manageSavedNetworksProvider)
          .getSavedPassword(widget.network.ssid);
      if (mounted) setState(() => _password = password ?? '');
    } catch (e) {
      if (mounted) {
        setState(() => _showPassword = false);
        AppToast.error('Could not read password: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingPassword = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _showRemoveDialog(BuildContext context, String ssid) async {
    final confirmed = await showRaccoonConfirmDialog(
      context,
      title: 'Remove Network',
      message: 'Remove "$ssid" from saved networks?',
      confirmLabel: 'Remove',
      icon: Icons.wifi_off,
    );
    if (confirmed && mounted) {
      ref.read(savedNetworksProvider.notifier).removeSavedNetwork(ssid);
    }
  }
}
