import 'dart:io';

class SystemFontService {
  const SystemFontService();

  Future<List<String>> loadFontFamilies() async {
    final fonts = <String>{'System'};
    if (Platform.isWindows) {
      fonts.addAll(await _loadWindowsFonts());
    } else {
      fonts.addAll(await _loadFontDirectoryNames(_fontDirectories()));
    }

    final sorted = fonts.where((font) => font.trim().isNotEmpty).toList()
      ..sort((a, b) {
        if (a == 'System') {
          return -1;
        }
        if (b == 'System') {
          return 1;
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return sorted;
  }

  Future<Iterable<String>> _loadWindowsFonts() async {
    final fonts = <String>{};
    const registryKeys = [
      r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      r'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
    ];

    for (final key in registryKeys) {
      try {
        final result = await Process.run('reg', ['query', key]);
        if (result.exitCode != 0) {
          continue;
        }
        fonts.addAll(_parseWindowsFontRegistry(result.stdout.toString()));
      } catch (_) {
        // Fall back to the Fonts directory below.
      }
    }

    if (fonts.isEmpty) {
      fonts.addAll(
        await _loadFontDirectoryNames([r'C:\Windows\Fonts']),
      );
    }
    return fonts;
  }

  Iterable<String> _parseWindowsFontRegistry(String output) {
    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.contains('REG_'))
        .map((line) => line.split(RegExp(r'\s{2,}')).first)
        .map(_normalizeWindowsFontName)
        .where((name) => name.isNotEmpty);
  }

  String _normalizeWindowsFontName(String name) {
    return name
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _fontDirectories() {
    if (Platform.isMacOS) {
      return const [
        '/System/Library/Fonts',
        '/Library/Fonts',
      ];
    }
    if (Platform.isLinux) {
      return const [
        '/usr/share/fonts',
        '/usr/local/share/fonts',
      ];
    }
    return const [];
  }

  Future<Iterable<String>> _loadFontDirectoryNames(
    Iterable<String> directories,
  ) async {
    final fonts = <String>{};
    const fontExtensions = {'.ttf', '.ttc', '.otf'};
    for (final path in directories) {
      final directory = Directory(path);
      if (!await directory.exists()) {
        continue;
      }
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final fileName = entity.uri.pathSegments.last;
        final dot = fileName.lastIndexOf('.');
        if (dot <= 0) {
          continue;
        }
        final extension = fileName.substring(dot).toLowerCase();
        if (fontExtensions.contains(extension)) {
          fonts.add(fileName.substring(0, dot).replaceAll('_', ' ').trim());
        }
      }
    }
    return fonts;
  }
}
