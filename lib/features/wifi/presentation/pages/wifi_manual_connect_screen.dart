import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_client_state.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/wifi_manual_connect_form.dart';

class WifiManualConnectScreen extends ConsumerWidget {
  const WifiManualConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<WifiClientState>(wifiClientProvider, (previous, state) {
      if (state.connectedSsid != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Connected to ${state.connectedSsid} successfully!'),
            backgroundColor: Colors.green[800]!));
        context.pop();
      } else if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${state.errorMessage}'),
            backgroundColor: Colors.red[800]!));
      }
    });

    return Scaffold(
      appBar: createTopBar(context, 'Manual WiFi Connect'),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: WifiManualConnectForm(),
      ),
    );
  }
}
