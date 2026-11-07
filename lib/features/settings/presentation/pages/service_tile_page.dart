import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

class ServiceTilePage extends StatefulWidget {
  final Map<String, String> service;

  const ServiceTilePage({
    super.key,
    required this.service,
  });

  @override
  State<ServiceTilePage> createState() => _ServiceTilePageState();
}

class _ServiceTilePageState extends State<ServiceTilePage> {
  bool _loading = false;
  bool _actionLoading = false;
  Map<String, String> _currentService = {};

  @override
  void initState() {
    super.initState();
    _currentService = Map.from(widget.service);
    _refreshServiceStatus();
  }

  Future<void> _refreshServiceStatus() async {
    setState(() => _loading = true);

    final serviceName = _currentService['unit'] ?? '';
    if (serviceName.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final result = await SudoProcess.run(
        'systemctl',
        ['show', serviceName, '--no-pager', '--property=ActiveState,SubState'],
      );

      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (var line in lines) {
          if (line.startsWith('ActiveState=')) {
            _currentService['active'] = line.split('=')[1];
          } else if (line.startsWith('SubState=')) {
            _currentService['sub'] = line.split('=')[1];
          }
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleService() async {
    final serviceName = _currentService['unit'] ?? '';
    final isRunning = _currentService['active'] == 'active' && _currentService['sub'] == 'running';
    final action = isRunning ? 'stop' : 'start';

    setState(() => _actionLoading = true);

    try {
      final result = await SudoProcess.run('systemctl', [action, serviceName]);
      if (result.exitCode == 0) {
        _showSnackBar('Service ${action}ed successfully', Colors.green);
        await _refreshServiceStatus();
      } else {
        _showSnackBar('Failed to $action service: ${result.stderr}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _restartService() async {
    final serviceName = _currentService['unit'] ?? '';

    setState(() => _actionLoading = true);

    try {
      final result = await SudoProcess.run('systemctl', ['restart', serviceName]);
      if (result.exitCode == 0) {
        _showSnackBar('Service restarted successfully', Colors.green);
        await _refreshServiceStatus();
      } else {
        _showSnackBar('Failed to restart service: ${result.stderr}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  void _viewLogs() {
    final serviceName = _currentService['unit'] ?? '';
    final displayName = _currentService['displayName'] ?? serviceName;

    context.push(AppRoutes.serviceLog, extra: {
      'serviceName': serviceName,
      'displayName': displayName,
    });
  }

  Future<void> _toggleEnabled() async {
    final serviceName = _currentService['unit'] ?? '';
    final isActive = _currentService['active'] == 'active';
    final action = isActive ? 'disable' : 'enable';

    setState(() => _actionLoading = true);

    try {
      final result = await SudoProcess.run('systemctl', [action, serviceName]);
      if (result.exitCode == 0) {
        _showSnackBar('Service ${action}d on boot', Colors.green);
        await _refreshServiceStatus();
      } else {
        _showSnackBar('Failed to $action service: ${result.stderr}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    const duration = Duration(seconds: 2);
    if (color == Colors.red) {
      AppToast.error(message, duration: duration);
    } else {
      AppToast.success(message, duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _currentService['active'] == 'active';
    final isRunning = _currentService['sub'] == 'running';
    final serviceName = _currentService['unit'] ?? '';
    final displayName = _currentService['displayName'] ?? serviceName;

    Color statusColor;
    IconData statusIcon;

    if (isActive && isRunning) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isActive && !isRunning) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(
        context,
        displayName,
        actions: [
          IconButton(
            onPressed: _loading ? null : _refreshServiceStatus,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            iconSize: 32,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left side - Status
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusIcon, size: 80, color: statusColor),
                      const SizedBox(height: 16),
                      Text(
                        serviceName,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor, width: 2),
                        ),
                        child: Text(
                          isRunning ? 'Running' : (_currentService['sub'] ?? 'Unknown'),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Right side - Controls (2x2 grid)
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Top row: Start/Stop and Restart
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: isRunning ? Icons.stop : Icons.play_arrow,
                              label: isRunning ? 'Stop' : 'Start',
                              color: isRunning ? Colors.red : Colors.green,
                              loading: _actionLoading,
                              onPressed: _toggleService,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.restart_alt,
                              label: 'Restart',
                              color: Colors.blue,
                              loading: _actionLoading,
                              onPressed: _restartService,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom row: View Logs and Enable/Disable
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.article,
                              label: 'Logs',
                              color: Colors.purple,
                              onPressed: _viewLogs,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: isActive ? Icons.toggle_on : Icons.toggle_off,
                              label: isActive ? 'Disable' : 'Enable',
                              color: isActive ? Colors.orange : Colors.teal,
                              loading: _actionLoading,
                              onPressed: _toggleEnabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: color),
              )
            else
              Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
