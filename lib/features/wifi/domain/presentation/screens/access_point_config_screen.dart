import 'package:flutter/material.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/access_point_state.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/access_point_form.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/access_point_status.dart';

class AccessPointConfigScreen extends ConsumerStatefulWidget {
  const AccessPointConfigScreen({super.key});

  @override
  ConsumerState<AccessPointConfigScreen> createState() =>
      _AccessPointConfigScreenState();
}

class _AccessPointConfigScreenState
    extends ConsumerState<AccessPointConfigScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(accessPointProvider.notifier).refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AccessPointState>(accessPointProvider, (previous, state) {
      // Only show snackbar if isStarted actually changed
      if (previous != null && previous.isStarted != state.isStarted) {
        if (state.isStarted) {
          AppToast.success('Hotspot started successfully');
        } else {
          AppToast.info('Hotspot stopped');
        }
      }

      // Show error message only if it's new
      if (state.errorMessage != null &&
          state.errorMessage != previous?.errorMessage) {
        AppToast.error('Error: ${state.errorMessage}');
      }
    });

    final state = ref.watch(accessPointProvider);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Hotspot Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccessPointStatus(
              isStarted: state.isStarted,
              config: state.config,
              ipAddress: state.ipAddress,
              connectedClients: state.connectedClients,
            ),
            const SizedBox(height: 14),
            AccessPointForm(
              initialConfig: state.config,
              isStarted: state.isStarted,
              isLoading: state.isLoading,
              onStart: (config) {
                ref.read(accessPointProvider.notifier).startAccessPoint(config);
              },
              onStop: () {
                ref.read(accessPointProvider.notifier).stopAccessPoint();
              },
            ),
          ],
        ),
      ),
    );
  }
}
