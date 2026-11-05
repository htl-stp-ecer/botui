import 'dart:io';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

class ToggleServiceButton extends StatefulWidget {
  final String serviceName;
  final bool isServiceRunning;
  final VoidCallback onServiceChanged;

  const ToggleServiceButton({
    super.key,
    required this.serviceName,
    required this.isServiceRunning,
    required this.onServiceChanged,
  });

  @override
  State<ToggleServiceButton> createState() => _ToggleServiceButtonState();
}

class _ToggleServiceButtonState extends State<ToggleServiceButton> {
  bool _loading = false;

  Future<void> _toggleService() async {
    setState(() {
      _loading = true;
    });

    final action = widget.isServiceRunning ? 'stop' : 'start';

    try {
      final result = await SudoProcess.run('systemctl', [action, widget.serviceName]);

      if (result.exitCode == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Service ${widget.serviceName} ${action}ed successfully',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.green[800]!,
              duration: const Duration(seconds: 2),
            ),
          );

          widget.onServiceChanged();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to $action service ${widget.serviceName}: ${result.stderr}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.red[800]!,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error toggling service: $e',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red[800]!,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.isServiceRunning;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _toggleService,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                isRunning ? Icons.stop : Icons.play_arrow,
                size: 24,
                color: Colors.white,
              ),
        label: Text(
          isRunning ? 'Stop Service' : 'Start Service',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isRunning ? Colors.red[700] : Colors.green[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }
}
