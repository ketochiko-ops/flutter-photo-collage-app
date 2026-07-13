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
    final size = _resolveFrameCanvasSize(image, exportSettings, frameSettings);
    final picture = ui.PictureRecorder();
    final canvas = Canvas(picture);

    if (frameSettings.textPlacement != TextPlacement.image) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Color(frameSettings.backgroundColor),
      );
    }

    final imageBounds = frameSettings.textPlacement == TextPlacement.image
        ? Offset.zero & size
        : Rect.fromLTRB(
            frameSettings.leftFrameWidth,
            frameSettings.topFrameWidth,
            size.width - frameSettings.rightFrameWidth,
            size.height - frameSettings.bottomFrameWidth,
          );
    final imageRect = frameSettings.textPlacement == TextPlacement.image
        ? imageBounds
        : _safeDeflate(imageBounds, frameSettings.imagePadding);

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

  Size _resolveFrameCanvasSize(
    ui.Image image,
    ExportSettings settings,
    FrameSettings frameSettings,
  ) {
    final sourceWidth = image.width.toDouble();
    final sourceHeight = image.height.toDouble();
    final sourceAspectRatio = sourceWidth / sourceHeight;
    final horizontalFrame =
        frameSettings.leftFrameWidth + frameSettings.rightFrameWidth;
    final verticalFrame =
        frameSettings.topFrameWidth + frameSettings.bottomFrameWidth;
    final requestedLongSide = settings.longSide;
    if (requestedLongSide == null || requestedLongSide <= 0) {
      return Size(
        math.max(1.0, sourceWidth + horizontalFrame),
        math.max(1.0, sourceHeight + verticalFrame),
      );
    }

    final longSide = requestedLongSide.toDouble();
    final sizeFromFixedWidth = Size(
      longSide,
      math.max(1.0, (longSide - horizontalFrame) / sourceAspectRatio) +
          verticalFrame,
    );
    if (sizeFromFixedWidth.height <= longSide) {
      return sizeFromFixedWidth;
    }

    return Size(
      math.max(1.0, (longSide - verticalFrame) * sourceAspectRatio) +
          horizontalFrame,
      longSide,
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
    final panel = switch (settings.textPlacement) {
      TextPlacement.topFrame => Rect.fromLTWH(
          settings.leftFrameWidth,
          0,
          size.width - settings.leftFrameWidth - settings.rightFrameWidth,
          settings.topFrameWidth,
        ),
      TextPlacement.bottomFrame => Rect.fromLTWH(
          settings.leftFrameWidth,
          size.height - settings.bottomFrameWidth,
          size.width - settings.leftFrameWidth - settings.rightFrameWidth,
          settings.bottomFrameWidth,
        ),
      TextPlacement.image =>
        (Offset.zero & size).deflate(settings.imagePadding),
    };
    if (panel.width <= 0 || panel.height <= 0) {
      return;
    }
    final textColor = Color(settings.textStyle.textColor);
    final fontFamily = settings.textStyle.fontFamily == 'System'
        ? null
        : settings.textStyle.fontFamily;

    final children = _metadataSpans(
      metadata,
      TextStyle(
        color: textColor,
        fontFamily: fontFamily,
        fontSize: settings.textStyle.fontSize,
        height: 1.24,
      ),
      TextStyle(
        color: textColor,
        fontFamily: fontFamily,
        fontSize: settings.textStyle.detailFontSize,
        height: 1.24,
      ),
    );
    if (children.isEmpty) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(children: children),
      textDirection: TextDirection.ltr,
      textAlign: _textAlign(settings.textHorizontalAlignment),
      maxLines: 3,
      ellipsis: '...',
    )..layout(minWidth: panel.width, maxWidth: panel.width);

    final dy = switch (settings.textVerticalAlignment) {
      TextVerticalAlignment.top => panel.top,
      TextVerticalAlignment.center =>
        panel.top + (panel.height - painter.height) / 2,
      TextVerticalAlignment.bottom => panel.bottom - painter.height,
    };
    painter.paint(canvas, Offset(panel.left, dy));
  }

  List<InlineSpan> _metadataSpans(
    PhotoMetadata metadata,
    TextStyle equipmentStyle,
    TextStyle detailStyle,
  ) {
    const equipmentSeparator = '    ';
    const detailSeparator = '  ';
    final spans = <InlineSpan>[];
    var previousWasDetail = false;

    void addPart(String value, TextStyle style, {required bool isDetail}) {
      final text = value.trim();
      if (text.isEmpty) {
        return;
      }
      if (spans.isNotEmpty) {
        spans.add(TextSpan(
          text: previousWasDetail && isDetail
              ? detailSeparator
              : equipmentSeparator,
          style: detailStyle,
        ));
      }
      spans.add(TextSpan(text: text, style: style));
      previousWasDetail = isDetail;
    }

    addPart(metadata.camera, equipmentStyle, isDetail: false);
    addPart(metadata.lens, equipmentStyle, isDetail: false);
    addPart(metadata.focalLength, detailStyle, isDetail: true);
    addPart(metadata.aperture, detailStyle, isDetail: true);
    addPart(metadata.shutterSpeed, detailStyle, isDetail: true);
    if (metadata.iso.trim().isNotEmpty) {
      addPart('ISO ${metadata.iso.trim()}', detailStyle, isDetail: true);
    }

    return spans;
  }

  TextAlign _textAlign(TextHorizontalAlignment alignment) {
    return switch (alignment) {
      TextHorizontalAlignment.left => TextAlign.left,
      TextHorizontalAlignment.center => TextAlign.center,
      TextHorizontalAlignment.right => TextAlign.right,
    };
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

  Future<image_lib.Image> _renderPicture(
      ui.PictureRecorder picture, Size size) async {
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
