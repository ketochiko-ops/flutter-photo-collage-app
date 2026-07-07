import 'dart:io';

import 'package:exif/exif.dart';

import '../models/photo_metadata.dart';

class MetadataExtractor {
  const MetadataExtractor();

  Future<PhotoMetadata> extract(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final tags = await readExifFromBytes(bytes);

    final make = _tag(tags, 'Image Make');
    final model = _tag(tags, 'Image Model');
    final lens = _tag(tags, 'EXIF LensModel');
    final focalLength = _tag(tags, 'EXIF FocalLength');
    final aperture = _tag(tags, 'EXIF FNumber');
    final shutter = _tag(tags, 'EXIF ExposureTime');
    final iso = _tag(tags, 'EXIF ISOSpeedRatings').ifEmpty(
      _tag(tags, 'EXIF PhotographicSensitivity'),
    );

    return PhotoMetadata(
      camera: [make, model].where((value) => value.isNotEmpty).join(' '),
      lens: lens,
      focalLength: _normalizeFocalLength(focalLength),
      aperture: _normalizeAperture(aperture),
      shutterSpeed: shutter,
      iso: iso.replaceAll(RegExp(r'[^0-9]'), ''),
    );
  }

  String _tag(Map<String, IfdTag> tags, String key) {
    return tags[key]?.printable.trim() ?? '';
  }

  String _normalizeFocalLength(String value) {
    if (value.isEmpty || value.toLowerCase().contains('mm')) {
      return value;
    }
    return '$value mm';
  }

  String _normalizeAperture(String value) {
    if (value.isEmpty || value.toLowerCase().startsWith('f')) {
      return value;
    }
    return 'f/$value';
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
