import 'export_settings.dart';
import 'photo_metadata.dart';

enum ProjectKind { frame, collage }

enum TextHorizontalAlignment { left, center, right }

enum TextVerticalAlignment { top, center, bottom }

enum TextPlacement { topFrame, bottomFrame, image }

class ProjectAsset {
  const ProjectAsset({
    required this.id,
    required this.fileName,
    required this.relativePath,
  });

  final String id;
  final String fileName;
  final String relativePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'relativePath': relativePath,
      };

  factory ProjectAsset.fromJson(Map<String, dynamic> json) {
    return ProjectAsset(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      relativePath: json['relativePath'] as String,
    );
  }
}

class TextStyleSettings {
  const TextStyleSettings({
    this.fontFamily = 'System',
    this.fontSize = 36,
    this.textColor = 0xFF111111,
  });

  final String fontFamily;
  final double fontSize;
  final int textColor;

  TextStyleSettings copyWith({
    String? fontFamily,
    double? fontSize,
    int? textColor,
  }) {
    return TextStyleSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'textColor': textColor,
      };

  factory TextStyleSettings.fromJson(Map<String, dynamic> json) {
    return TextStyleSettings(
      fontFamily: json['fontFamily'] as String? ?? 'System',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 36,
      textColor: json['textColor'] as int? ?? 0xFF111111,
    );
  }
}

class FrameSettings {
  const FrameSettings({
    this.borderColor = 0xFFFFFFFF,
    this.backgroundColor = 0xFFFFFFFF,
    this.borderWidth = 64,
    this.topFrameWidth = 64,
    this.rightFrameWidth = 64,
    this.bottomFrameWidth = 220,
    this.leftFrameWidth = 64,
    this.bottomPanelHeight = 220,
    this.imagePadding = 24,
    this.textStyle = const TextStyleSettings(),
    this.textHorizontalAlignment = TextHorizontalAlignment.left,
    this.textVerticalAlignment = TextVerticalAlignment.center,
    this.textPlacement = TextPlacement.bottomFrame,
  });

  final int borderColor;
  final int backgroundColor;
  final double borderWidth;
  final double topFrameWidth;
  final double rightFrameWidth;
  final double bottomFrameWidth;
  final double leftFrameWidth;
  final double bottomPanelHeight;
  final double imagePadding;
  final TextStyleSettings textStyle;
  final TextHorizontalAlignment textHorizontalAlignment;
  final TextVerticalAlignment textVerticalAlignment;
  final TextPlacement textPlacement;

  FrameSettings copyWith({
    int? borderColor,
    int? backgroundColor,
    double? borderWidth,
    double? topFrameWidth,
    double? rightFrameWidth,
    double? bottomFrameWidth,
    double? leftFrameWidth,
    double? bottomPanelHeight,
    double? imagePadding,
    TextStyleSettings? textStyle,
    TextHorizontalAlignment? textHorizontalAlignment,
    TextVerticalAlignment? textVerticalAlignment,
    TextPlacement? textPlacement,
  }) {
    return FrameSettings(
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderWidth: borderWidth ?? this.borderWidth,
      topFrameWidth: topFrameWidth ?? this.topFrameWidth,
      rightFrameWidth: rightFrameWidth ?? this.rightFrameWidth,
      bottomFrameWidth: bottomFrameWidth ?? this.bottomFrameWidth,
      leftFrameWidth: leftFrameWidth ?? this.leftFrameWidth,
      bottomPanelHeight:
          bottomPanelHeight ?? bottomFrameWidth ?? this.bottomPanelHeight,
      imagePadding: imagePadding ?? this.imagePadding,
      textStyle: textStyle ?? this.textStyle,
      textHorizontalAlignment:
          textHorizontalAlignment ?? this.textHorizontalAlignment,
      textVerticalAlignment: textVerticalAlignment ?? this.textVerticalAlignment,
      textPlacement: textPlacement ?? this.textPlacement,
    );
  }

  Map<String, dynamic> toJson() => {
        'borderColor': borderColor,
        'backgroundColor': backgroundColor,
        'borderWidth': borderWidth,
        'topFrameWidth': topFrameWidth,
        'rightFrameWidth': rightFrameWidth,
        'bottomFrameWidth': bottomFrameWidth,
        'leftFrameWidth': leftFrameWidth,
        'bottomPanelHeight': bottomFrameWidth,
        'imagePadding': imagePadding,
        'textStyle': textStyle.toJson(),
        'textHorizontalAlignment': textHorizontalAlignment.name,
        'textVerticalAlignment': textVerticalAlignment.name,
        'textPlacement': textPlacement.name,
      };

  factory FrameSettings.fromJson(Map<String, dynamic> json) {
    final legacyBorderWidth = (json['borderWidth'] as num?)?.toDouble() ?? 64;
    final legacyBottomPanelHeight =
        (json['bottomPanelHeight'] as num?)?.toDouble() ?? 220;

    return FrameSettings(
      borderColor: json['borderColor'] as int? ?? 0xFFFFFFFF,
      backgroundColor: json['backgroundColor'] as int? ?? 0xFFFFFFFF,
      borderWidth: legacyBorderWidth,
      topFrameWidth:
          (json['topFrameWidth'] as num?)?.toDouble() ?? legacyBorderWidth,
      rightFrameWidth:
          (json['rightFrameWidth'] as num?)?.toDouble() ?? legacyBorderWidth,
      bottomFrameWidth:
          (json['bottomFrameWidth'] as num?)?.toDouble() ??
              legacyBottomPanelHeight,
      leftFrameWidth:
          (json['leftFrameWidth'] as num?)?.toDouble() ?? legacyBorderWidth,
      bottomPanelHeight: legacyBottomPanelHeight,
      imagePadding: (json['imagePadding'] as num?)?.toDouble() ?? 24,
      textStyle: TextStyleSettings.fromJson(
        json['textStyle'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      textHorizontalAlignment: _enumValue(
        TextHorizontalAlignment.values,
        json['textHorizontalAlignment'] as String?,
        TextHorizontalAlignment.left,
      ),
      textVerticalAlignment: _enumValue(
        TextVerticalAlignment.values,
        json['textVerticalAlignment'] as String?,
        TextVerticalAlignment.center,
      ),
      textPlacement: _enumValue(
        TextPlacement.values,
        json['textPlacement'] as String?,
        TextPlacement.bottomFrame,
      ),
    );
  }
}

T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

class CollageSettings {
  const CollageSettings({
    this.columns = 2,
    this.gutter = 24,
    this.backgroundColor = 0xFFFFFFFF,
  });

  final int columns;
  final double gutter;
  final int backgroundColor;

  CollageSettings copyWith({
    int? columns,
    double? gutter,
    int? backgroundColor,
  }) {
    return CollageSettings(
      columns: columns ?? this.columns,
      gutter: gutter ?? this.gutter,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'gutter': gutter,
        'backgroundColor': backgroundColor,
      };

  factory CollageSettings.fromJson(Map<String, dynamic> json) {
    return CollageSettings(
      columns: json['columns'] as int? ?? 2,
      gutter: (json['gutter'] as num?)?.toDouble() ?? 24,
      backgroundColor: json['backgroundColor'] as int? ?? 0xFFFFFFFF,
    );
  }
}

class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.assets,
    required this.exportSettings,
    this.metadata = const PhotoMetadata(),
    this.frameSettings = const FrameSettings(),
    this.collageSettings = const CollageSettings(),
  });

  final String id;
  final String name;
  final ProjectKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProjectAsset> assets;
  final ExportSettings exportSettings;
  final PhotoMetadata metadata;
  final FrameSettings frameSettings;
  final CollageSettings collageSettings;

  ProjectDocument copyWith({
    String? id,
    String? name,
    ProjectKind? kind,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProjectAsset>? assets,
    ExportSettings? exportSettings,
    PhotoMetadata? metadata,
    FrameSettings? frameSettings,
    CollageSettings? collageSettings,
  }) {
    return ProjectDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assets: assets ?? this.assets,
      exportSettings: exportSettings ?? this.exportSettings,
      metadata: metadata ?? this.metadata,
      frameSettings: frameSettings ?? this.frameSettings,
      collageSettings: collageSettings ?? this.collageSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'assets': assets.map((asset) => asset.toJson()).toList(),
        'exportSettings': exportSettings.toJson(),
        'metadata': metadata.toJson(),
        'frameSettings': frameSettings.toJson(),
        'collageSettings': collageSettings.toJson(),
      };

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    return ProjectDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: ProjectKind.values.byName(json['kind'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      assets: (json['assets'] as List<dynamic>? ?? const [])
          .map((asset) => ProjectAsset.fromJson(asset as Map<String, dynamic>))
          .toList(),
      exportSettings: ExportSettings.fromJson(
        json['exportSettings'] as Map<String, dynamic>,
      ),
      metadata: PhotoMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      frameSettings: FrameSettings.fromJson(
        json['frameSettings'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      collageSettings: CollageSettings.fromJson(
        json['collageSettings'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
    );
  }
}
