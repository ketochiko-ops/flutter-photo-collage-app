import 'export_settings.dart';
import 'photo_metadata.dart';
import 'project_document.dart';

class AppPreferences {
  const AppPreferences({
    this.frameExportSettings = const ExportSettings(longSide: 4000),
    this.frameMetadata = const PhotoMetadata(),
    this.frameSettings = const FrameSettings(),
    this.collageExportSettings = const ExportSettings(longSide: 4000),
    this.collageSettings = const CollageSettings(),
  });

  final ExportSettings frameExportSettings;
  final PhotoMetadata frameMetadata;
  final FrameSettings frameSettings;
  final ExportSettings collageExportSettings;
  final CollageSettings collageSettings;

  AppPreferences copyWith({
    ExportSettings? frameExportSettings,
    PhotoMetadata? frameMetadata,
    FrameSettings? frameSettings,
    ExportSettings? collageExportSettings,
    CollageSettings? collageSettings,
  }) {
    return AppPreferences(
      frameExportSettings: frameExportSettings ?? this.frameExportSettings,
      frameMetadata: frameMetadata ?? this.frameMetadata,
      frameSettings: frameSettings ?? this.frameSettings,
      collageExportSettings:
          collageExportSettings ?? this.collageExportSettings,
      collageSettings: collageSettings ?? this.collageSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'frameExportSettings': frameExportSettings.toJson(),
        'frameMetadata': frameMetadata.toJson(),
        'frameSettings': frameSettings.toJson(),
        'collageExportSettings': collageExportSettings.toJson(),
        'collageSettings': collageSettings.toJson(),
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    const defaults = AppPreferences();
    return AppPreferences(
      frameExportSettings: json['frameExportSettings'] is Map<String, dynamic>
          ? ExportSettings.fromJson(
              json['frameExportSettings'] as Map<String, dynamic>,
            )
          : defaults.frameExportSettings,
      frameMetadata: json['frameMetadata'] is Map<String, dynamic>
          ? PhotoMetadata.fromJson(
              json['frameMetadata'] as Map<String, dynamic>,
            )
          : defaults.frameMetadata,
      frameSettings: json['frameSettings'] is Map<String, dynamic>
          ? FrameSettings.fromJson(
              json['frameSettings'] as Map<String, dynamic>,
            )
          : defaults.frameSettings,
      collageExportSettings:
          json['collageExportSettings'] is Map<String, dynamic>
              ? ExportSettings.fromJson(
                  json['collageExportSettings'] as Map<String, dynamic>,
                )
              : defaults.collageExportSettings,
      collageSettings: json['collageSettings'] is Map<String, dynamic>
          ? CollageSettings.fromJson(
              json['collageSettings'] as Map<String, dynamic>,
            )
          : defaults.collageSettings,
    );
  }
}
