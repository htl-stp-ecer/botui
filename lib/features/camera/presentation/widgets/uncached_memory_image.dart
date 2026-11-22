import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// A JPEG from memory that is not kept in Flutter's image cache.
///
/// `Image.memory` puts every decoded picture in the global [ImageCache]. A
/// frame of a live camera is never shown a second time, so the cache would
/// fill with pictures nobody needs (on the Pi, tens of MiB) and keep them
/// after the screen is gone. This widget removes a picture from the cache as
/// soon as the next one replaces it, and when it goes away itself. The picture
/// on screen stays: the widget keeps its own reference until it is replaced.
class UncachedMemoryImage extends StatefulWidget {
  const UncachedMemoryImage({
    super.key,
    required this.bytes,
    this.cacheWidth,
    this.cacheHeight,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
  });

  final Uint8List bytes;

  /// The size to decode at, in pixels: the picture is made no larger than that.
  final int? cacheWidth;
  final int? cacheHeight;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<UncachedMemoryImage> createState() => _UncachedMemoryImageState();
}

class _UncachedMemoryImageState extends State<UncachedMemoryImage> {
  late ImageProvider _provider;

  ImageProvider _providerFor(UncachedMemoryImage widget) =>
      ResizeImage.resizeIfNeeded(
        widget.cacheWidth,
        widget.cacheHeight,
        MemoryImage(widget.bytes),
      );

  @override
  void initState() {
    super.initState();
    _provider = _providerFor(widget);
  }

  @override
  void didUpdateWidget(UncachedMemoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.cacheWidth != widget.cacheWidth ||
        oldWidget.cacheHeight != widget.cacheHeight) {
      _provider.evict();
      _provider = _providerFor(widget);
    }
  }

  @override
  void dispose() {
    _provider.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _provider,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: widget.filterQuality,
      errorBuilder: widget.errorBuilder,
    );
  }
}
