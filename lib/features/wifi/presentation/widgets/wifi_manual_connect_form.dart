import 'package:flutter/material.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/themed_field.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';

class WifiManualConnectForm extends ConsumerStatefulWidget {
  const WifiManualConnectForm({super.key});

  @override
  ConsumerState<WifiManualConnectForm> createState() =>
      _WifiManualConnectFormState();
}

class _WifiManualConnectFormState extends ConsumerState<WifiManualConnectForm> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _caCertController = TextEditingController();
  WifiEncryptionType _encryptionType = WifiEncryptionType.wpa2Personal;
  bool _obscurePassword = true;

  Widget _passwordField(AppTheme theme, int index, String label) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: themedFieldDecoration(
        theme,
        index,
        label: label,
        icon: Icons.lock,
        hint: 'Enter password',
        suffix: IconButton(
          icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(wifiClientProvider).isLoading;
    final theme = ref.watch(colorThemeProvider);

    final personal = _encryptionType == WifiEncryptionType.wpa2Personal ||
        _encryptionType == WifiEncryptionType.wpa3Personal;
    final enterprise = _encryptionType == WifiEncryptionType.wpa2Enterprise ||
        _encryptionType == WifiEncryptionType.wpa3Enterprise;

    // Fields in order; each takes the next color of the theme's pattern, and
    // the button the one after the last field.
    var position = 0;
    final fields = <Widget>[
      TextField(
        controller: _ssidController,
        style: const TextStyle(color: Colors.white),
        decoration: themedFieldDecoration(theme, position++,
            label: 'Network Name (SSID)', icon: Icons.wifi, hint: 'Enter SSID'),
      ),
      DropdownButtonFormField<WifiEncryptionType>(
        value: _encryptionType,
        dropdownColor: kFormMenuColor,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: themedFieldDecoration(theme, position++,
            label: 'Encryption Type', icon: Icons.security),
        onChanged: (val) {
          if (val != null) setState(() => _encryptionType = val);
        },
        items: const [
          DropdownMenuItem(
              value: WifiEncryptionType.open, child: Text('Open (No Password)')),
          DropdownMenuItem(
              value: WifiEncryptionType.wpa2Personal,
              child: Text('WPA2 Personal')),
          DropdownMenuItem(
              value: WifiEncryptionType.wpa3Personal,
              child: Text('WPA3 Personal')),
          DropdownMenuItem(
              value: WifiEncryptionType.wpa2Enterprise,
              child: Text('WPA2 Enterprise (EAP)')),
          DropdownMenuItem(
              value: WifiEncryptionType.wpa3Enterprise,
              child: Text('WPA3 Enterprise (EAP)')),
        ],
      ),
      if (personal) _passwordField(theme, position++, 'Password'),
      if (enterprise) ...[
        TextField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white),
          decoration: themedFieldDecoration(theme, position++,
              label: 'EAP Username', icon: Icons.person, hint: 'Enter username'),
        ),
        _passwordField(theme, position++, 'EAP Password'),
        TextField(
          controller: _caCertController,
          style: const TextStyle(color: Colors.white),
          decoration: themedFieldDecoration(theme, position++,
              label: 'CA Certificate (optional)',
              icon: Icons.description,
              hint: '/path/to/ca.cert'),
        ),
      ],
    ];
    final buttonColor = theme.tileColor(TileColor.green, position);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    fields[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        // Fixed at the bottom of the screen, outside the scrolling form.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _connect(context),
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: theme.textColor),
                      )
                    : const Icon(Icons.wifi),
                label: Text(isLoading ? 'Connecting...' : 'Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: theme.textColor,
                  disabledBackgroundColor: buttonColor.withValues(alpha: 0.6),
                  disabledForegroundColor:
                      theme.textColor.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _connect(BuildContext context) {
    final ssid = _ssidController.text.trim();
    if (ssid.isEmpty) {
      _showErrorSnackbar(context, 'SSID cannot be empty');
      return;
    }

    WifiCredentials creds;
    switch (_encryptionType) {
      case WifiEncryptionType.open:
        creds = PersonalCredentials('');
        break;
      case WifiEncryptionType.wpa2Personal:
      case WifiEncryptionType.wpa3Personal:
        final password = _passwordController.text.trim();
        if (password.isEmpty) {
          _showErrorSnackbar(context, 'Password cannot be empty');
          return;
        }
        creds = PersonalCredentials(password);
        break;
      case WifiEncryptionType.wpa2Enterprise:
      case WifiEncryptionType.wpa3Enterprise:
        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();
        if (username.isEmpty || password.isEmpty) {
          _showErrorSnackbar(context, 'Username and password cannot be empty');
          return;
        }
        creds = EnterpriseCredentials(
          username: username,
          password: password,
          caCertificatePath: _caCertController.text.trim().isEmpty
              ? null
              : _caCertController.text.trim(),
        );
        break;
    }

    ref.read(wifiClientProvider.notifier).connectToNetwork(
          ssid,
          _encryptionType,
          creds,
        );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    AppToast.error(message);
  }
}
