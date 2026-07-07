import 'dart:math' as math;

class ExportSettings {
  const ExportSettings({
    required this.width,
    required this.height,
    this.targetBytes,
    this.jpegQuality = 92,
  });

  final int width;
  final int height;
  final int? targetBytes;
  final int jpegQuality;

  double get aspectRatio => width / height;

  bool get hasValidSize => width > 0 && height > 0;

  ExportSettings copyWith({
    int? width,
    int? height,
    int? targetBytes,
    int? jpegQuality,
  }) {
    return ExportSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      targetBytes: targetBytes ?? this.targetBytes,
      jpegQuality: jpegQuality ?? this.jpegQuality,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'targetBytes': targetBytes,
        'jpegQuality': jpegQuality,
      };

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    return ExportSettings(
      width: json['width'] as int,
      height: json['height'] as int,
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
