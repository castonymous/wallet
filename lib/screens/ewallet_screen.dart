import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wallet/models/db_helper.dart';
import 'package:wallet/models/provider_helper.dart';
import 'package:wallet/services/auto_backup_service.dart';
import 'package:wallet/services/vault_file_service.dart';
import 'package:wallet/widgets/encrypted_image_display.dart';

class EWalletCard extends StatelessWidget {
  final EWalletAccount item;
  final VoidCallback? onTap;

  const EWalletCard({super.key, required this.item, this.onTap});

  static String money(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Rp 0';
    final chars = digits.split('').reversed.toList();
    final chunks = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      chunks.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return 'Rp ${chunks.reversed.join('.')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isDark ? const Color(0xFF151515) : const Color(0xFFF6F6F6),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _EWalletLogo(item: item, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.provider,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        if (item.accountName.isNotEmpty)
                          Text(
                            item.accountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                money(item.balance),
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6),
              ),
              const SizedBox(height: 3),
              Text(
                'Saldo manual',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniInfo(label: 'Nomor', value: item.phoneNumber.isEmpty ? '—' : item.phoneNumber),
                  ),
                  if (item.limit.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    Expanded(child: _MiniInfo(label: 'Limit', value: money(item.limit))),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1, color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EWalletLogo extends StatelessWidget {
  final EWalletAccount item;
  final double size;
  const _EWalletLogo({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    final path = item.logoImagePath;
    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .25),
        child: EncryptedImageDisplay(
          imagePath: path,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: (size * 3).round(),
          cacheHeight: (size * 3).round(),
        ),
      );
    }
    final initial = item.provider.trim().isEmpty ? '?' : item.provider.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * .25),
      ),
      child: Text(initial, style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w900)),
    );
  }
}

class EWalletEditScreen extends StatefulWidget {
  final EWalletAccount? item;
  const EWalletEditScreen({super.key, this.item});

  @override
  State<EWalletEditScreen> createState() => _EWalletEditScreenState();
}

class _EWalletEditScreenState extends State<EWalletEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _provider;
  late final TextEditingController _accountName;
  late final TextEditingController _phone;
  late final TextEditingController _balance;
  late final TextEditingController _limit;
  late final TextEditingController _notes;
  File? _newLogo;
  bool _removeExistingLogo = false;
  bool _saving = false;

  static const _commonProviders = ['GoPay', 'OVO', 'DANA', 'ShopeePay', 'LinkAja', 'Akulaku', 'Kredivo'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _provider = TextEditingController(text: item?.provider ?? '');
    _accountName = TextEditingController(text: item?.accountName ?? '');
    _phone = TextEditingController(text: item?.phoneNumber ?? '');
    _balance = TextEditingController(text: item?.balance ?? '');
    _limit = TextEditingController(text: item?.limit ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_provider, _accountName, _phone, _balance, _limit, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _newLogo = File(picked.path);
      _removeExistingLogo = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      String? logoPath = _removeExistingLogo ? null : widget.item?.logoImagePath;
      if (_newLogo != null) {
        final saved = await VaultFileService.savePrivateCopy(_newLogo!, preferredName: 'ewallet_logo.png');
        if (saved != null) {
          if (widget.item?.logoImagePath != null && widget.item!.logoImagePath != saved) {
            await DatabaseHelper.deleteImageFile(widget.item!.logoImagePath);
          }
          logoPath = saved;
        }
      } else if (_removeExistingLogo && widget.item?.logoImagePath != null) {
        await DatabaseHelper.deleteImageFile(widget.item!.logoImagePath);
      }

      final item = EWalletAccount(
        id: widget.item?.id,
        provider: _provider.text.trim(),
        accountName: _accountName.text.trim(),
        phoneNumber: _phone.text.trim(),
        balance: _balance.text.trim(),
        limit: _limit.text.trim(),
        notes: _notes.text.trim(),
        logoImagePath: logoPath,
        orderIndex: widget.item?.orderIndex ?? 0,
      );
      if (widget.item == null) {
        await EWalletDatabaseHelper.instance.insert(item);
      } else {
        await EWalletDatabaseHelper.instance.update(item);
      }
      AutoBackupService.triggerBackup();
      if (mounted) {
        await context.read<EWalletProvider>().fetchItems();
        if (mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPath = !_removeExistingLogo ? widget.item?.logoImagePath : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Tambah E-Wallet' : 'Edit E-Wallet'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('SIMPAN')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('PILIH CEPAT', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _commonProviders.map((name) => ActionChip(
                label: Text(name),
                onPressed: () => setState(() => _provider.text = name),
              )).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _provider,
              decoration: const InputDecoration(labelText: 'Nama layanan', hintText: 'GoPay, OVO, Akulaku, dll'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Isi nama layanan' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _accountName, decoration: const InputDecoration(labelText: 'Nama akun (opsional)')),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Nomor HP / akun'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _balance,
              decoration: const InputDecoration(labelText: 'Saldo manual', prefixText: 'Rp '),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _limit,
              decoration: const InputDecoration(labelText: 'Limit / paylater (opsional)', prefixText: 'Rp '),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),
            Text('LOGO', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: _newLogo != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(17), child: Image.file(_newLogo!, fit: BoxFit.contain))
                      : existingPath != null && existingPath.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(17), child: EncryptedImageDisplay(imagePath: existingPath, fit: BoxFit.contain))
                          : const Icon(Icons.account_balance_wallet_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.image_outlined), label: const Text('Pilih logo dari galeri')),
                      if (_newLogo != null || (existingPath?.isNotEmpty ?? false))
                        TextButton(
                          onPressed: () => setState(() {
                            _newLogo = null;
                            _removeExistingLogo = true;
                          }),
                          child: const Text('Hapus logo'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(widget.item == null ? 'SIMPAN E-WALLET' : 'SIMPAN PERUBAHAN'),
            ),
          ],
        ),
      ),
    );
  }
}

class EWalletDetailScreen extends StatelessWidget {
  final EWalletAccount item;
  const EWalletDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => EWalletEditScreen(item: item)),
              );
              if (result == true && context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EWalletCard(item: item),
          const SizedBox(height: 22),
          ListTile(leading: const Icon(Icons.phone_android_rounded), title: const Text('Nomor HP / akun'), subtitle: Text(item.phoneNumber.isEmpty ? '—' : item.phoneNumber)),
          ListTile(leading: const Icon(Icons.account_circle_outlined), title: const Text('Nama akun'), subtitle: Text(item.accountName.isEmpty ? '—' : item.accountName)),
          ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Saldo'), subtitle: Text(EWalletCard.money(item.balance))),
          if (item.limit.isNotEmpty)
            ListTile(leading: const Icon(Icons.credit_score_outlined), title: const Text('Limit'), subtitle: Text(EWalletCard.money(item.limit))),
          if (item.notes.isNotEmpty)
            ListTile(leading: const Icon(Icons.notes_rounded), title: const Text('Catatan'), subtitle: Text(item.notes)),
          const SizedBox(height: 8),
          Text(
            'Saldo dan limit bersifat manual karena OIS Finance tetap offline dan tidak terhubung ke akun layanan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
