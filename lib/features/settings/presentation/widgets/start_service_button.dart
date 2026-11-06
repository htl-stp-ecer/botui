import 'dart:io';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

class StartServiceButton extends StatefulWidget {
  final String serviceName;
  final VoidCallback onServiceChanged;

  const StartServiceButton({
    super.key,
    required this.serviceName,
    required this.onServiceChanged,
  });

  @override
  State<StartServiceButton> createState() => _StartServiceButtonState();
}

class _StartServiceButtonState extends State<StartServiceButton> {
  bool _loading = false;

  Future<void> _startService() async {
    setState(() {
      _loading = true;
    });

    try {
      final result = await SudoProcess.run('systemctl', ['start', widget.serviceName]);

      if (result.exitCode == 0) {
        if (mounted) {
          AppToast.success('Service ${widget.serviceName} started successfully', duration: const Duration(seconds: 2));

          widget.onServiceChanged();
        }
      } else {
        if (mounted) {
          AppToast.error('Failed to start service ${widget.serviceName}: ${result.stderr}', duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error('Error starting service: $e', duration: const Duration(seconds: 3));
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
        onPressed: _loading ? null : _startService,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow, size: 24, color: Colors.white),
        label: const Text(
          'Start Service',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }
}
