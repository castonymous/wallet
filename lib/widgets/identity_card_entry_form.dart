import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet/models/db_helper.dart';
import 'package:wallet/models/provider_helper.dart';
import 'package:wallet/services/auto_backup_service.dart';
import 'package:wallet/services/image_service.dart';
import 'package:wallet/widgets/card_appearance_selector.dart';
import 'package:wallet/widgets/card_image_cropper.dart';
import 'package:wallet/widgets/color_picker.dart';
import 'package:wallet/widgets/encrypted_image_display.dart';
import 'package:wallet/widgets/identity_card_widget.dart';

class IdentityCardEntryForm extends StatefulWidget {
  final IdentityCard? existingCard;

  const IdentityCardEntryForm({super.key, this.existingCard});

  @override
  State<IdentityCardEntryForm> createState() => IdentityCardEntryFormState();
}

class IdentityCardEntryFormState extends State<IdentityCardEntryForm> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _cardTypeController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Identity');

  String? _frontImagePath;
  String? _backImagePath;
  String _selectedColor = 'obsidian';
  String _displayMode = 'photo';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCard;
    if (existing != null) {
      _nameController.text = existing.name;
      _valueController.text = existing.value;
      _cardTypeController.text = existing.cardType;
      _categoryController.text = existing.category ?? 'Identity';
      _frontImagePath = existing.frontImagePath;
      _backImagePath = existing.backImagePath;
      _selectedColor = existing.color ?? 'obsidian';
      _displayMode = existing.displayMode;
    }
    _nameController.addListener(_refreshPreview);
    _valueController.addListener(_refreshPreview);
    _cardTypeController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _valueController.removeListener(_refreshPreview);
    _cardTypeController.removeListener(_refreshPreview);
    _nameController.dispose();
    _valueController.dispose();
    _cardTypeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    final cropped = await pickAndCropCardImage(context);
    if (cropped == null) return;

    final encryptedPath = await saveImageToAppDirectory(cropped);
    if (encryptedPath == null || !mounted) return;

    setState(() {
      if (isFront) {
        _frontImagePath = encryptedPath;
      } else {
        _backImagePath = encryptedPath;
      }
      if (_displayMode == 'generated') _displayMode = 'photo';
    });
  }

  Future<void> _saveData() async {
    final name = _nameController.text.trim();
    final value = _valueController.text.trim();
    final cardType = _cardTypeController.text.trim();

    if (cardType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card label is required.')),
      );
      return;
    }

    if (_displayMode != 'generated' &&
        (_frontImagePath == null || _frontImagePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a front image or switch the appearance to Simple.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final card = IdentityCard(
        id: widget.existingCard?.id,
        name: name.isEmpty ? cardType : name,
        value: value,
        cardType: cardType,
        category: _categoryController.text.trim(),
        frontImagePath: _frontImagePath,
        backImagePath: _backImagePath,
        color: _selectedColor,
        displayMode: _displayMode,
        orderIndex: widget.existingCard?.orderIndex ?? 0,
      );

      if (widget.existingCard != null) {
        await IdentityDatabaseHelper.instance.updateIdentity(card);
        if (widget.existingCard!.frontImagePath != _frontImagePath) {
          await DatabaseHelper.deleteImageFile(widget.existingCard!.frontImagePath);
        }
        if (widget.existingCard!.backImagePath != _backImagePath) {
          await DatabaseHelper.deleteImageFile(widget.existingCard!.backImagePath);
        }
      } else {
        await IdentityDatabaseHelper.instance.insertIdentity(card);
      }
      AutoBackupService.triggerBackup();

      if (mounted) {
        context.read<IdentityProvider>().fetchIdentities();
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void save() => _saveData();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final preview = IdentityCard(
      name: _nameController.text.isEmpty ? 'NAME' : _nameController.text,
      value: _valueController.text.isEmpty ? 'ID NUMBER' : _valueController.text,
      cardType: _cardTypeController.text.isEmpty
          ? 'IDENTITY CARD'
          : _cardTypeController.text,
      category: _categoryController.text,
      frontImagePath: _frontImagePath,
      backImagePath: _backImagePath,
      color: _selectedColor,
      displayMode: _displayMode,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        IdentityCardWidget(card: preview, onTap: () {}),
        const SizedBox(height: 28),
        CardAppearanceSelector(
          value: _displayMode,
          onChanged: (value) => setState(() => _displayMode = value),
        ),
        if (_displayMode == 'generated') ...[
          const SizedBox(height: 28),
          ColorPicker(
            selectedColor: _selectedColor,
            onColorSelected: (color) => setState(() => _selectedColor = color),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'CARD IMAGES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a side to take a photo or choose an image. It will be cropped to card ratio and encrypted.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildImagePickerTile(
                'Front side',
                _frontImagePath,
                () => _pickImage(true),
                () => setState(() => _frontImagePath = null),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildImagePickerTile(
                'Back side',
                _backImagePath,
                () => _pickImage(false),
                () => setState(() => _backImagePath = null),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _cardTypeController,
          decoration: InputDecoration(
            labelText: 'Card label',
            hintText: 'KTP, NPWP, SIM C, BPJS...',
            prefixIcon: const Icon(Icons.label_outline_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _categoryController,
          decoration: InputDecoration(
            labelText: 'Category',
            hintText: 'Identity, Tax, Vehicle, Access...',
            prefixIcon: const Icon(Icons.category_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Name / alias (optional)',
            hintText: 'e.g. Fajar or Main KTP',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _valueController,
          decoration: InputDecoration(
            labelText: 'ID value / number (optional)',
            hintText: 'You can leave sensitive numbers empty',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 38),
        if (widget.existingCard == null)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  : const Text(
                      'SAVE CARD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePickerTile(
    String label,
    String? path,
    VoidCallback onTap,
    VoidCallback onRemove,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.586,
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (path != null && path.isNotEmpty)
                    EncryptedImageDisplay(imagePath: path, fit: BoxFit.cover)
                  else
                    ColoredBox(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (path != null && path.isNotEmpty)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: onRemove,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
