import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/saved_networks_notifier.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/saved_network_list_item.dart';

class SavedNetworksScreen extends ConsumerStatefulWidget {
  const SavedNetworksScreen({super.key});

  @override
  ConsumerState<SavedNetworksScreen> createState() =>
      _SavedNetworksScreenState();
}

class _SavedNetworksScreenState extends ConsumerState<SavedNetworksScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(savedNetworksProvider.notifier).loadSavedNetworks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedNetworksProvider);
    final theme = ref.watch(colorThemeProvider);

    return Scaffold(
      appBar: createTopBar(context, 'Saved Networks'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(savedNetworksProvider.notifier).loadSavedNetworks();
                    },
                    icon: const Icon(Icons.refresh, size: 28),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No saved networks',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Connect to a WiFi network to save it',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final sortedNetworks = List.of(state.networks)
                  ..sort((a, b) => b.lastConnected.compareTo(a.lastConnected));

                return ListView.builder(
                  itemCount: sortedNetworks.length,
                  itemBuilder: (context, index) {
                    final network = sortedNetworks[index];
                    return SavedNetworkListItem(network: network);
                  },
                );
              } else if (state.errorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${state.errorMessage}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(savedNetworksProvider.notifier).loadSavedNetworks();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            }(),
          ),
        ],
      ),
    );
  }
}
