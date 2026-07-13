import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'models/export_settings.dart';
import 'models/photo_metadata.dart';
import 'models/project_document.dart';
import 'services/local_image_composer.dart';
import 'services/metadata_extractor.dart';
import 'services/project_repository.dart';
import 'services/system_font_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }
  runApp(const CollageApp());
}

String _nameTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return [
    value.year.toString().padLeft(4, '0'),
    twoDigits(value.month),
    twoDigits(value.day),
    '_',
    twoDigits(value.hour),
    twoDigits(value.minute),
    twoDigits(value.second),
  ].join();
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
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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
  final _fontService = const SystemFontService();
  final _uuid = const Uuid();

  File? _imageFile;
  Uint8List? _previewBytes;
  double? _sourceAspectRatio;
  int? _sourceLongSide;
  PhotoMetadata _metadata = const PhotoMetadata();
  ExportSettings _export = const ExportSettings(longSide: 4000);
  FrameSettings _frame = const FrameSettings();
  String _status = '';
  String? _previewError;
  bool _busy = false;
  bool _previewing = false;
  bool _loadingFonts = true;
  int _previewVersion = 0;
  Timer? _previewDebounce;
  List<String> _fontFamilies = const ['System'];

  final _controllers = <String, TextEditingController>{
    'camera': TextEditingController(),
    'lens': TextEditingController(),
    'focal': TextEditingController(),
    'aperture': TextEditingController(),
    'shutter': TextEditingController(),
    'iso': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadFontFamilies();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFontFamilies() async {
    final fonts = await _fontService.loadFontFamilies();
    if (!mounted) {
      return;
    }
    setState(() {
      _fontFamilies = _withCurrentFont(fonts);
      _loadingFonts = false;
    });
  }

  List<String> _withCurrentFont(List<String> fonts) {
    final current = _frame.textStyle.fontFamily.trim();
    if (current.isEmpty || fonts.contains(current)) {
      return fonts;
    }
    return [...fonts, current]..sort((a, b) {
        if (a == 'System') {
          return -1;
        }
        if (b == 'System') {
          return 1;
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
  }

  Future<void> _selectImage() async {
    final file = await openFile(acceptedTypeGroups: _imageTypes);
    if (file == null) {
      return;
    }
    final selected = File(file.path);
    PhotoMetadata extracted;
    double? sourceAspectRatio;
    int? sourceLongSide;
    try {
      extracted = await _metadataExtractor.extract(selected);
    } catch (_) {
      extracted = const PhotoMetadata();
    }
    try {
      final decoded = image_lib.decodeImage(await selected.readAsBytes());
      if (decoded != null && decoded.height > 0) {
        sourceAspectRatio = decoded.width / decoded.height;
        sourceLongSide = math.max(decoded.width, decoded.height);
      }
    } catch (_) {
      sourceAspectRatio = null;
      sourceLongSide = null;
    }
    setState(() {
      _imageFile = selected;
      _sourceAspectRatio = sourceAspectRatio;
      _sourceLongSide = sourceLongSide;
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
    final location = await getSaveLocation(
      suggestedName: 'framed_photo_${_nameTimestamp(DateTime.now())}.jpg',
    );
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
      final timestamp = _nameTimestamp(now);
      final document = ProjectDocument(
        id: _uuid.v4(),
        name: '${p.basenameWithoutExtension(imageFile.path)}_$timestamp',
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
        _previewError = 'Long side must be blank or greater than 0.';
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
      final previewExport = _previewExportSettings();
      final bytes = await _composer.composeFramedJpeg(
        imageFile: imageFile,
        metadata: _metadata,
        exportSettings: previewExport,
        frameSettings: _previewFrameSettings(previewExport),
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
    final requestedLongSide = _export.longSide;
    if (requestedLongSide != null) {
      return ExportSettings(
        longSide: math.min(requestedLongSide, maxPreviewSide),
        jpegQuality: 86,
      );
    }

    final sourceLongSide = _sourceLongSide;
    if (sourceLongSide == null || sourceLongSide <= maxPreviewSide) {
      return const ExportSettings(jpegQuality: 86);
    }
    return const ExportSettings(
      longSide: maxPreviewSide,
      jpegQuality: 86,
    );
  }

  FrameSettings _previewFrameSettings(ExportSettings previewExport) {
    final previewLongSide = previewExport.longSide;
    final outputLongSide = _export.longSide ?? _sourceLongSide;
    if (previewLongSide == null ||
        outputLongSide == null ||
        outputLongSide <= 0) {
      return _frame;
    }
    final scale = previewLongSide / outputLongSide;
    return _frame.copyWith(
      topFrameWidth: _frame.topFrameWidth * scale,
      rightFrameWidth: _frame.rightFrameWidth * scale,
      bottomFrameWidth: _frame.bottomFrameWidth * scale,
      leftFrameWidth: _frame.leftFrameWidth * scale,
      bottomPanelHeight: _frame.bottomFrameWidth * scale,
      imagePadding: _frame.imagePadding * scale,
      textStyle: _frame.textStyle.copyWith(
        fontSize: _frame.textStyle.fontSize * scale,
        detailFontSize: _frame.textStyle.detailFontSize * scale,
      ),
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
            aspectRatio: _sourceAspectRatio ?? _export.aspectRatio,
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
              FontFamilyDropdown(
                fonts: _fontFamilies,
                value: _frame.textStyle.fontFamily,
                loading: _loadingFonts,
                onChanged: (font) {
                  setState(() {
                    _frame = _frame.copyWith(
                      textStyle: _frame.textStyle.copyWith(
                        fontFamily: font,
                      ),
                    );
                  });
                  _schedulePreviewRefresh();
                },
              ),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ColorSwatchField(
                label: 'Frame Color',
                value: _frame.backgroundColor,
                onChanged: (color) {
                  setState(() {
                    _frame = _frame.copyWith(
                      backgroundColor: color,
                      borderColor: color,
                    );
                  });
                  _schedulePreviewRefresh();
                },
              ),
              ColorSwatchField(
                label: 'Text Color',
                value: _frame.textStyle.textColor,
                onChanged: (color) {
                  setState(() {
                    _frame = _frame.copyWith(
                      textStyle: _frame.textStyle.copyWith(textColor: color),
                    );
                  });
                  _schedulePreviewRefresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SegmentedField<TextPlacement>(
                label: 'Text Location',
                value: _frame.textPlacement,
                options: const {
                  TextPlacement.bottomFrame: 'Bottom Frame',
                  TextPlacement.topFrame: 'Top Frame',
                  TextPlacement.image: 'On Image',
                },
                onChanged: (value) {
                  setState(
                      () => _frame = _frame.copyWith(textPlacement: value));
                  _schedulePreviewRefresh();
                },
              ),
              SegmentedField<TextHorizontalAlignment>(
                label: 'Horizontal',
                value: _frame.textHorizontalAlignment,
                options: const {
                  TextHorizontalAlignment.left: 'Left',
                  TextHorizontalAlignment.center: 'Center',
                  TextHorizontalAlignment.right: 'Right',
                },
                onChanged: (value) {
                  setState(
                    () => _frame = _frame.copyWith(
                      textHorizontalAlignment: value,
                    ),
                  );
                  _schedulePreviewRefresh();
                },
              ),
              SegmentedField<TextVerticalAlignment>(
                label: 'Vertical',
                value: _frame.textVerticalAlignment,
                options: const {
                  TextVerticalAlignment.top: 'Top',
                  TextVerticalAlignment.center: 'Center',
                  TextVerticalAlignment.bottom: 'Bottom',
                },
                onChanged: (value) {
                  setState(
                    () => _frame = _frame.copyWith(
                      textVerticalAlignment: value,
                    ),
                  );
                  _schedulePreviewRefresh();
                },
              ),
            ],
          ),
          if (_frame.textPlacement != TextPlacement.image) ...[
            const SizedBox(height: 16),
            SliderField(
              label: 'Top Frame',
              value: _frame.topFrameWidth,
              min: 0,
              max: 600,
              onChanged: (value) {
                setState(() {
                  _frame = _frame.copyWith(topFrameWidth: value);
                });
                _schedulePreviewRefresh();
              },
            ),
            SliderField(
              label: 'Side Frame',
              value: (_frame.leftFrameWidth + _frame.rightFrameWidth) / 2,
              min: 0,
              max: 600,
              onChanged: (value) {
                setState(() {
                  _frame = _frame.copyWith(
                    leftFrameWidth: value,
                    rightFrameWidth: value,
                  );
                });
                _schedulePreviewRefresh();
              },
            ),
            SliderField(
              label: 'Bottom Frame',
              value: _frame.bottomFrameWidth,
              min: 0,
              max: 800,
              onChanged: (value) {
                setState(() {
                  _frame = _frame.copyWith(
                    bottomFrameWidth: value,
                    bottomPanelHeight: value,
                  );
                });
                _schedulePreviewRefresh();
              },
            ),
          ],
          SliderField(
            label: 'Camera/Lens Size',
            value: _frame.textStyle.fontSize,
            min: 18,
            max: 140,
            onChanged: (value) {
              setState(() {
                _frame = _frame.copyWith(
                  textStyle: _frame.textStyle.copyWith(fontSize: value),
                );
              });
              _schedulePreviewRefresh();
            },
          ),
          SliderField(
            label: 'Other Text Size',
            value: _frame.textStyle.detailFontSize,
            min: 18,
            max: 140,
            onChanged: (value) {
              setState(() {
                _frame = _frame.copyWith(
                  textStyle: _frame.textStyle.copyWith(
                    detailFontSize: value,
                  ),
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

class FontFamilyDropdown extends StatelessWidget {
  const FontFamilyDropdown({
    required this.fonts,
    required this.value,
    required this.loading,
    required this.onChanged,
    super.key,
  });

  final List<String> fonts;
  final String value;
  final bool loading;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentValue = fonts.contains(value) ? value : 'System';
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: currentValue,
        isExpanded: true,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: loading ? 'Loading Fonts' : 'Font Family',
        ),
        items: fonts
            .map(
              (font) => DropdownMenuItem<String>(
                value: font,
                child: Text(
                  font,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: font == 'System' ? null : font,
                  ),
                ),
              ),
            )
            .toList(),
        selectedItemBuilder: (context) => fonts
            .map(
              (font) => Text(
                font,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: font == 'System' ? null : font,
                ),
              ),
            )
            .toList(),
        onChanged: loading
            ? null
            : (font) {
                if (font != null) {
                  onChanged(font);
                }
              },
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
  Uint8List? _previewBytes;
  ExportSettings _export = const ExportSettings(longSide: 4000);
  CollageSettings _collage = const CollageSettings();
  String? _previewError;
  bool _busy = false;
  bool _previewing = false;
  int _previewVersion = 0;
  Timer? _previewDebounce;
  String _status = '';

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  Future<void> _selectImages() async {
    final files = await openFiles(acceptedTypeGroups: _imageTypes);
    setState(() {
      _imageFiles = files.map((file) => File(file.path)).toList();
      _status = '${_imageFiles.length}枚の画像を選択しました。';
    });
    await _refreshPreview();
  }

  Future<void> _removeImageAt(int index) async {
    if (index < 0 || index >= _imageFiles.length) {
      return;
    }
    _previewDebounce?.cancel();
    _previewVersion++;
    setState(() {
      _imageFiles = [
        ..._imageFiles.take(index),
        ..._imageFiles.skip(index + 1),
      ];
      _status = '${_imageFiles.length} selected images.';
      if (_imageFiles.isEmpty) {
        _previewBytes = null;
        _previewError = null;
        _previewing = false;
      }
    });
    if (_imageFiles.isNotEmpty) {
      await _refreshPreview();
    }
  }

  Future<void> _swapImageOrder(int fromIndex, int toIndex) async {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _imageFiles.length ||
        toIndex >= _imageFiles.length) {
      return;
    }
    _previewDebounce?.cancel();
    _previewVersion++;
    setState(() {
      final reordered = [..._imageFiles];
      final source = reordered[fromIndex];
      reordered[fromIndex] = reordered[toIndex];
      reordered[toIndex] = source;
      _imageFiles = reordered;
      _status = 'Image order updated.';
    });
    await _refreshPreview();
  }

  Future<void> _exportJpeg() async {
    if (_imageFiles.isEmpty) {
      setState(() => _status = '先に画像を選択してください。');
      return;
    }
    final location = await getSaveLocation(
      suggestedName: 'collage_${_nameTimestamp(DateTime.now())}.jpg',
    );
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
      final timestamp = _nameTimestamp(now);
      final document = ProjectDocument(
        id: _uuid.v4(),
        name: 'collage_$timestamp',
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

  void _schedulePreviewRefresh() {
    if (_imageFiles.isEmpty) {
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
    if (_imageFiles.isEmpty) {
      setState(() {
        _previewBytes = null;
        _previewError = null;
        _previewing = false;
      });
      return;
    }
    if (!_export.hasValidSize) {
      setState(() {
        _previewError = 'Long side must be blank or greater than 0.';
        _previewing = false;
      });
      return;
    }

    final version = ++_previewVersion;
    setState(() {
      _previewing = true;
      _previewError = null;
    });

    try {
      final bytes = await _composer.composeCollageJpeg(
        imageFiles: _imageFiles,
        exportSettings: _previewExportSettings(),
        collageSettings: _collage,
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
    final requestedLongSide = _export.longSide;
    return ExportSettings(
      longSide: requestedLongSide == null
          ? maxPreviewSide
          : math.min(requestedLongSide, maxPreviewSide),
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
          OutputImagePreview(
            bytes: _previewBytes,
            fileName: _imageFiles.isEmpty
                ? null
                : '${_imageFiles.length} selected images',
            aspectRatio: 1,
            loading: _previewing,
            error: _previewError,
          ),
          const SizedBox(height: 16),
          SelectedFilesPreview(
            files: _imageFiles,
            onRemove: (index) {
              unawaited(_removeImageAt(index));
            },
            onMove: (fromIndex, toIndex) {
              unawaited(_swapImageOrder(fromIndex, toIndex));
            },
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
            label: 'Columns',
            value: _collage.columns.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
            integer: true,
            onChanged: (value) {
              setState(() {
                _collage = _collage.copyWith(columns: value.round());
              });
              _schedulePreviewRefresh();
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
              _schedulePreviewRefresh();
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
    final location = await getSaveLocation(
      suggestedName: '${document.name}_${_nameTimestamp(DateTime.now())}.jpg',
    );
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
            Text(document.name,
                style: Theme.of(context).textTheme.headlineSmall),
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

  late final TextEditingController _longSide;
  late final TextEditingController _targetMb;

  @override
  void initState() {
    super.initState();
    _longSide = TextEditingController(
      text: widget.settings.longSide?.toString() ?? '',
    );
    _targetMb = TextEditingController(
      text: widget.settings.targetBytes == null
          ? ''
          : _formatMegabytes(widget.settings.targetBytes!),
    );
  }

  @override
  void dispose() {
    _longSide.dispose();
    _targetMb.dispose();
    super.dispose();
  }

  void _commit() {
    final longSide = int.tryParse(_longSide.text);
    final targetMb = double.tryParse(_targetMb.text);
    widget.onChanged(
      ExportSettings(
        longSide: longSide == null || longSide <= 0 ? null : longSide,
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
        _numberField(_longSide, 'Long Side'),
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

class SliderField extends StatefulWidget {
  const SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.integer = false,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool integer;
  final ValueChanged<double> onChanged;

  @override
  State<SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<SliderField> {
  late final TextEditingController _controller;
  late double _lastValue;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value;
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(SliderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _lastValue && widget.value != oldWidget.value) {
      _lastValue = widget.value;
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    if (widget.integer) {
      return value.round().toString();
    }
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _commitText(String text) {
    final parsed = double.tryParse(text);
    if (parsed == null) {
      _controller.text = _formatValue(widget.value);
      return;
    }
    final normalized = widget.integer ? parsed.roundToDouble() : parsed;
    final clamped = normalized.clamp(widget.min, widget.max).toDouble();
    _lastValue = clamped;
    _controller.text = _formatValue(clamped);
    widget.onChanged(clamped);
  }

  void _handleSliderChanged(double value) {
    _lastValue = value;
    _controller.text = _formatValue(value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(widget.label)),
        Expanded(
          child: Slider(
            value: widget.value.clamp(widget.min, widget.max).toDouble(),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: _formatValue(widget.value),
            onChanged: _handleSliderChanged,
          ),
        ),
        SizedBox(
          width: 88,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: _commitText,
            onEditingComplete: () {
              _commitText(_controller.text);
              FocusScope.of(context).unfocus();
            },
            onTapOutside: (_) {
              _commitText(_controller.text);
              FocusScope.of(context).unfocus();
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class SegmentedField<T> extends StatelessWidget {
  const SegmentedField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 112, child: Text(label)),
          SegmentedButton<T>(
            segments: options.entries
                .map(
                  (entry) => ButtonSegment<T>(
                    value: entry.key,
                    label: Text(entry.value),
                  ),
                )
                .toList(),
            selected: {value},
            onSelectionChanged: (selected) => onChanged(selected.single),
          ),
        ],
      ),
    );
  }
}

class ColorSwatchField extends StatefulWidget {
  const ColorSwatchField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const _colors = [
    0xFFFFFFFF,
    0xFFF5F5F5,
    0xFFE0E0E0,
    0xFF9E9E9E,
    0xFF212121,
    0xFF000000,
    0xFFB71C1C,
    0xFF1B5E20,
    0xFF0D47A1,
    0xFFFFC107,
  ];

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<ColorSwatchField> createState() => _ColorSwatchFieldState();
}

class _ColorSwatchFieldState extends State<ColorSwatchField> {
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _hexText(widget.value));
  }

  @override
  void didUpdateWidget(ColorSwatchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _hexController.text = _hexText(widget.value);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _hexText(int value) {
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _commitHex(String value) {
    final cleaned = value.replaceAll('#', '').trim();
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(cleaned)) {
      return;
    }
    final argb = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    widget.onChanged(int.parse(argb, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 520,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 92, child: Text(widget.label)),
          ...ColorSwatchField._colors.map(
            (colorValue) {
              final selected = colorValue == widget.value;
              final color = Color(colorValue);
              return Tooltip(
                message:
                    '#${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => widget.onChanged(colorValue),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
          SizedBox(
            width: 112,
            child: TextField(
              controller: _hexController,
              onSubmitted: _commitHex,
              onEditingComplete: () => _commitHex(_hexController.text),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'HEX',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
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
    final safeAspectRatio =
        aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const maxPreviewHeight = 520.0;
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : maxPreviewHeight * safeAspectRatio;
            final previewWidth =
                math.min(maxWidth, maxPreviewHeight * safeAspectRatio);
            final previewHeight = previewWidth / safeAspectRatio;

            return Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: ClipRect(
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
            );
          },
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
  const SelectedFilesPreview({
    required this.files,
    this.onRemove,
    this.onMove,
    super.key,
  });

  final List<File> files;
  final ValueChanged<int>? onRemove;
  final void Function(int fromIndex, int toIndex)? onMove;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No image selected')),
      );
    }
    final visibleFiles = files.take(12).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visibleFiles
          .asMap()
          .entries
          .map(
            (entry) {
              final index = entry.key;
              final file = entry.value;
              final canMove = onMove != null && files.length > 1;
              final thumbnail = _SelectedFileThumbnail(
                file: file,
                index: index,
                count: files.length,
                onRemove: onRemove,
                onMove: onMove,
              );

              return SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: canMove
                          ? DragTarget<int>(
                              onWillAccept: (fromIndex) =>
                                  fromIndex != null && fromIndex != index,
                              onAccept: (fromIndex) =>
                                  onMove!(fromIndex, index),
                              builder: (context, candidateData, rejectedData) {
                                final isHovering = candidateData.isNotEmpty;
                                return Draggable<int>(
                                  data: index,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 150,
                                      height: 150,
                                      child: Opacity(
                                        opacity: 0.86,
                                        child: thumbnail,
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.35,
                                    child: thumbnail,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: isHovering
                                          ? Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 3,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: thumbnail,
                                  ),
                                );
                              },
                            )
                          : thumbnail,
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
              );
            },
          )
          .toList(),
    );
  }
}

class _SelectedFileThumbnail extends StatelessWidget {
  const _SelectedFileThumbnail({
    required this.file,
    required this.index,
    required this.count,
    required this.onRemove,
    required this.onMove,
  });

  final File file;
  final int index;
  final int count;
  final ValueChanged<int>? onRemove;
  final void Function(int fromIndex, int toIndex)? onMove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
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
        if (onMove != null && count > 1) ...[
          Positioned(
            left: 6,
            top: 6,
            child: _thumbnailActionButton(
              tooltip: 'Move previous',
              icon: Icons.chevron_left,
              onPressed:
                  index == 0 ? null : () => onMove!(index, index - 1),
            ),
          ),
          Positioned(
            left: 42,
            top: 6,
            child: _thumbnailActionButton(
              tooltip: 'Move next',
              icon: Icons.chevron_right,
              onPressed: index >= count - 1
                  ? null
                  : () => onMove!(index, index + 1),
            ),
          ),
        ],
        if (onRemove != null)
          Positioned(
            top: 6,
            right: 6,
            child: _thumbnailActionButton(
              tooltip: 'Remove image',
              icon: Icons.close,
              onPressed: () => onRemove!(index),
            ),
          ),
      ],
    );
  }

  Widget _thumbnailActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 18,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(32),
          minimumSize: const Size.square(32),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
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
