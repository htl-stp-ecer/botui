import 'dart:io';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

class StopServiceButton extends StatefulWidget {
  final String serviceName;
  final VoidCallback onServiceChanged;

  const StopServiceButton({
    super.key,
    required this.serviceName,
    required this.onServiceChanged,
  });

  @override
  State<StopServiceButton> createState() => _StopServiceButtonState();
}

class _StopServiceButtonState extends State<StopServiceButton> {
  bool _loading = false;

  Future<void> _stopService() async {
    setState(() {
      _loading = true;
    });

    try {
      final result = await SudoProcess.run('systemctl', ['stop', widget.serviceName]);

      if (result.exitCode == 0) {
        if (mounted) {
          AppToast.success('Service ${widget.serviceName} stopped successfully', duration: const Duration(seconds: 2));

          widget.onServiceChanged();
        }
      } else {
        if (mounted) {
          AppToast.error('Failed to stop service ${widget.serviceName}: ${result.stderr}', duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error('Error stopping service: $e', duration: const Duration(seconds: 3));
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
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _stopService,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.stop, size: 24, color: Colors.white),
        label: const Text(
          'Stop Service',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }
}
