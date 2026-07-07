import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/project_document.dart';

class ProjectRepository {
  const ProjectRepository({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  Future<ProjectDocument> save({
    required Directory projectDirectory,
    required ProjectDocument document,
    required List<File> sourceImages,
  }) async {
    await projectDirectory.create(recursive: true);
    final assetsDirectory = Directory(p.join(projectDirectory.path, 'assets'));
    await assetsDirectory.create(recursive: true);

    final assets = <ProjectAsset>[];
    for (final source in sourceImages) {
      final id = _uuid.v4();
      final extension = p.extension(source.path).toLowerCase();
      final fileName = '$id$extension';
      final copied = File(p.join(assetsDirectory.path, fileName));
      await source.copy(copied.path);
      assets.add(
        ProjectAsset(
          id: id,
          fileName: p.basename(source.path),
          relativePath: p.join('assets', fileName),
        ),
      );
    }

    final saved = document.copyWith(
      assets: assets,
      updatedAt: DateTime.now(),
    );
    await _writeDocument(projectDirectory, saved);
    return saved;
  }

  Future<ProjectDocument> updateDocument({
    required Directory projectDirectory,
    required ProjectDocument document,
  }) async {
    final updated = document.copyWith(updatedAt: DateTime.now());
    await _writeDocument(projectDirectory, updated);
    return updated;
  }

  Future<ProjectDocument> open(Directory projectDirectory) async {
    final file = File(p.join(projectDirectory.path, 'project.json'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ProjectDocument.fromJson(json);
  }

  List<File> resolveAssets({
    required Directory projectDirectory,
    required ProjectDocument document,
  }) {
    return document.assets
        .map((asset) => File(p.join(projectDirectory.path, asset.relativePath)))
        .toList();
  }

  Future<void> _writeDocument(
    Directory projectDirectory,
    ProjectDocument document,
  ) async {
    final file = File(p.join(projectDirectory.path, 'project.json'));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(document.toJson()));
  }
}
