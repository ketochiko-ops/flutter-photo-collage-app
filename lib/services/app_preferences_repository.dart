import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_preferences.dart';

class AppPreferencesRepository {
  const AppPreferencesRepository();

  Future<AppPreferences> load() async {
    final file = await _preferencesFile();
    if (!await file.exists()) {
      return const AppPreferences();
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) {
        return const AppPreferences();
      }
      return AppPreferences.fromJson(json);
    } catch (_) {
      return const AppPreferences();
    }
  }

  Future<void> save(AppPreferences preferences) async {
    final file = await _preferencesFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(preferences.toJson()));
  }

  Future<File> _preferencesFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'defaults.json'));
  }
}
