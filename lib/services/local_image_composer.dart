import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image_lib;

import '../models/collage_layout.dart';
import '../models/export_settings.dart';
import '../models/photo_metadata.dart';
import '../models/project_document.dart';

class LocalImageComposer {
  LocalImageComposer({SizeLimiter sizeLimiter = const SizeLimiter()})
      : _sizeLimiter = sizeLimiter;

  final SizeLimiter _sizeLimiter;

  Future<Uint8List> composeFramedJpeg({
    required File imageFile,
    required PhotoMetadata metadata,
    required ExportSettings exportSettings,
    required FrameSettings frameSettings,
  }) async {
    final image = await _decodeUiImage(await imageFile.readAsBytes());
    final size = _resolveFrameCanvasSize(image, exportSettings);
    final picture = ui.PictureRecorder();
    final canvas = Canvas(picture);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(frameSettings.backgroundColor),
    );

    final imageBounds = Rect.fromLTRB(
      frameSettings.leftFrameWidth,
      frameSettings.topFrameWidth,
      size.width - frameSettings.rightFrameWidth,
      size.height - frameSettings.bottomFrameWidth,
    );
    final imageRect = _safeDeflate(imageBounds, frameSettings.imagePadding);

    _drawFittedImage(canvas, image, imageRect, BoxFit.contain);
    _drawMetadataPanel(canvas, size, metadata, frameSettings);

    final rendered = await _renderPicture(picture, size);
    return _encodeJpegUnderTarget(rendered, exportSettings);
  }

  Future<Uint8List> composeCollageJpeg({
    required List<File> imageFiles,
    required ExportSettings exportSettings,
    required CollageSettings collageSettings,
  }) async {
    final images = <ui.Image>[];
    for (final imageFile in imageFiles) {
      images.add(await _decodeUiImage(await imageFile.readAsBytes()));
    }
    final size = _resolveCollageCanvasSize(images, exportSettings);
    final picture = ui.PictureRecorder();
    final canvas = Canvas(picture);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(collageSettings.backgroundColor),
    );

    final layout = const CollageLayout().build(
      itemCount: imageFiles.length,
      columns: collageSettings.columns,
      canvasSize: size,
      gutter: collageSettings.gutter,
    );

    for (var index = 0; index < images.length; index++) {
      _drawFittedImage(canvas, images[index], layout[index], BoxFit.cover);
    }

    final rendered = await _renderPicture(picture, size);
    return _encodeJpegUnderTarget(rendered, exportSettings);
  }

  Size _resolveFrameCanvasSize(ui.Image image, ExportSettings settings) {
    final sourceWidth = image.width.toDouble();
    final sourceHeight = image.height.toDouble();
    final requestedLongSide = settings.longSide;
    if (requestedLongSide == null || requestedLongSide <= 0) {
      return Size(sourceWidth, sourceHeight);
    }

    final scale = requestedLongSide / math.max(sourceWidth, sourceHeight);
    return Size(
      math.max(1.0, sourceWidth * scale),
      math.max(1.0, sourceHeight * scale),
    );
  }

  Size _resolveCollageCanvasSize(
    List<ui.Image> images,
    ExportSettings settings,
  ) {
    final requestedLongSide = settings.longSide;
    if (requestedLongSide != null && requestedLongSide > 0) {
      return Size.square(requestedLongSide.toDouble());
    }
    if (images.isEmpty) {
      return const Size.square(1);
    }
    final longestSide = images
        .map((image) => math.max(image.width, image.height))
        .reduce(math.max);
    return Size.square(longestSide.toDouble());
  }

  Future<void> writeJpeg({
    required Uint8List bytes,
    required File destination,
  }) async {
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
  }

  void _drawMetadataPanel(
    Canvas canvas,
    Size size,
    PhotoMetadata metadata,
    FrameSettings settings,
  ) {
    final panelTop = size.height - settings.bottomFrameWidth;
    final panel = Rect.fromLTWH(
      settings.leftFrameWidth,
      panelTop,
      size.width - settings.leftFrameWidth - settings.rightFrameWidth,
      settings.bottomFrameWidth,
    );
    if (panel.width <= 0 || panel.height <= 0) {
      return;
    }
    final textColor = Color(settings.textStyle.textColor);
    final fontFamily =
        settings.textStyle.fontFamily == 'System' ? null : settings.textStyle.fontFamily;

    final children = <InlineSpan>[
      TextSpan(
        text: metadata.displayParts.join('  /  '),
        style: TextStyle(
          color: textColor,
          fontFamily: fontFamily,
          fontSize: settings.textStyle.fontSize,
          height: 1.24,
        ),
      ),
    ];

    final painter = TextPainter(
      text: TextSpan(children: children),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: panel.width);

    final dy = panel.top + (panel.height - painter.height) / 2;
    painter.paint(canvas, Offset(panel.left, dy));
  }

  Rect _safeDeflate(Rect rect, double delta) {
    if (rect.width <= 0 || rect.height <= 0) {
      return Rect.fromLTWH(rect.left, rect.top, 1, 1);
    }
    final maxDelta = rect.shortestSide / 2 - 0.5;
    if (maxDelta <= 0) {
      return rect;
    }
    final safeDelta = delta.clamp(0, maxDelta).toDouble();
    return rect.deflate(safeDelta);
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _drawFittedImage(
    Canvas canvas,
    ui.Image image,
    Rect outputRect,
    BoxFit fit,
  ) {
    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(fit, inputSize, outputRect.size);
    final inputSubrect = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & inputSize,
    );
    final outputSubrect = Alignment.center.inscribe(
      fitted.destination,
      outputRect,
    );
    canvas.drawImageRect(image, inputSubrect, outputSubrect, Paint());
  }

  Future<image_lib.Image> _renderPicture(ui.PictureRecorder picture, Size size) async {
    final uiImage = await picture
        .endRecording()
        .toImage(size.width.round(), size.height.round());
    final rgba = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      throw StateError('Failed to read rendered image bytes.');
    }
    return image_lib.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: rgba.buffer,
      order: image_lib.ChannelOrder.rgba,
    );
  }

  Uint8List _encodeJpegUnderTarget(
    image_lib.Image rendered,
    ExportSettings settings,
  ) {
    var quality = _sizeLimiter.clampQuality(settings.jpegQuality);
    var encoded = Uint8List.fromList(
      image_lib.encodeJpg(rendered, quality: quality),
    );

    while (_sizeLimiter.shouldRetry(
      currentBytes: encoded.length,
      targetBytes: settings.targetBytes,
      currentQuality: quality,
    )) {
      quality = _sizeLimiter.clampQuality(_sizeLimiter.nextQuality(quality));
      encoded = Uint8List.fromList(
        image_lib.encodeJpg(rendered, quality: quality),
      );
    }
    return encoded;
  }
}
