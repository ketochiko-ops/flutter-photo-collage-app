import 'dart:ui';

import 'package:flutter_photo_collage_app/models/collage_layout.dart';
import 'package:flutter_photo_collage_app/models/export_settings.dart';
import 'package:flutter_photo_collage_app/models/photo_metadata.dart';
import 'package:flutter_photo_collage_app/models/project_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhotoMetadata', () {
    // 撮影情報の表示順と、ISO表記が重複しないことを確認します。
    test('builds display parts and prefixes ISO once', () {
      const metadata = PhotoMetadata(
        camera: 'FUJIFILM X-T5',
        lens: 'XF 35mm F1.4',
        focalLength: '35 mm',
        aperture: 'f/2',
        shutterSpeed: '1/250',
        iso: '400',
      );

      expect(metadata.displayParts, [
        'FUJIFILM X-T5',
        'XF 35mm F1.4',
        '35 mm',
        'f/2',
        '1/250',
        'ISO 400',
      ]);
    });
  });

  group('CollageLayout', () {
    // ガターを含めたグリッドの各矩形が、期待どおりの位置とサイズになることを確認します。
    test('creates stable grid rects with gutters', () {
      final rects = const CollageLayout().build(
        itemCount: 4,
        columns: 2,
        canvasSize: const Size(1000, 1000),
        gutter: 20,
      );

      expect(rects, hasLength(4));
      expect(rects.first, const Rect.fromLTWH(20, 20, 470, 470));
      expect(rects.last, const Rect.fromLTWH(510, 510, 470, 470));
    });

    // 指定列数が画像枚数より多い場合、画像枚数に合わせて列数が制限されることを確認します。
    test('limits columns to item count', () {
      final rects = const CollageLayout().build(
        itemCount: 2,
        columns: 6,
        canvasSize: const Size(800, 400),
        gutter: 10,
      );

      expect(rects, hasLength(2));
      expect(rects.first.width, 385);
      expect(rects.first.height, 380);
    });
  });

  group('ExportSettings and SizeLimiter', () {
    // 書き出し設定をJSON化して復元しても、設定値が維持されることを確認します。
    test('round-trips json', () {
      const settings = ExportSettings(
        width: 1920,
        height: 1080,
        targetBytes: 900000,
        jpegQuality: 88,
      );

      expect(ExportSettings.fromJson(settings.toJson()).toJson(),
          settings.toJson());
    });

    test('restores long side from legacy width and height json', () {
      final settings = ExportSettings.fromJson(const {
        'width': 1920,
        'height': 1080,
      });

      expect(settings.longSide, 1920);
    });

    // 出力サイズが目標バイト数を超えた場合だけ、品質調整の再試行が必要になることを確認します。
    test('retries only when target bytes are exceeded', () {
      const limiter = SizeLimiter();

      expect(
        limiter.shouldRetry(
          currentBytes: 1200,
          targetBytes: 1000,
          currentQuality: 90,
        ),
        isTrue,
      );
      expect(
        limiter.shouldRetry(
          currentBytes: 900,
          targetBytes: 1000,
          currentQuality: 90,
        ),
        isFalse,
      );
    });
  });

  group('ProjectDocument', () {
    test('uses requested default collage settings', () {
      const settings = CollageSettings();

      expect(settings.columns, 2);
      expect(settings.gutter, 10);
      expect(settings.aspectRatio, 1);
      expect(settings.backgroundColor, 0xFF000000);
    });

    test('round-trips collage aspect ratio settings', () {
      const settings = CollageSettings(
        columns: 3,
        gutter: 12,
        aspectRatio: 1.5,
      );

      final restored = CollageSettings.fromJson(settings.toJson());

      expect(restored.columns, 3);
      expect(restored.gutter, 12);
      expect(restored.aspectRatio, 1.5);
    });

    test('uses requested default frame widths', () {
      const settings = FrameSettings();

      expect(settings.leftFrameWidth, 100);
      expect(settings.rightFrameWidth, 100);
      expect(settings.topFrameWidth, 100);
      expect(settings.bottomFrameWidth, 350);
      expect(settings.bottomPanelHeight, 350);
      expect(settings.backgroundColor, 0xFF000000);
      expect(settings.textStyle.fontSize, 90);
      expect(settings.textStyle.detailFontSize, 60);
      expect(settings.textStyle.textColor, 0xFFFFFFFF);
      expect(
        settings.textHorizontalAlignment,
        TextHorizontalAlignment.center,
      );
    });

    // プロジェクト情報、使用画像、撮影情報、書き出し設定がJSONから復元されることを確認します。
    test('round-trips project json', () {
      final now = DateTime.utc(2026, 7, 7, 1, 2, 3);
      final document = ProjectDocument(
        id: 'project-1',
        name: 'sample',
        kind: ProjectKind.frame,
        createdAt: now,
        updatedAt: now,
        assets: const [
          ProjectAsset(
            id: 'asset-1',
            fileName: 'photo.jpg',
            relativePath: 'assets/asset-1.jpg',
          ),
        ],
        exportSettings: const ExportSettings(width: 3000, height: 2000),
        metadata: const PhotoMetadata(camera: 'Camera'),
        frameSettings: const FrameSettings(),
      );

      final restored = ProjectDocument.fromJson(document.toJson());

      expect(restored.id, document.id);
      expect(restored.kind, ProjectKind.frame);
      expect(restored.assets.single.relativePath, 'assets/asset-1.jpg');
      expect(restored.metadata.camera, 'Camera');
      expect(restored.exportSettings.width, 3000);
    });

    test('restores frame widths from legacy frame settings json', () {
      final settings = FrameSettings.fromJson(const {
        'borderWidth': 80,
        'bottomPanelHeight': 260,
      });

      expect(settings.topFrameWidth, 80);
      expect(settings.rightFrameWidth, 80);
      expect(settings.bottomFrameWidth, 260);
      expect(settings.leftFrameWidth, 80);
      expect(settings.toJson()['bottomPanelHeight'], 260);
    });

    test('round-trips text placement settings', () {
      const settings = FrameSettings(
        textStyle: TextStyleSettings(
          fontSize: 80,
          detailFontSize: 52,
        ),
        textHorizontalAlignment: TextHorizontalAlignment.right,
        textVerticalAlignment: TextVerticalAlignment.top,
        textPlacement: TextPlacement.image,
      );

      final restored = FrameSettings.fromJson(settings.toJson());

      expect(restored.textStyle.fontSize, 80);
      expect(restored.textStyle.detailFontSize, 52);
      expect(restored.textHorizontalAlignment, TextHorizontalAlignment.right);
      expect(restored.textVerticalAlignment, TextVerticalAlignment.top);
      expect(restored.textPlacement, TextPlacement.image);
    });

    test('uses equipment font size for legacy detail font size', () {
      final settings = FrameSettings.fromJson(const {
        'textStyle': {
          'fontSize': 64,
        },
      });

      expect(settings.textStyle.fontSize, 64);
      expect(settings.textStyle.detailFontSize, 64);
    });

    test('uses split font size defaults from empty text style json', () {
      final settings = FrameSettings.fromJson(const {
        'textStyle': {},
      });

      expect(settings.textStyle.fontSize, 90);
      expect(settings.textStyle.detailFontSize, 60);
    });
  });
}
