import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wallet/models/db_helper.dart';
import 'package:wallet/models/theme_provider.dart';
import 'package:wallet/services/auto_backup_service.dart';
import 'package:wallet/services/card_utils.dart';
import 'package:wallet/services/image_service.dart';
import 'package:wallet/widgets/card_appearance_selector.dart';
import 'package:wallet/widgets/card_image_cropper.dart';
import 'package:wallet/widgets/color_picker.dart';
import 'package:wallet/widgets/form_section.dart';
import 'package:wallet/widgets/glass_credit_card.dart';
import 'package:wallet/widgets/image_picker_widget.dart';

class CreditCardEntryForm extends StatefulWidget {
  const CreditCardEntryForm({super.key});

  @override
  State<CreditCardEntryForm> createState() => _CreditCardEntryFormState();
}

class _CreditCardEntryFormState extends State<CreditCardEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _issuerController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Bank');

  String _network = 'visa';
  String _selectedColor = 'default';
  String _displayMode = 'photo';
  File? _frontImageFile;
  File? _backImageFile;
  bool _showAdditionalDetails = false;
  bool _isSaving = false;

  final _customFieldNameControllers = <TextEditingController>[];
  final _customFieldValueControllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _numberController.addListener(_onNumberChanged);
    _expiryController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onNumberChanged() {
    final detected = CardUtils.detectCardNetwork(_numberController.text);
    if (detected != null && detected != _network) {
      setState(() => _network = detected);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _numberController.removeListener(_onNumberChanged);
    _expiryController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _issuerController.dispose();
    _categoryController.dispose();
    for (final c in _customFieldNameControllers) {
      c.dispose();
    }
    for (final c in _customFieldValueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    final cropped = await pickAndCropCardImage(context);
    if (cropped == null || !mounted) return;
    setState(() {
      if (isFront) {
        _frontImageFile = cropped;
      } else {
        _backImageFile = cropped;
      }
      if (_displayMode == 'generated') _displayMode = 'photo';
    });
  }

  Future<void> _addData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_displayMode != 'generated' && _frontImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a front image or switch the appearance to Simple.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? frontImagePath;
      if (_frontImageFile != null) {
        frontImagePath = await saveImageToAppDirectory(_frontImageFile!);
      }

      String? backImagePath;
      if (_backImageFile != null) {
        backImagePath = await saveImageToAppDirectory(_backImageFile!);
      }

      final customFields = <String, String>{};
      for (int i = 0; i < _customFieldNameControllers.length; i++) {
        final fieldName = _customFieldNameControllers[i].text.trim();
        final fieldValue = _customFieldValueControllers[i].text.trim();
        if (fieldName.isNotEmpty && fieldValue.isNotEmpty) {
          customFields[fieldName] = fieldValue;
        }
      }

      final wallet = Wallet(
        name: _nameController.text.trim(),
        number: _numberController.text.trim(),
        expiry: _expiryController.text.trim(),
        network: _network,
        issuer: _issuerController.text.trim(),
        category: _categoryController.text.trim(),
        customFields: customFields.isNotEmpty ? customFields : null,
        color: _selectedColor,
        frontImagePath: frontImagePath,
        backImagePath: backImagePath,
        displayMode: _displayMode,
      );

      await DatabaseHelper.instance.insertWallet(wallet);
      AutoBackupService.triggerBackup();
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addCustomField() {
    setState(() {
      _customFieldNameControllers.add(TextEditingController());
      _customFieldValueControllers.add(TextEditingController());
    });
  }

  void _removeCustomField(int index) {
    setState(() {
      _customFieldNameControllers[index].dispose();
      _customFieldValueControllers[index].dispose();
      _customFieldNameControllers.removeAt(index);
      _customFieldValueControllers.removeAt(index);
    });
  }

  String? _numberValidator(String? value) {
    final cleaned = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.length < 4 || cleaned.length > 19) {
      return 'Use 4-19 digits, or leave it empty';
    }
    return null;
  }

  String? _expiryValidator(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length == 4 ? null : 'Use MMYY or leave it empty';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final previewWallet = Wallet(
      name: _nameController.text.isEmpty ? 'CARD NAME' : _nameController.text,
      number: _numberController.text,
      expiry: _expiryController.text,
      network: _network,
      category: _categoryController.text,
      color: _selectedColor,
      displayMode: _displayMode,
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCreditCard(
            isMasked: false,
            wallet: previewWallet,
            previewImageFile: _frontImageFile,
            previewDisplayMode: _displayMode,
            onCardTap: () {},
          ),
          const SizedBox(height: 24),
          FormSection(
            children: [
              CardAppearanceSelector(
                value: _displayMode,
                onChanged: (value) => setState(() => _displayMode = value),
              ),
              if (_displayMode == 'generated') ...[
                const SizedBox(height: 24),
                ColorPicker(
                  selectedColor: _selectedColor,
                  onColorSelected: (color) =>
                      setState(() => _selectedColor = color),
                ),
              ],
            ],
          ),
          if (_displayMode != 'generated' ||
              _frontImageFile != null ||
              _backImageFile != null)
            FormSection(
              children: [
                Text(
                  'CARD IMAGES',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Photos are cropped to the standard card ratio, then encrypted before storage.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ImagePickerWidget(
                  title: 'Front image',
                  imageFile: _frontImageFile,
                  onPickImage: () => _pickImage(true),
                  onRemoveImage: () => setState(() => _frontImageFile = null),
                ),
                const SizedBox(height: 12),
                ImagePickerWidget(
                  title: 'Back image',
                  imageFile: _backImageFile,
                  onPickImage: () => _pickImage(false),
                  onRemoveImage: () => setState(() => _backImageFile = null),
                ),
              ],
            ),
          FormSection(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Card name',
                  hintText: 'e.g. BCA Blue, Main Debit',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a card name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Bank, Work, Personal, Access...',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(
                  labelText: 'Issuer / institution (optional)',
                  hintText: 'e.g. BCA',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Card number / last digits (optional)',
                  hintText: 'You can save only the last 4 digits',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                ],
                validator: _numberValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry MMYY (optional)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: _expiryValidator,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _network,
                decoration: const InputDecoration(
                  labelText: 'Card network (optional)',
                ),
                items: const ['visa', 'mastercard', 'rupay', 'amex', 'discover']
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (newValue) {
                  if (newValue != null) setState(() => _network = newValue);
                },
              ),
            ],
          ),
          if (!_showAdditionalDetails)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAdditionalDetails = true),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Custom fields'),
              ),
            ),
          if (_showAdditionalDetails)
            FormSection(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CUSTOM FIELDS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _addCustomField,
                    ),
                  ],
                ),
                if (_customFieldNameControllers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Add anything you want to remember: physical location, account alias, notes, etc.',
                        textAlign: TextAlign.center,
                        style: themeProvider.getTextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _customFieldNameControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _customFieldNameControllers[index],
                              decoration: const InputDecoration(
                                labelText: 'Field name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _customFieldValueControllers[index],
                              decoration: const InputDecoration(labelText: 'Value'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeCustomField(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _addData,
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
