class PhotoMetadata {
  const PhotoMetadata({
    this.equipmentName = '',
    this.camera = '',
    this.lens = '',
    this.focalLength = '',
    this.aperture = '',
    this.shutterSpeed = '',
    this.iso = '',
  });

  final String equipmentName;
  final String camera;
  final String lens;
  final String focalLength;
  final String aperture;
  final String shutterSpeed;
  final String iso;

  bool get isEmpty =>
      equipmentName.isEmpty &&
      camera.isEmpty &&
      lens.isEmpty &&
      focalLength.isEmpty &&
      aperture.isEmpty &&
      shutterSpeed.isEmpty &&
      iso.isEmpty;

  List<String> get displayParts {
    return [
      if (camera.trim().isNotEmpty) camera.trim(),
      if (lens.trim().isNotEmpty) lens.trim(),
      if (focalLength.trim().isNotEmpty) focalLength.trim(),
      if (aperture.trim().isNotEmpty) aperture.trim(),
      if (shutterSpeed.trim().isNotEmpty) shutterSpeed.trim(),
      if (iso.trim().isNotEmpty) 'ISO ${iso.trim()}',
    ];
  }

  PhotoMetadata copyWith({
    String? equipmentName,
    String? camera,
    String? lens,
    String? focalLength,
    String? aperture,
    String? shutterSpeed,
    String? iso,
  }) {
    return PhotoMetadata(
      equipmentName: equipmentName ?? this.equipmentName,
      camera: camera ?? this.camera,
      lens: lens ?? this.lens,
      focalLength: focalLength ?? this.focalLength,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      iso: iso ?? this.iso,
    );
  }

  Map<String, dynamic> toJson() => {
        'equipmentName': equipmentName,
        'camera': camera,
        'lens': lens,
        'focalLength': focalLength,
        'aperture': aperture,
        'shutterSpeed': shutterSpeed,
        'iso': iso,
      };

  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      equipmentName: json['equipmentName'] as String? ?? '',
      camera: json['camera'] as String? ?? '',
      lens: json['lens'] as String? ?? '',
      focalLength: json['focalLength'] as String? ?? '',
      aperture: json['aperture'] as String? ?? '',
      shutterSpeed: json['shutterSpeed'] as String? ?? '',
      iso: json['iso'] as String? ?? '',
    );
  }
}
