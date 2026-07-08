import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'models/export_settings.dart';
import 'models/photo_metadata.dart';
import 'models/project_document.dart';
import 'services/local_image_composer.dart';
import 'services/metadata_extractor.dart';
import 'services/project_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }
  runApp(const CollageApp());
}

class CollageApp extends StatelessWidget {
  const CollageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Photo Collage Studio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF306C7A)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FrameEditorPage(),
      const CollageEditorPage(),
      const ProjectOpenPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Collage Studio'),
        actions: const [Padding(padding: EdgeInsets.all(8), child: AdSlot())],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.filter_frames_outlined),
            selectedIcon: Icon(Icons.filter_frames),
            label: 'Frame',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Collage',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: 'Project',
          ),
        ],
      ),
    );
  }
}

class FrameEditorPage extends StatefulWidget {
  const FrameEditorPage({super.key});

  @override
  State<FrameEditorPage> createState() => _FrameEditorPageState();
}

class _FrameEditorPageState extends State<FrameEditorPage> {
  final _composer = LocalImageComposer();
  final _metadataExtractor = const MetadataExtractor();
  final _repository = const ProjectRepository();
  final _uuid = const Uuid();

  File? _imageFile;
  Uint8List? _previewBytes;
  PhotoMetadata _metadata = const PhotoMetadata();
  ExportSettings _export = const ExportSettings(width: 3000, height: 2000);
  FrameSettings _frame = const FrameSettings();
  String _status = '';
  String? _previewError;
  bool _busy = false;
  bool _previewing = false;
  int _previewVersion = 0;
  Timer? _previewDebounce;

  final _controllers = <String, TextEditingController>{
    'camera': TextEditingController(),
    'lens': TextEditingController(),
    'focal': TextEditingController(),
    'aperture': TextEditingController(),
    'shutter': TextEditingController(),
    'iso': TextEditingController(),
    'font': TextEditingController(text: 'System'),
  };

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectImage() async {
    final file = await openFile(acceptedTypeGroups: _imageTypes);
    if (file == null) {
      return;
    }
    final selected = File(file.path);
    PhotoMetadata extracted;
    try {
      extracted = await _metadataExtractor.extract(selected);
    } catch (_) {
      extracted = const PhotoMetadata();
    }
    setState(() {
      _imageFile = selected;
      _metadata = extracted;
      _syncControllersFromMetadata();
      _status = '画像を読み込みました: ${p.basename(selected.path)}';
    });
    await _refreshPreview();
  }

  Future<void> _exportJpeg() async {
    final imageFile = _imageFile;
    if (imageFile == null) {
      setState(() => _status = '先に画像を選択してください。');
      return;
    }
    final location = await getSaveLocation(suggestedName: 'framed_photo.jpg');
    if (location == null) {
      return;
    }
    await _runBusy(() async {
      _readMetadataFromControllers();
      final jpeg = await _composer.composeFramedJpeg(
        imageFile: imageFile,
        metadata: _metadata,
        exportSettings: _export,
        frameSettings: _frame,
      );
      await _composer.writeJpeg(bytes: jpeg, destination: File(location.path));
      setState(() => _status = 'JPEGを書き出しました: ${location.path}');
    });
  }

  Future<void> _saveProject() async {
    final imageFile = _imageFile;
    if (imageFile == null) {
      setState(() => _status = '保存する画像を選択してください。');
      return;
    }
    final directory = await getDirectoryPath(confirmButtonText: 'Save Project');
    if (directory == null) {
      return;
    }
    await _runBusy(() async {
      _readMetadataFromControllers();
      final now = DateTime.now();
      final document = ProjectDocument(
        id: _uuid.v4(),
        name: p.basenameWithoutExtension(imageFile.path),
        kind: ProjectKind.frame,
        createdAt: now,
        updatedAt: now,
        assets: const [],
        exportSettings: _export,
        metadata: _metadata,
        frameSettings: _frame,
      );
      await _repository.save(
        projectDirectory: Directory(directory),
        document: document,
        sourceImages: [imageFile],
      );
      setState(() => _status = 'プロジェクトを保存しました: $directory');
    });
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      setState(() => _status = 'エラー: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _syncControllersFromMetadata() {
    _controllers['camera']!.text = _metadata.camera;
    _controllers['lens']!.text = _metadata.lens;
    _controllers['focal']!.text = _metadata.focalLength;
    _controllers['aperture']!.text = _metadata.aperture;
    _controllers['shutter']!.text = _metadata.shutterSpeed;
    _controllers['iso']!.text = _metadata.iso;
    _controllers['font']!.text = _frame.textStyle.fontFamily;
  }

  void _readMetadataFromControllers() {
    _metadata = PhotoMetadata(
      camera: _controllers['camera']!.text,
      lens: _controllers['lens']!.text,
      focalLength: _controllers['focal']!.text,
      aperture: _controllers['aperture']!.text,
      shutterSpeed: _controllers['shutter']!.text,
      iso: _controllers['iso']!.text,
    );
    _frame = _frame.copyWith(
      textStyle: _frame.textStyle.copyWith(
        fontFamily: _controllers['font']!.text.trim().isEmpty
            ? 'System'
            : _controllers['font']!.text.trim(),
      ),
    );
  }

  void _schedulePreviewRefresh() {
    if (_imageFile == null) {
      return;
    }
    _previewDebounce?.cancel();
    _previewDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        if (mounted) {
          _refreshPreview();
        }
      },
    );
  }

  Future<void> _refreshPreview() async {
    final imageFile = _imageFile;
    if (imageFile == null) {
      setState(() {
        _previewBytes = null;
        _previewError = null;
        _previewing = false;
      });
      return;
    }
    if (!_export.hasValidSize) {
      setState(() {
        _previewError = 'Preview requires a positive width and height.';
        _previewing = false;
      });
      return;
    }

    _readMetadataFromControllers();
    final version = ++_previewVersion;
    setState(() {
      _previewing = true;
      _previewError = null;
    });

    try {
      final bytes = await _composer.composeFramedJpeg(
        imageFile: imageFile,
        metadata: _metadata,
        exportSettings: _previewExportSettings(),
        frameSettings: _frame,
      );
      if (!mounted || version != _previewVersion) {
        return;
      }
      setState(() => _previewBytes = bytes);
    } catch (error) {
      if (!mounted || version != _previewVersion) {
        return;
      }
      setState(() => _previewError = error.toString());
    } finally {
      if (mounted && version == _previewVersion) {
        setState(() => _previewing = false);
      }
    }
  }

  ExportSettings _previewExportSettings() {
    const maxPreviewSide = 1200;
    final longestSide = math.max(_export.width, _export.height);
    if (longestSide <= maxPreviewSide) {
      return ExportSettings(
        width: _export.width,
        height: _export.height,
        jpegQuality: 86,
      );
    }
    final scale = maxPreviewSide / longestSide;
    return ExportSettings(
      width: math.max(1, (_export.width * scale).round()),
      height: math.max(1, (_export.height * scale).round()),
      jpegQuality: 86,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      busy: _busy,
      status: _status,
      actions: [
        FilledButton.icon(
          onPressed: _busy ? null : _selectImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Select Image'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _exportJpeg,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('Export JPEG'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _saveProject,
          icon: const Icon(Icons.folder_copy_outlined),
          label: const Text('Save Project'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutputImagePreview(
            bytes: _previewBytes,
            fileName: _imageFile == null ? null : p.basename(_imageFile!.path),
            aspectRatio: _export.aspectRatio,
            loading: _previewing,
            error: _previewError,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _field('camera', 'Camera', onChanged: _schedulePreviewRefresh),
              _field('lens', 'Lens', onChanged: _schedulePreviewRefresh),
              _field(
                'focal',
                'Focal Length',
                onChanged: _schedulePreviewRefresh,
              ),
              _field(
                'aperture',
                'Aperture',
                onChanged: _schedulePreviewRefresh,
              ),
              _field(
                'shutter',
                'Shutter',
                onChanged: _schedulePreviewRefresh,
              ),
              _field('iso', 'ISO', onChanged: _schedulePreviewRefresh),
              _field('font', 'Font Family', onChanged: _schedulePreviewRefresh),
            ],
          ),
          const SizedBox(height: 16),
          ExportControls(
            settings: _export,
            onChanged: (settings) {
              setState(() => _export = settings);
              _schedulePreviewRefresh();
            },
          ),
          SliderField(
            label: 'Font Size',
            value: _frame.textStyle.fontSize,
            min: 18,
            max: 96,
            onChanged: (value) {
              setState(() {
                _frame = _frame.copyWith(
                  textStyle: _frame.textStyle.copyWith(fontSize: value),
                );
              });
              _schedulePreviewRefresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _field(String key, String label, {VoidCallback? onChanged}) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: _controllers[key],
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}

class CollageEditorPage extends StatefulWidget {
  const CollageEditorPage({super.key});

  @override
  State<CollageEditorPage> createState() => _CollageEditorPageState();
}

class _CollageEditorPageState extends State<CollageEditorPage> {
  final _composer = LocalImageComposer();
  final _repository = const ProjectRepository();
  final _uuid = const Uuid();

  List<File> _imageFiles = const [];
  ExportSettings _export = const ExportSettings(width: 3000, height: 3000);
  CollageSettings _collage = const CollageSettings();
  bool _busy = false;
  String _status = '';

  Future<void> _selectImages() async {
    final files = await openFiles(acceptedTypeGroups: _imageTypes);
    setState(() {
      _imageFiles = files.map((file) => File(file.path)).toList();
      _status = '${_imageFiles.length}枚の画像を選択しました。';
    });
  }

  Future<void> _exportJpeg() async {
    if (_imageFiles.isEmpty) {
      setState(() => _status = '先に画像を選択してください。');
      return;
    }
    final location = await getSaveLocation(suggestedName: 'collage.jpg');
    if (location == null) {
      return;
    }
    await _runBusy(() async {
      final jpeg = await _composer.composeCollageJpeg(
        imageFiles: _imageFiles,
        exportSettings: _export,
        collageSettings: _collage,
      );
      await _composer.writeJpeg(bytes: jpeg, destination: File(location.path));
      setState(() => _status = 'JPEGを書き出しました: ${location.path}');
    });
  }

  Future<void> _saveProject() async {
    if (_imageFiles.isEmpty) {
      setState(() => _status = '保存する画像を選択してください。');
      return;
    }
    final directory = await getDirectoryPath(confirmButtonText: 'Save Project');
    if (directory == null) {
      return;
    }
    await _runBusy(() async {
      final now = DateTime.now();
      final document = ProjectDocument(
        id: _uuid.v4(),
        name: 'collage_${now.millisecondsSinceEpoch}',
        kind: ProjectKind.collage,
        createdAt: now,
        updatedAt: now,
        assets: const [],
        exportSettings: _export,
        collageSettings: _collage,
      );
      await _repository.save(
        projectDirectory: Directory(directory),
        document: document,
        sourceImages: _imageFiles,
      );
      setState(() => _status = 'プロジェクトを保存しました: $directory');
    });
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      setState(() => _status = 'エラー: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      busy: _busy,
      status: _status,
      actions: [
        FilledButton.icon(
          onPressed: _busy ? null : _selectImages,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Select Images'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _exportJpeg,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('Export JPEG'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _saveProject,
          icon: const Icon(Icons.folder_copy_outlined),
          label: const Text('Save Project'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectedFilesPreview(files: _imageFiles),
          const SizedBox(height: 16),
          ExportControls(
            settings: _export,
            onChanged: (settings) => setState(() => _export = settings),
          ),
          SliderField(
            label: 'Columns',
            value: _collage.columns.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
            onChanged: (value) {
              setState(() {
                _collage = _collage.copyWith(columns: value.round());
              });
            },
          ),
          SliderField(
            label: 'Gutter',
            value: _collage.gutter,
            min: 0,
            max: 80,
            onChanged: (value) {
              setState(() {
                _collage = _collage.copyWith(gutter: value);
              });
            },
          ),
        ],
      ),
    );
  }
}

class ProjectOpenPage extends StatefulWidget {
  const ProjectOpenPage({super.key});

  @override
  State<ProjectOpenPage> createState() => _ProjectOpenPageState();
}

class _ProjectOpenPageState extends State<ProjectOpenPage> {
  final _repository = const ProjectRepository();
  final _composer = LocalImageComposer();
  ProjectDocument? _document;
  Directory? _directory;
  bool _busy = false;
  String _status = '';

  Future<void> _openProject() async {
    final directory = await getDirectoryPath(confirmButtonText: 'Open Project');
    if (directory == null) {
      return;
    }
    try {
      final document = await _repository.open(Directory(directory));
      setState(() {
        _document = document;
        _directory = Directory(directory);
        _status = 'プロジェクトを開きました。';
      });
    } catch (error) {
      setState(() => _status = 'エラー: $error');
    }
  }

  Future<void> _exportOpenedProject() async {
    final document = _document;
    final directory = _directory;
    if (document == null || directory == null) {
      setState(() => _status = '先にプロジェクトを開いてください。');
      return;
    }
    final location = await getSaveLocation(suggestedName: '${document.name}.jpg');
    if (location == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final files = _repository.resolveAssets(
        projectDirectory: directory,
        document: document,
      );
      final bytes = switch (document.kind) {
        ProjectKind.frame => await _composer.composeFramedJpeg(
            imageFile: files.first,
            metadata: document.metadata,
            exportSettings: document.exportSettings,
            frameSettings: document.frameSettings,
          ),
        ProjectKind.collage => await _composer.composeCollageJpeg(
            imageFiles: files,
            exportSettings: document.exportSettings,
            collageSettings: document.collageSettings,
          ),
      };
      await _composer.writeJpeg(bytes: bytes, destination: File(location.path));
      setState(() => _status = 'JPEGを書き出しました: ${location.path}');
    } catch (error) {
      setState(() => _status = 'エラー: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final files = document == null || _directory == null
        ? <File>[]
        : _repository.resolveAssets(
            projectDirectory: _directory!,
            document: document,
          );

    return EditorScaffold(
      busy: _busy,
      status: _status,
      actions: [
        FilledButton.icon(
          onPressed: _busy ? null : _openProject,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Open Project'),
        ),
        FilledButton.icon(
          onPressed: _busy || document == null ? null : _exportOpenedProject,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('Export JPEG'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (document != null) ...[
            Text(document.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Type: ${document.kind.name}'),
            Text('Updated: ${document.updatedAt}'),
            const SizedBox(height: 16),
          ],
          SelectedFilesPreview(files: files),
        ],
      ),
    );
  }
}

class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    required this.child,
    required this.actions,
    required this.busy,
    required this.status,
    super.key,
  });

  final Widget child;
  final List<Widget> actions;
  final bool busy;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(spacing: 8, runSpacing: 8, children: actions),
                ),
                if (busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(status),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class ExportControls extends StatefulWidget {
  const ExportControls({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final ExportSettings settings;
  final ValueChanged<ExportSettings> onChanged;

  @override
  State<ExportControls> createState() => _ExportControlsState();
}

class _ExportControlsState extends State<ExportControls> {
  static const _bytesPerMegabyte = 1024 * 1024;

  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _targetMb;

  @override
  void initState() {
    super.initState();
    _width = TextEditingController(text: widget.settings.width.toString());
    _height = TextEditingController(text: widget.settings.height.toString());
    _targetMb = TextEditingController(
      text: widget.settings.targetBytes == null
          ? ''
          : _formatMegabytes(widget.settings.targetBytes!),
    );
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _targetMb.dispose();
    super.dispose();
  }

  void _commit() {
    final width = int.tryParse(_width.text) ?? widget.settings.width;
    final height = int.tryParse(_height.text) ?? widget.settings.height;
    final targetMb = double.tryParse(_targetMb.text);
    widget.onChanged(
      ExportSettings(
        width: width,
        height: height,
        targetBytes: targetMb == null || targetMb <= 0
            ? null
            : (targetMb * _bytesPerMegabyte).round(),
        jpegQuality: widget.settings.jpegQuality,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _numberField(_width, 'Width'),
        _numberField(_height, 'Height'),
        _numberField(_targetMb, 'Target MB', decimal: true),
      ],
    );
  }

  String _formatMegabytes(int bytes) {
    final megabytes = bytes / _bytesPerMegabyte;
    if (megabytes == megabytes.roundToDouble()) {
      return megabytes.toStringAsFixed(0);
    }
    return megabytes.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: (_) => _commit(),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}

class SliderField extends StatelessWidget {
  const SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 64, child: Text(value.round().toString())),
      ],
    );
  }
}

class OutputImagePreview extends StatelessWidget {
  const OutputImagePreview({
    required this.bytes,
    required this.aspectRatio,
    required this.loading,
    this.fileName,
    this.error,
    super.key,
  });

  final Uint8List? bytes;
  final double aspectRatio;
  final bool loading;
  final String? fileName;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final imageBytes = bytes;
    final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: AspectRatio(
            aspectRatio: safeAspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes == null)
                      const Center(child: Text('No image selected'))
                    else
                      Image.memory(imageBytes, fit: BoxFit.contain),
                    if (loading)
                      const ColoredBox(
                        color: Color(0x66FFFFFF),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (fileName != null) ...[
          const SizedBox(height: 6),
          Text(
            fileName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class SelectedFilesPreview extends StatelessWidget {
  const SelectedFilesPreview({required this.files, super.key});

  final List<File> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No image selected')),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: files
          .take(12)
          .map(
            (file) => SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFE8ECEF),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.basename(file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class AdSlot extends StatefulWidget {
  const AdSlot({super.key});

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  BannerAd? _bannerAd;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/6300978111'
            : 'ca-app-pub-3940256099942544/2934735716',
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _loaded = true),
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
        request: const AdRequest(),
      )..load();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null || !_loaded) {
      return const SizedBox(width: 320, height: 50);
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

const _imageTypes = [
  XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'heic'],
  ),
];
