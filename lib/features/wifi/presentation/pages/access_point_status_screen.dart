import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/access_point_status.dart';

class AccessPointStatusScreen extends ConsumerStatefulWidget {
  const AccessPointStatusScreen({super.key});

  @override
  ConsumerState<AccessPointStatusScreen> createState() =>
      _AccessPointStatusScreenState();
}

class _AccessPointStatusScreenState
    extends ConsumerState<AccessPointStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(accessPointProvider.notifier).refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final apState = ref.watch(accessPointProvider);

    return Scaffold(
      appBar: createTopBar(context, 'Access Point Status'),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: apState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : AccessPointStatus(
                isStarted: apState.isStarted,
                ssid: apState.config?.ssid ?? 'STP-Velox-AP',
                ipAddress: apState.ipAddress,
              ),
      ),
    );
  }
}
