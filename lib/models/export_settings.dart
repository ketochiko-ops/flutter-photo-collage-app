import 'dart:math' as math;

class ExportSettings {
  const ExportSettings({
    this.width,
    this.height,
    this.longSide,
    this.targetBytes,
    this.jpegQuality = 92,
  });

  final int? width;
  final int? height;
  final int? longSide;
  final int? targetBytes;
  final int jpegQuality;

  double get aspectRatio {
    final safeWidth = width;
    final safeHeight = height;
    if (safeWidth == null || safeHeight == null || safeHeight <= 0) {
      return 1;
    }
    return safeWidth / safeHeight;
  }

  bool get hasValidSize => longSide == null || longSide! > 0;

  ExportSettings copyWith({
    int? width,
    int? height,
    int? longSide,
    int? targetBytes,
    int? jpegQuality,
  }) {
    return ExportSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      longSide: longSide ?? this.longSide,
      targetBytes: targetBytes ?? this.targetBytes,
      jpegQuality: jpegQuality ?? this.jpegQuality,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'longSide': longSide,
        'targetBytes': targetBytes,
        'jpegQuality': jpegQuality,
      };

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    final width = json['width'] as int?;
    final height = json['height'] as int?;
    return ExportSettings(
      width: width,
      height: height,
      longSide: json.containsKey('longSide')
          ? json['longSide'] as int?
          : (width == null || height == null ? null : math.max(width, height)),
      targetBytes: json['targetBytes'] as int?,
      jpegQuality: json['jpegQuality'] as int? ?? 92,
    );
  }
}

class SizeLimiter {
  const SizeLimiter();

  int nextQuality(int currentQuality) {
    if (currentQuality <= 50) {
      return currentQuality - 5;
    }
    if (currentQuality <= 75) {
      return currentQuality - 8;
    }
    return currentQuality - 10;
  }

  bool shouldRetry({
    required int currentBytes,
    required int? targetBytes,
    required int currentQuality,
  }) {
    if (targetBytes == null || targetBytes <= 0) {
      return false;
    }
    return currentBytes > targetBytes && currentQuality > 25;
  }

  int clampQuality(int quality) => math.max(20, math.min(100, quality));
}
