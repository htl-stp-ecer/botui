import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

const _serverUrl = 'http://localhost:8421';

// Injected at build time via --dart-define=APP_VERSION=x.y.z, falls back to pubspec value.
const _uiVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

class AppStatusScreen extends StatefulWidget {
  const AppStatusScreen({super.key});

  @override
  State<AppStatusScreen> createState() => _AppStatusScreenState();
}

class _AppStatusScreenState extends State<AppStatusScreen> {
  Map<String, String?>? _versions;
  String? _error;
  bool _loading = true;

  static const _componentOrder = [
    ('ui', 'ui', Icons.phone_android),
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
    setState(() {
      _loading = true;
      _error = null;
    });

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
        setState(() {
          _versions = versions;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Server returned ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      // Server unreachable — still show ui version locally
      setState(() {
        _versions = {'ui': _uiVersion};
        _error = 'raccoon-server not reachable';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'App Status', actions: [
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _componentOrder.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Colors.grey[800], height: 1),
                      itemBuilder: (context, i) {
                        final (key, label, icon) = _componentOrder[i];
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
