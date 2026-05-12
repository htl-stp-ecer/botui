import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/lan_only_status.dart';

class LanOnlyStatusScreen extends ConsumerStatefulWidget {
  const LanOnlyStatusScreen({super.key});

  @override
  ConsumerState<LanOnlyStatusScreen> createState() =>
      _LanOnlyStatusScreenState();
}

class _LanOnlyStatusScreenState extends ConsumerState<LanOnlyStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Use Future.microtask to avoid modifying provider during widget build
    Future.microtask(() {
      ref.read(lanOnlyProvider.notifier).checkStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lanState = ref.watch(lanOnlyProvider);

    return Scaffold(
      appBar: createTopBar(context, 'LAN Status'),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: lanState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  LanOnlyStatus(
                    isActive: lanState.isActive,
                    isCableConnected: lanState.isCableConnected,
                    ipAddress: lanState.ipAddress,
                    macAddress: lanState.macAddress,
                  ),
                  if (lanState.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFD93025),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x332B0D0A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_rounded,
                            color: Color(0xFFD93025),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lanState.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF5F1A16),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
