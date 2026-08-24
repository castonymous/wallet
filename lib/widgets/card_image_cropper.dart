import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Picks a card image from camera/gallery and opens a simple manual cropper
/// locked to the standard ISO/IEC 7810 ID-1 card ratio (85.60 x 53.98 mm).
Future<File?> pickAndCropCardImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add card image',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                subtitle: const Text('Photograph the physical card'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Use a scan, photo, or custom design'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 94,
  );
  if (picked == null) return null;
  if (!context.mounted) return File(picked.path);

  return Navigator.of(context).push<File>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CardImageCropScreen(imageFile: File(picked.path)),
    ),
  );
}

class CardImageCropScreen extends StatefulWidget {
  final File imageFile;

  const CardImageCropScreen({super.key, required this.imageFile});

  @override
  State<CardImageCropScreen> createState() => _CardImageCropScreenState();
}

class _CardImageCropScreenState extends State<CardImageCropScreen> {
  static const double _cardRatio = 1.586;
  final GlobalKey _captureKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _saveCrop() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;

      final temp = await getTemporaryDirectory();
      final file = File(
        p.join(temp.path, 'card_crop_${DateTime.now().microsecondsSinceEpoch}.png'),
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (mounted) Navigator.pop(context, file);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust card image'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveCrop,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('USE'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Move and zoom until the card fills the frame. The result is saved in the standard 85.60 × 53.98 mm card ratio.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: _cardRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      key: _captureKey,
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return InteractiveViewer(
                              transformationController: _transformController,
                              minScale: 1,
                              maxScale: 6,
                              panEnabled: true,
                              scaleEnabled: true,
                              constrained: true,
                              boundaryMargin: const EdgeInsets.all(240),
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _transformController.value = Matrix4.identity(),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveCrop,
                  icon: const Icon(Icons.crop_rounded),
                  label: const Text('Use crop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
