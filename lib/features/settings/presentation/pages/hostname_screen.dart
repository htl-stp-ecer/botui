import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';

/// Lets the user change the device hostname and its mDNS (`.local`) name in a
/// single action.
class HostnameScreen extends StatefulWidget {
  const HostnameScreen({super.key, this.service = const SystemConfigService()});

  final SystemConfigService service;

  @override
  State<HostnameScreen> createState() => _HostnameScreenState();
}

class _HostnameScreenState extends State<HostnameScreen> {
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
    if (!mounted) return;
    setState(() => _saving = false);
    _showSnack(outcome.message, isError: !outcome.ok);
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Hostname & mDNS'),
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
                          borderSide: BorderSide(color: Colors.grey.shade600),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade600),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.travel_explore,
                            color: Colors.grey[500], size: 20),
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
                          backgroundColor: Colors.blue[700],
                          disabledBackgroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _saving ? 'Applying…' : 'Apply',
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
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
