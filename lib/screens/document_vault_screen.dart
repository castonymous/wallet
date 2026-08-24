import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wallet/models/db_helper.dart';
import 'package:wallet/models/provider_helper.dart';
import 'package:wallet/services/auto_backup_service.dart';
import 'package:wallet/services/vault_file_service.dart';
import 'package:wallet/widgets/encrypted_image_display.dart';
import 'package:wallet/widgets/full_screen_image_viewer.dart';

class DocumentVaultCard extends StatelessWidget {
  final DocumentItem item;
  final VoidCallback? onTap;
  const DocumentVaultCard({super.key, required this.item, this.onTap});

  IconData get _icon {
    if (item.isPdf) return Icons.picture_as_pdf_outlined;
    if (item.isDocx) return Icons.description_outlined;
    if (item.isImage) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark ? const Color(0xFF151515) : const Color(0xFFF7F7F7),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: .06)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 68,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.isImage
                    ? EncryptedImageDisplay(imagePath: item.encryptedPath, fit: BoxFit.cover, cacheWidth: 180)
                    : Icon(_icon, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text(
                      '${item.category} • ${item.fileType.toUpperCase()} • ${item.orientation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white45 : Colors.black45),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentEditScreen extends StatefulWidget {
  final DocumentItem? item;
  const DocumentEditScreen({super.key, this.item});

  @override
  State<DocumentEditScreen> createState() => _DocumentEditScreenState();
}

class _DocumentEditScreenState extends State<DocumentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _notes;
  String _orientation = 'portrait';
  File? _pickedFile;
  String? _pickedName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.title ?? '');
    _category = TextEditingController(text: widget.item?.category ?? 'Dokumen');
    _notes = TextEditingController(text: widget.item?.notes ?? '');
    _orientation = widget.item?.orientation ?? 'portrait';
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'docx'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    File? source;
    if (f.path != null) {
      source = File(f.path!);
    } else if (f.bytes != null) {
      final temp = await getTemporaryDirectory();
      source = File(p.join(temp.path, 'ois_pick_${DateTime.now().microsecondsSinceEpoch}_${f.name}'));
      await source.writeAsBytes(f.bytes!, flush: true);
    }
    if (source == null || !await source.exists()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File tidak dapat diakses.')));
      return;
    }
    setState(() {
      _pickedFile = source;
      _pickedName = f.name;
      if (_title.text.trim().isEmpty) _title.text = p.basenameWithoutExtension(f.name);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (widget.item == null && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih file dokumen dulu.')));
      return;
    }
    setState(() => _saving = true);
    try {
      var encryptedPath = widget.item?.encryptedPath;
      var fileName = widget.item?.fileName;
      var fileType = widget.item?.fileType;
      if (_pickedFile != null) {
        final name = _pickedName ?? p.basename(_pickedFile!.path);
        final saved = await VaultFileService.savePrivateCopy(_pickedFile!, preferredName: name);
        if (saved == null) throw Exception('Gagal menyimpan file');
        if (widget.item != null && widget.item!.encryptedPath != saved) {
          await DatabaseHelper.deleteImageFile(widget.item!.encryptedPath);
        }
        encryptedPath = saved;
        fileName = name;
        fileType = p.extension(name).replaceFirst('.', '').toLowerCase();
      }
      final item = DocumentItem(
        id: widget.item?.id,
        title: _title.text.trim(),
        category: _category.text.trim().isEmpty ? 'Dokumen' : _category.text.trim(),
        fileName: fileName!,
        fileType: fileType!,
        orientation: _orientation,
        encryptedPath: encryptedPath!,
        notes: _notes.text.trim(),
        orderIndex: widget.item?.orderIndex ?? 0,
      );
      if (widget.item == null) {
        await DocumentDatabaseHelper.instance.insert(item);
      } else {
        await DocumentDatabaseHelper.instance.update(item);
      }
      AutoBackupService.triggerBackup();
      if (mounted) {
        await context.read<DocumentProvider>().fetchItems();
        if (mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shownName = _pickedName ?? widget.item?.fileName;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Tambah Dokumen' : 'Edit Dokumen'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('SIMPAN'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(shownName == null ? 'Pilih gambar / PDF / DOCX' : 'Ganti file'),
            ),
            if (shownName != null) ...[
              const SizedBox(height: 8),
              Text(shownName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nama dokumen', hintText: 'Ijazah SMK, CV, Sertifikat, dll'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Isi nama dokumen' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Kategori', hintText: 'Lamaran Kerja, Pendidikan, Pajak...')),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _orientation,
              decoration: const InputDecoration(labelText: 'Tampilan kertas'),
              items: const [
                DropdownMenuItem(value: 'portrait', child: Text('A4 Portrait')),
                DropdownMenuItem(value: 'landscape', child: Text('A4 Landscape')),
              ],
              onChanged: (v) => setState(() => _orientation = v ?? 'portrait'),
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
            const SizedBox(height: 20),
            Text(
              'File disimpan terenkripsi di private storage Android. PNG/JPG bisa dilihat langsung, DOCX mendapat preview teks offline, dan file asli tetap bisa diekspor kembali.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_outline_rounded),
              label: const Text('SIMPAN TERENKRIPSI'),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentDetailScreen extends StatefulWidget {
  final DocumentItem item;
  const DocumentDetailScreen({super.key, required this.item});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  String? _docxPreview;
  Uint8List? _pdfPreview;
  bool _loadingPreview = false;

  Future<void> _loadDocx() async {
    if (_docxPreview != null || _loadingPreview) return;
    setState(() => _loadingPreview = true);
    final text = await VaultFileService.docxTextPreview(widget.item.encryptedPath);
    if (mounted) setState(() {
      _docxPreview = text;
      _loadingPreview = false;
    });
  }

  Future<void> _loadPdf() async {
    if (_pdfPreview != null || _loadingPreview) return;
    setState(() => _loadingPreview = true);
    try {
      final bytes = await VaultFileService.renderPdfFirstPage(widget.item.encryptedPath);
      if (mounted) setState(() => _pdfPreview = bytes);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _export() async {
    final result = await VaultFileService.exportEncryptedFile(
      encryptedPath: widget.item.encryptedPath,
      suggestedName: widget.item.fileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result == null ? 'Export dibatalkan.' : 'Salinan dokumen berhasil dibuat.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item.isDocx && _docxPreview == null && !_loadingPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocx());
    } else if (item.isPdf && _pdfPreview == null && !_loadingPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPdf());
    }
    final a4Ratio = item.orientation == 'landscape' ? 1.4142 : 1 / 1.4142;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share_rounded), tooltip: 'Export original', onPressed: _export),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DocumentEditScreen(item: item)));
              if (changed == true && context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item.isImage)
            Center(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePath: item.encryptedPath))),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560, maxWidth: 620),
                  child: AspectRatio(
                    aspectRatio: a4Ratio,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: EncryptedImageDisplay(imagePath: item.encryptedPath, fit: BoxFit.contain, cacheWidth: 1800),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (item.isDocx)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _loadingPreview
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  : SelectableText(_docxPreview ?? 'Preview belum tersedia.'),
            )
          else if (item.isPdf)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560, maxWidth: 620),
                child: AspectRatio(
                  aspectRatio: a4Ratio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: _loadingPreview
                        ? const Center(child: CircularProgressIndicator())
                        : _pdfPreview != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_pdfPreview!, fit: BoxFit.contain))
                            : const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Preview PDF tidak dapat dibuat. File asli tetap aman dan bisa diekspor.', textAlign: TextAlign.center))),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(item.fileName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          ListTile(leading: const Icon(Icons.category_outlined), title: const Text('Kategori'), subtitle: Text(item.category)),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('File'), subtitle: Text('${item.fileName} • ${item.fileType.toUpperCase()}')),
          ListTile(leading: const Icon(Icons.crop_portrait_rounded), title: const Text('Orientasi'), subtitle: Text('A4 ${item.orientation}')),
          if (item.notes.isNotEmpty) ListTile(leading: const Icon(Icons.notes_rounded), title: const Text('Catatan'), subtitle: Text(item.notes)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined), label: const Text('EXPORT FILE ASLI')),
        ],
      ),
    );
  }
}
