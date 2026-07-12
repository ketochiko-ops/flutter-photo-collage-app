import 'dart:io';

import 'package:flutter_photo_collage_app/models/export_settings.dart';
import 'package:flutter_photo_collage_app/models/photo_metadata.dart';
import 'package:flutter_photo_collage_app/models/project_document.dart';
import 'package:flutter_photo_collage_app/services/local_image_composer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test('side frame width affects framed output geometry', () async {
    final directory = await Directory.systemTemp.createTemp('composer_test_');
    addTearDown(() => directory.delete(recursive: true));

    final sourceFile = File('${directory.path}/source.png');
    final sourceImage = image_lib.Image(width: 400, height: 300);
    image_lib.fill(sourceImage, color: image_lib.ColorRgb8(30, 80, 120));
    await sourceFile.writeAsBytes(image_lib.encodePng(sourceImage));

    final composer = LocalImageComposer();
    const exportSettings = ExportSettings(longSide: 800);
    const baseFrame = FrameSettings(
      topFrameWidth: 10,
      bottomFrameWidth: 50,
      leftFrameWidth: 20,
      rightFrameWidth: 20,
    );
    const wideSideFrame = FrameSettings(
      topFrameWidth: 10,
      bottomFrameWidth: 50,
      leftFrameWidth: 100,
      rightFrameWidth: 100,
    );

    final baseJpeg = await composer.composeFramedJpeg(
      imageFile: sourceFile,
      metadata: const PhotoMetadata(),
      exportSettings: exportSettings,
      frameSettings: baseFrame,
    );
    final wideSideJpeg = await composer.composeFramedJpeg(
      imageFile: sourceFile,
      metadata: const PhotoMetadata(),
      exportSettings: exportSettings,
      frameSettings: wideSideFrame,
    );

    final baseOutput = image_lib.decodeJpg(baseJpeg);
    final wideSideOutput = image_lib.decodeJpg(wideSideJpeg);

    expect(baseOutput, isNotNull);
    expect(wideSideOutput, isNotNull);
    expect(baseOutput!.width, 800);
    expect(wideSideOutput!.width, 800);
    expect(wideSideOutput.height, lessThan(baseOutput.height));
  });
}
