import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';

/// Lets the user change the device hostname and its mDNS (`.local`) name in a
/// single action.
class HostnameScreen extends ConsumerStatefulWidget {
  const HostnameScreen({super.key, this.service = const SystemConfigService()});

  final SystemConfigService service;

  @override
  ConsumerState<HostnameScreen> createState() => _HostnameScreenState();
}

class _HostnameScreenState extends ConsumerState<HostnameScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await widget.service.getHostname();
    if (!mounted) return;
    setState(() {
      _controller.text = current;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (!SystemConfigService.isValidHostname(name)) {
      _showSnack(
        'Invalid hostname — use letters, digits and hyphens only.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    final outcome = await widget.service.setHostnameAndMdns(name);
    if (outcome.ok) await _restartHotspotIfOn();
    if (!mounted) return;
    setState(() => _saving = false);
    _showSnack(outcome.message, isError: !outcome.ok);
  }

  /// The hotspot's DNS answers with the robot's name, so it has to be started
  /// again to pick up the new one.
  Future<void> _restartHotspotIfOn() async {
    try {
      final ap = ref.read(manageAccessPointProvider);
      if (!await ap.isAccessPointActive()) return;
      final config = await ap.getAccessPointConfig();
      if (config != null) await ap.startAccessPoint(config);
    } catch (_) {
      // The name is already changed; a failed hotspot restart is not fatal.
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (isError) {
      AppToast.error(message);
    } else {
      AppToast.success(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(colorThemeProvider);
    // One palette for the screen: the name field is position 0 (blue slot),
    // Apply is position 1 (green slot). Same scheme as the keyboard screen.
    final fieldColor = theme.tileColor(TileColor.blue, 0);
    final applyColor = theme.tileColor(TileColor.green, 1);
    final fg = theme.textColor;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Hostname'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Device name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sets the system hostname and the mDNS name at once. '
                      'Other devices reach it as "<name>.local".',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9-]')),
                        LengthLimitingTextInputFormatter(63),
                      ],
                      style: const TextStyle(fontSize: 22, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. cubebot',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.travel_explore, color: fieldColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _controller.text.trim().isEmpty
                              ? 'mDNS: —'
                              : 'mDNS: ${_controller.text.trim()}.local',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: applyColor,
                          disabledBackgroundColor:
                              theme.tileColor(TileColor.grey, null),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _saving
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: fg),
                              )
                            : Icon(Icons.save, color: fg),
                        label: Text(
                          _saving ? 'Applying…' : 'Apply',
                          style: TextStyle(fontSize: 20, color: fg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
