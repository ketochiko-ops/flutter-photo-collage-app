import 'dart:io';

import 'package:flutter_photo_collage_app/models/export_settings.dart';
import 'package:flutter_photo_collage_app/models/project_document.dart';
import 'package:flutter_photo_collage_app/services/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('saves project json and copies source images into assets folder', () async {
    final temp = await Directory.systemTemp.createTemp('photo_collage_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final source = File(p.join(temp.path, 'source.jpg'));
    await source.writeAsBytes([1, 2, 3, 4]);

    final projectDirectory = Directory(p.join(temp.path, 'project'));
    final now = DateTime.utc(2026, 7, 7);
    final document = ProjectDocument(
      id: 'project',
      name: 'project',
      kind: ProjectKind.collage,
      createdAt: now,
      updatedAt: now,
      assets: const [],
      exportSettings: const ExportSettings(width: 1000, height: 1000),
    );

    final saved = await const ProjectRepository().save(
      projectDirectory: projectDirectory,
      document: document,
      sourceImages: [source],
    );

    expect(File(p.join(projectDirectory.path, 'project.json')).existsSync(), isTrue);
    expect(saved.assets, hasLength(1));
    expect(
      File(p.join(projectDirectory.path, saved.assets.single.relativePath))
          .existsSync(),
      isTrue,
    );

    final opened = await const ProjectRepository().open(projectDirectory);
    expect(opened.name, 'project');
    expect(opened.assets.single.fileName, 'source.jpg');
  });
}
