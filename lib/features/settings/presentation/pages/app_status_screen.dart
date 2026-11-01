import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stpvelox/core/widgets/error_popup.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

const _serverUrl = 'http://localhost:8421';

// Injected at build time via --dart-define=APP_VERSION=<build number> (see build.sh).
const _uiVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

class AppStatusScreen extends StatefulWidget {
  const AppStatusScreen({super.key});

  @override
  State<AppStatusScreen> createState() => _AppStatusScreenState();
}

class _AppStatusScreenState extends State<AppStatusScreen> {
  Map<String, String?>? _versions;
  bool _loading = true;

  static const _componentOrder = [
    ('ui', 'botui', Icons.phone_android),
    ('raccoon-cli', 'raccoon-cli', Icons.terminal),
    ('raccoon-lib', 'raccoon-lib', Icons.library_books),
    ('raccoon-transport', 'raccoon-transport', Icons.swap_horiz),
    ('stm32-data-reader', 'stm32-data-reader', Icons.memory),
    ('raccoon-cam', 'raccoon-cam', Icons.camera_alt),
  ];

  @override
  void initState() {
    super.initState();
    _fetchVersions();
  }

  Future<void> _fetchVersions() async {
    setState(() => _loading = true);
    String? error;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('$_serverUrl/version'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final data = json.decode(body) as Map<String, dynamic>;
        final versions = <String, String?>{
          for (final e in data.entries) e.key: e.value as String?,
        };
        // ui version is known locally — override what the server reports
        versions['ui'] = _uiVersion;
        _versions = versions;
      } else {
        error = 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      // Server unreachable — still show ui version locally
      _versions = {'ui': _uiVersion};
      error = 'raccoon-server not reachable';
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) await showErrorPopup(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Versions', actions: [
        IconButton(
          onPressed: _loading ? null : _fetchVersions,
          icon: _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, color: Colors.white),
          iconSize: 32,
        ),
      ]),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      // Row 0 is the bundle version, followed by the components.
                      itemCount: _componentOrder.length + 1,
                      separatorBuilder: (_, i) => i == 0
                          // Extra gap between the bundle row and the components.
                          ? Column(
                              children: [
                                const SizedBox(height: 8),
                                Divider(color: Colors.grey[800], height: 1),
                                const SizedBox(height: 8),
                              ],
                            )
                          : Divider(color: Colors.grey[800], height: 1),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          // TODO: replace with the real bundle version.
                          return const _VersionRow(
                            icon: Icons.inventory_2,
                            label: 'Bundle Version',
                            version: 'TODO',
                          );
                        }
                        final (key, label, icon) = _componentOrder[i - 1];
                        final version = _versions?[key];
                        return _VersionRow(
                          icon: icon,
                          label: label,
                          version: version,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? version;

  const _VersionRow({
    required this.icon,
    required this.label,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final installed = version != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          if (installed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Text(
                version!,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              'not installed',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
        ],
      ),
    );
  }
}
