import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/core/widgets/grey_badge.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';

/// One screenshot, uncropped, with its `scp` command and a delete button.
/// Pops with `true` when the file was deleted.
class ScreenshotDetailScreen extends StatefulWidget {
  final String path;

  const ScreenshotDetailScreen({super.key, required this.path});

  @override
  State<ScreenshotDetailScreen> createState() => _ScreenshotDetailScreenState();
}

class _ScreenshotDetailScreenState extends State<ScreenshotDetailScreen> {
  // Same radius as the preview in the overview.
  static const _radius = 15.0;

  late final File _file = File(widget.path);
  late final String _name = widget.path.split('/').last;
  late final Future<(Uint8List, double)> _image = _loadImage();
  String _hostname = '';

  @override
  void initState() {
    super.initState();
    const SystemConfigService().getHostname().then((h) {
      if (mounted) setState(() => _hostname = h);
    });
  }

  /// The bytes plus width/height, so the image can be shown at its own aspect
  /// ratio and the rounded corners sit on the image itself, not on letterboxing.
  Future<(Uint8List, double)> _loadImage() async {
    final bytes = await _file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();
    return (bytes, ratio);
  }

  Future<void> _delete() async {
    final confirmed = await showRaccoonConfirmDialog(
      context,
      title: 'Delete screenshot?',
      message: 'Do you really want to delete $_name?',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline,
      iconColor: Colors.red,
    );
    if (!confirmed) return;
    try {
      await _file.delete();
    } catch (e) {
      AppToast.error('Failed to delete $_name');
      return;
    }
    AppToast.success('Deleted $_name');
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final host = _hostname.isEmpty ? 'hostname' : _hostname;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: createTopBar(context, _name),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: FutureBuilder<(Uint8List, double)>(
                    future: _image,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Icon(Icons.broken_image,
                            color: Colors.white38, size: 64);
                      }
                      final data = snap.data;
                      if (data == null) return const CircularProgressIndicator();
                      return AspectRatio(
                        aspectRatio: data.$2,
                        child: Container(
                          // Drawn over the image's edge, so the size stays.
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(_radius),
                            border: Border.all(color: Colors.grey[700]!, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(_radius),
                            child: Image.memory(data.$1, fit: BoxFit.fill),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GreyBadge('scp pi@$host.local:/home/pi/screenshots/$_name .'),
                    ),
                  ),
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    iconSize: 40,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
