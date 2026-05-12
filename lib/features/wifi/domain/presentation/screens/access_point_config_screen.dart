import 'package:flutter/material.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hotspot started successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hotspot stopped')),
          );
        }
      }

      // Show error message only if it's new
      if (state.errorMessage != null &&
          state.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${state.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    final state = ref.watch(accessPointProvider);

    return Scaffold(
      appBar: createTopBar(context, 'Hotspot Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccessPointStatus(
              isStarted: state.isStarted,
              ssid: state.config?.ssid ?? '',
              ipAddress: state.ipAddress,
            ),
            const SizedBox(height: 16),
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
