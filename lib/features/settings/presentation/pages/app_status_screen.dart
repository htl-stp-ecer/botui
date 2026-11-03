import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stpvelox/core/contract/bundle_file.dart';
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
  // The bundle file is local, so it is read right away and shown without waiting.
  BundleFile _bundle = BundleFile.read();
  bool _loading = true;

  /// (server key, bundle key, label, icon). Both sections use this order.
  static const _componentOrder = [
    ('ui', 'botui', 'botui', Icons.phone_android),
    ('raccoon-cli', 'raccoon-cli', 'raccoon-cli', Icons.terminal),
    ('raccoon-lib', 'raccoon-lib', 'raccoon-lib', Icons.library_books),
    ('raccoon-transport', 'raccoon-transport', 'raccoon-transport', Icons.swap_horiz),
    ('stm32-data-reader', 'stm32-data-reader', 'stm32-data-reader', Icons.memory),
    ('raccoon-cam', 'raccoon-cam', 'raccoon-cam', Icons.camera_alt),
  ];

  @override
  void initState() {
    super.initState();
    _fetchVersions();
  }

  Future<void> _fetchVersions() async {
    setState(() => _loading = true);
    String? error;
    _bundle = BundleFile.read();

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

  Widget _divider({double gap = 0}) => Column(
        children: [
          SizedBox(height: gap),
          Divider(color: Colors.grey[800], height: 1),
          SizedBox(height: gap),
        ],
      );

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          text,
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
      );

  /// Section 1: what the bundle file says. Section 2: what is installed, same order.
  List<Widget> _rows() {
    final bundle = _bundle;
    final bundleError = bundle.error == null ? null : 'bundle file ${bundle.error}';
    final components = bundle.json?['components'];
    final bundleVersions = components is Map<String, dynamic> ? components : const <String, dynamic>{};

    final rows = <Widget>[
      _sectionHeader('Bundle metadata'),
      _VersionRow(
        icon: Icons.inventory_2,
        label: 'Bundle Version',
        version: bundle.name,
        missingText: bundleError ?? 'not set',
      ),
      _divider(gap: 8),
    ];
    for (var i = 0; i < _componentOrder.length; i++) {
      final (_, bundleKey, label, icon) = _componentOrder[i];
      if (i > 0) rows.add(_divider());
      final value = bundleVersions[bundleKey];
      rows.add(_VersionRow(
        icon: icon,
        label: label,
        version: value == null ? null : '$value',
        missingText: bundleError ?? 'not in bundle',
      ));
    }
    rows.add(_divider());
    final hash = bundle.json?['contract_hash'];
    rows.add(_VersionRow(
      icon: Icons.fingerprint,
      label: 'contract_hash',
      version: hash == null ? null : '$hash',
      missingText: bundleError ?? 'not in bundle',
    ));

    rows.add(_divider(gap: 8));
    rows.add(_sectionHeader('Installed'));
    for (var i = 0; i < _componentOrder.length; i++) {
      final (key, _, label, icon) = _componentOrder[i];
      if (i > 0) rows.add(_divider());
      rows.add(_VersionRow(
        icon: icon,
        label: label,
        version: _versions?[key],
        // The botui version is compiled in; only the server-reported ones load.
        loading: _loading && key != 'ui',
      ));
    }
    return rows;
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: _rows(),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? version;

  /// Text when [version] is null.
  final String missingText;

  /// Show a spinner instead of the value while it is being fetched.
  final bool loading;

  const _VersionRow({
    required this.icon,
    required this.label,
    required this.version,
    this.missingText = 'not installed',
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final installed = version != null && version!.isNotEmpty;
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
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else if (installed)
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
              missingText,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
        ],
      ),
    );
  }
}
