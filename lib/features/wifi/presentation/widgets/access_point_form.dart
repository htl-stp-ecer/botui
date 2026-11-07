import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/utils/password_generator.dart';
import 'package:stpvelox/features/wifi/application/access_point_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/access_point_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';

class AccessPointForm extends ConsumerStatefulWidget {
  final AccessPointConfig? initialConfig;
  final Function(AccessPointConfig) onStart;
  final VoidCallback onStop;
  final bool isStarted;
  final bool isLoading;

  const AccessPointForm({
    super.key,
    this.initialConfig,
    required this.onStart,
    required this.onStop,
    required this.isStarted,
    this.isLoading = false,
  });

  @override
  ConsumerState<AccessPointForm> createState() => _AccessPointFormState();
}

class _AccessPointFormState extends ConsumerState<AccessPointForm> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  WifiBand _selectedBand = WifiBand.bandAuto;
  WifiEncryptionType _encryptionType = WifiEncryptionType.wpa2Personal;
  bool _isHidden = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null) {
      final config = widget.initialConfig!;
      _ssidController.text = config.ssid;
      _passwordController.text = config.password;
      _selectedBand = config.band;
      _encryptionType = config.encryptionType;
      _isHidden = config.hidden;
    } else {
      _ssidController.text = 'RaccoonOS';
      _passwordController.text = 'raccoonos';
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apState = ref.watch(accessPointProvider);
    final apNotifier = ref.read(accessPointProvider.notifier);

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIconColor: Colors.white70,
          suffixIconColor: Colors.white70,
          border: _fieldBorder(Colors.white.withValues(alpha: 0.12)),
          enabledBorder: _fieldBorder(Colors.white.withValues(alpha: 0.12)),
          focusedBorder: _fieldBorder(_accent),
          errorBorder: _fieldBorder(Colors.redAccent),
          focusedErrorBorder: _fieldBorder(Colors.redAccent),
        ),
        canvasColor: _cardColor,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      child: _buildForm(apState, apNotifier),
    );
  }

  static const _accent = Color(0xFFBA68C8);
  static const _cardColor = Color(0xFF11161C);

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 1.5),
      );

  /// Bottom buttons take their color from the theme: [slot] at [position]
  /// (0 = first button in the row).
  ButtonStyle _buttonStyle(TileColor slot, int position) {
    final theme = ref.watch(colorThemeProvider);
    return ElevatedButton.styleFrom(
        backgroundColor: theme.tileColor(slot, position),
        foregroundColor: theme.textColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
  }

  Widget _buildForm(AccessPointState apState, AccessPointNotifier apNotifier) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _accent.withValues(alpha: 0.32), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network Configuration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                        labelText: 'Network Name (SSID)',
                        prefixIcon: Icon(Icons.wifi)),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter network name';
                      if (value.length < 3) return 'Must be at least 3 chars';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_showPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Generate Password',
                            onPressed: () {
                              _passwordController.text =
                                  PasswordGenerator.generateReadablePassword();
                            },
                          )
                        ],
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter password';
                      if (value.length < 8) return 'Must be at least 8 chars';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WifiBand>(
                    value: _selectedBand,
                    dropdownColor: const Color(0xFF1A2027),
                    decoration: const InputDecoration(
                      labelText: 'WiFi Band',
                      prefixIcon: Icon(Icons.signal_wifi_4_bar),
                    ),
                    items: WifiBand.values
                        .map((b) => DropdownMenuItem(value: b, child: Text(b.displayName)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBand = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WifiEncryptionType>(
                    value: _encryptionType,
                    dropdownColor: const Color(0xFF1A2027),
                    decoration: const InputDecoration(
                      labelText: 'Security',
                      prefixIcon: Icon(Icons.security),
                    ),
                    items: [
                      WifiEncryptionType.wpa3Personal,
                      WifiEncryptionType.wpa2Personal,
                      WifiEncryptionType.open
                    ]
                        .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e == WifiEncryptionType.wpa3Personal
                            ? 'WPA3 Personal (Recommended)'
                            : e == WifiEncryptionType.wpa2Personal
                            ? 'WPA2 Personal'
                            : 'Open')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _encryptionType = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: _accent,
                    title: const Text('Hidden Network',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text('Won\'t appear in scan results',
                        style: TextStyle(color: Colors.grey[400])),
                    value: _isHidden,
                    onChanged: (v) => setState(() => _isHidden = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (apState.isStarted) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  ref.read(colorThemeProvider).textColor),
                            ),
                          )
                        : const Icon(Icons.stop),
                    label: const Text('Stop Hotspot'),
                    style: _buttonStyle(TileColor.red, 0),
                    onPressed: widget.isLoading ? null : apNotifier.stopHotspot,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  ref.read(colorThemeProvider).textColor),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Restart'),
                    style: _buttonStyle(TileColor.blue, 1),
                    onPressed: widget.isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              final cfg = AccessPointConfig(
                                  ssid: _ssidController.text,
                                  password: _passwordController.text,
                                  band: _selectedBand,
                                  encryptionType: _encryptionType,
                                  hidden: _isHidden);
                              apNotifier.startHotspot(cfg);
                            }
                          },
                  ),
                )
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  ref.read(colorThemeProvider).textColor),
                            ),
                          )
                        : const Icon(Icons.router),
                    label: Text(widget.isLoading ? 'Starting...' : 'Start Hotspot'),
                    style: _buttonStyle(TileColor.green, 0),
                    onPressed: widget.isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              final cfg = AccessPointConfig(
                                  ssid: _ssidController.text,
                                  password: _passwordController.text,
                                  band: _selectedBand,
                                  encryptionType: _encryptionType,
                                  hidden: _isHidden);
                              apNotifier.startHotspot(cfg);
                            }
                          },
                  ),
                )
              ]
            ],
          ),
        ],
      ),
    );
  }
}
