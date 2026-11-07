import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/wifi_scan_list_item.dart';

class WifiScanListScreen extends ConsumerStatefulWidget {
  const WifiScanListScreen({super.key});

  @override
  ConsumerState<WifiScanListScreen> createState() =>
      _WifiScanListScreenState();
}

class _WifiScanListScreenState extends ConsumerState<WifiScanListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(wifiClientProvider.notifier).loadNetworks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wifiClientProvider);
    final theme = ref.watch(colorThemeProvider);

    return Scaffold(
      appBar: createTopBar(context, 'Scanned WiFi Networks'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(wifiClientProvider.notifier).loadNetworks();
                    },
                    icon: const Icon(Icons.refresh, size: 28),
                    label: const Text(
                      'Refresh',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.tileColor(TileColor.blue, 0),
                      foregroundColor: theme.textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.wifiManualConnect),
                    icon: const Icon(Icons.add, size: 28),
                    label: const Text(
                      'Manual',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.tileColor(TileColor.green, 1),
                      foregroundColor: theme.textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey[800],
          ),
          Expanded(
            child: () {

              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (!state.isLoading) {
                if (state.networks.isEmpty) {
                  return const Center(child: Text('No networks found.'));
                }
                final sortedNetworks = state.networks.sorted((a, b) => a.compareTo(b));

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(wifiClientProvider.notifier).loadNetworks();
                  },
                  child: ListView.builder(
                    // Cards add 4 above/below themselves; 12 more makes the gap
                    // at the top and bottom 16, like the sides.
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: sortedNetworks.length,
                    itemBuilder: (context, index) {
                      final network = sortedNetworks[index];
                      return WifiScanListItem(network: network);
                    },
                  ),
                );
              } else if (state.errorMessage != null) {
                return Center(
                    child: Text(
                      'Error: ${state.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                    ));
              }
              return const SizedBox();
            }(),
          ),
        ],
      ),
    );
  }
}
