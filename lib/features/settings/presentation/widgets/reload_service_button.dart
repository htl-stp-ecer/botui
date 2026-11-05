import 'dart:io';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

class ReloadServiceButton extends StatefulWidget {
  final String serviceName;
  final VoidCallback onServiceChanged;

  const ReloadServiceButton({
    super.key,
    required this.serviceName,
    required this.onServiceChanged,
  });

  @override
  State<ReloadServiceButton> createState() => _ReloadServiceButtonState();
}

class _ReloadServiceButtonState extends State<ReloadServiceButton> {
  bool _loading = false;

  Future<void> _reloadService() async {
    setState(() {
      _loading = true;
    });

    try {
      final result = await SudoProcess.run('systemctl', ['reload-or-restart', widget.serviceName]);

      if (result.exitCode == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Service ${widget.serviceName} reloaded successfully',
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
                'Failed to reload service ${widget.serviceName}: ${result.stderr}',
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
              'Error reloading service: $e',
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
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _reloadService,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.refresh, size: 24, color: Colors.white),
        label: const Text(
          'Reload Service',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }
}
