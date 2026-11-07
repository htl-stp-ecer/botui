import 'package:flutter/material.dart';

class LanOnlyStatus extends StatelessWidget {
  final bool isActive;
  final bool isCableConnected;
  final String? ipAddress;
  final String? macAddress;

  const LanOnlyStatus({
    super.key,
    required this.isActive,
    required this.isCableConnected,
    this.ipAddress,
    this.macAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue[900] : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.blue[400]! : Colors.grey[600]!,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.cable : Icons.cable_outlined,
                color: isActive ? Colors.blue[300] : Colors.grey[400],
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                isActive ? 'Ethernet Mode Active' : 'Ethernet Mode Inactive',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.blue[300] : Colors.grey[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Cable connection status
          Row(
            children: [
              Icon(
                isCableConnected ? Icons.check_circle : Icons.warning,
                color: isCableConnected ? Colors.green[400] : Colors.orange[400],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCableConnected ? 'Ethernet cable connected' : 'No ethernet cable detected',
                style: TextStyle(
                  fontSize: 14,
                  color: isCableConnected ? Colors.green[300] : Colors.orange[300],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            if (ipAddress != null) ...[
              Text(
                'IP Address: $ipAddress',
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
            ],
            if (macAddress != null) ...[
              Text(
                'MAC Address: $macAddress',
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'WiFi is disabled - using wired connection only',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic),
            ),
          ] else if (!isCableConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[900]?.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[400]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[300], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connect an ethernet cable before switching to Ethernet Mode',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[100],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

