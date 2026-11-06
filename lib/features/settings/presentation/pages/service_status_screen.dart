import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});

  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  Map<String, Map<String, String>> _services = {};
  bool _loading = true;

  // Services we want to manage
  static const _targetServices = [
    ('ssh.service', 'SSH', Icons.terminal),
    ('raccoon.service', 'Raccoon', Icons.pets),
    ('flutter-ui.service', 'Bot UI', Icons.phone_android),
    ('stm32_data_reader.service', 'STM32 Reader', Icons.memory),
    ('raccoon-cam.service', 'Camera', Icons.camera_alt),
  ];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  static const _fetchTimeout = Duration(seconds: 10);

  /// [showSudoPopup] is false for the silent refetch after returning from a
  /// service's control page; the cards still show `error` in that case.
  Future<void> _fetchServices({bool showSudoPopup = true}) async {
    setState(() => _loading = true);

    if (!await SudoProcess.isPasswordless('systemctl')) {
      if (!mounted) return;
      setState(() {
        _services = {
          for (final (unit, name, icon) in _targetServices)
            unit: {
              'unit': unit,
              'displayName': name,
              'icon': icon.codePoint.toString(),
              'active': 'error',
              'sub': 'error',
              'load': 'error',
            },
        };
        _loading = false;
      });
      if (showSudoPopup) {
        await showRaccoonErrorDialog(
            context, "Missing passwordless sudo, can't fetch services");
      }
      return;
    }

    // All services are queried in parallel, each capped at [_fetchTimeout],
    // so the screen can never load for longer than that.
    final entries = await Future.wait(
      _targetServices.map((s) => _fetchService(s.$1, s.$2, s.$3)),
    );

    if (mounted) {
      setState(() {
        _services = {for (final e in entries) e['unit']!: e};
        _loading = false;
      });
    }
  }

  Future<Map<String, String>> _fetchService(
      String serviceName, String displayName, IconData icon) async {
    Map<String, String> entry(String active, String sub, String load) => {
          'unit': serviceName,
          'displayName': displayName,
          'icon': icon.codePoint.toString(),
          'active': active,
          'sub': sub,
          'load': load,
        };

    try {
      final result = await SudoProcess.run(
        'systemctl',
        ['show', serviceName, '--no-pager', '--property=ActiveState,SubState,LoadState'],
      ).timeout(_fetchTimeout);

      if (result.exitCode != 0) {
        return entry('not-found', 'not-found', 'not-found');
      }

      String active = 'unknown';
      String sub = 'unknown';
      String load = 'unknown';
      for (final line in (result.stdout as String).split('\n')) {
        if (line.startsWith('ActiveState=')) {
          active = line.split('=')[1];
        } else if (line.startsWith('SubState=')) {
          sub = line.split('=')[1];
        } else if (line.startsWith('LoadState=')) {
          load = line.split('=')[1];
        }
      }
      return entry(active, sub, load);
    } catch (e) {
      // Includes TimeoutException.
      return entry('error', 'error', 'error');
    }
  }

  void _navigateToServiceControl(Map<String, String> service) {
    context
        .push(AppRoutes.serviceTile, extra: service)
        .then((_) => _fetchServices(showSudoPopup: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Services', actions: [
        IconButton(
          onPressed: _loading ? null : _fetchServices,
          icon: _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, color: Colors.white),
          iconSize: 32,
        ),
      ]),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: _targetServices.map((s) {
                    final service = _services[s.$1];
                    if (service == null) return const SizedBox.shrink();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _ServiceCard(
                          service: service,
                          icon: s.$3,
                          onTap: () => _navigateToServiceControl(service),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }
}

/// Cards whose name is shown on several lines (the name elsewhere stays on
/// one line).
const _cardLabels = {
  'stm32_data_reader.service': 'STM32\nReader',
};

class _ServiceCard extends StatelessWidget {
  final Map<String, String> service;
  final IconData icon;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = service['active'] == 'active';
    final isRunning = service['sub'] == 'running';
    final notFound = service['load'] == 'not-found';
    final displayName = service['displayName'] ?? service['unit'] ?? '';

    Color statusColor;
    IconData statusIcon;

    if (notFound) {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
    } else if (isActive && isRunning) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isActive && !isRunning) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Icon(icon, size: 48, color: Colors.grey[400]),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, size: 20, color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Room for two lines on every card, so the status badges line up.
            SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  _cardLabels[service['unit']] ?? displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor, width: 1),
              ),
              child: Text(
                notFound ? 'Not Found' : (isRunning ? 'Running' : service['sub'] ?? 'Unknown'),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
