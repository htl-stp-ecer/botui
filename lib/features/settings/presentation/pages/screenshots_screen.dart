import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/screenshot_service.dart';
import 'package:stpvelox/core/utils/home_dir.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/grey_badge.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';

/// Lists the PNGs in `~/screenshots/` (newest first) as a scrollable grid.
class ScreenshotsScreen extends ConsumerStatefulWidget {
  const ScreenshotsScreen({super.key});

  @override
  ConsumerState<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

class _ScreenshotsScreenState extends ConsumerState<ScreenshotsScreen> {
  late Future<List<File>> _files = _load();
  late final ValueNotifier<int> _saved;
  String _hostname = '';

  @override
  void initState() {
    super.initState();
    const SystemConfigService().getHostname().then((h) {
      if (mounted) setState(() => _hostname = h);
    });
    // A screenshot taken while this screen is open shows up right away.
    _saved = ref.read(screenshotServiceProvider).saved..addListener(_reload);
  }

  @override
  void dispose() {
    _saved.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final reloaded = _load();
    setState(() {
      _files = reloaded;
    });
  }

  Future<List<File>> _load() async {
    final dir = Directory('${homeDir()}/screenshots');
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.png'))
        .cast<File>()
        .toList();
    // Filenames are timestamps, so a reverse name sort is newest first.
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(
        context,
        'Screenshots',
        // No padding of its own: the top bar already keeps its distance to the battery.
        trailing: const Text(
          'Triple-Click to take a Screenshot',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<File>>(
          future: _files,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Could not load screenshots:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              );
            }
            final files = snap.data ?? const <File>[];
            if (files.isEmpty) {
              return const Center(
                child: Text(
                  'No screenshots yet',
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.15,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: files.length,
                      (context, i) => _ShotTile(
                        file: files[i],
                        onTap: () async {
                          await context.push<bool>(AppRoutes.screenshotDetail,
                              extra: files[i].path);
                          // Always re-read: the file may have been deleted there.
                          _reload();
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _CopyAllCard(hostname: _hostname)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShotTile extends StatelessWidget {
  final File file;
  final VoidCallback onTap;

  const _ShotTile({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = file.path.split('/').last;
    // Nested radii: outer = inner + padding.
    const innerRadius = 15.0;
    const padding = 14.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(innerRadius + padding),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                // Decode small: screenshots are full display size.
                cacheWidth: 400,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    ));
  }
}

/// Last item of the scroll view: how to copy the whole folder to a PC.
class _CopyAllCard extends StatelessWidget {
  final String hostname;

  const _CopyAllCard({required this.hostname});

  @override
  Widget build(BuildContext context) {
    final host = hostname.isEmpty ? 'hostname' : hostname;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(29),
        ),
        child: Column(
          children: [
            const Text(
              'To copy all screenshots to your PC:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GreyBadge('scp -r ${loginUser()}@$host.local:${homeDir()}/screenshots/ .'),
            const Text(
              "\n\nWindows Users must use the robot's IP address instead of <hostname>.local, as windows doesn't properly support mDNS.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
