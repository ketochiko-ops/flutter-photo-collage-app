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
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final withoutUnit = trimmed.replaceAll(
      RegExp(r'\s*mm$', caseSensitive: false),
      '',
    );
    final number = _parseNumber(withoutUnit);
    if (number == null) {
      return trimmed.toLowerCase().contains('mm') ? trimmed : '$trimmed mm';
    }
    return '${_formatNumber(number)} mm';
  }

  String _normalizeAperture(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final withoutPrefix = trimmed.replaceFirst(
      RegExp(r'^f/?', caseSensitive: false),
      '',
    );
    final number = _parseNumber(withoutPrefix);
    if (number == null) {
      return trimmed.toLowerCase().startsWith('f') ? trimmed : 'f/$trimmed';
    }
    return 'f/${_formatNumber(number)}';
  }

  double? _parseNumber(String value) {
    final trimmed = value.trim();
    final fractionMatch = RegExp(r'^(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)$')
        .firstMatch(trimmed);
    if (fractionMatch != null) {
      final numerator = double.tryParse(fractionMatch.group(1)!);
      final denominator = double.tryParse(fractionMatch.group(2)!);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }
    return double.tryParse(trimmed);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
