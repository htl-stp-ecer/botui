import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/utils/password_generator.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                        labelText: 'Network Name (SSID)',
                        border: OutlineInputBorder(),
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
                      border: const OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'WiFi Band',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Security',
                      border: OutlineInputBorder(),
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
                    title: const Text('Hidden Network'),
                    subtitle: const Text('Won\'t appear in scan results'),
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.stop),
                    label: const Text('Stop Hotspot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: widget.isLoading ? null : apNotifier.stopHotspot,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: widget.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Restart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.router),
                    label: Text(widget.isLoading ? 'Starting...' : 'Start Hotspot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
