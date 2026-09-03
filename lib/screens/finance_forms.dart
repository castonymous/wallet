import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallet/models/finance_models.dart';
import 'package:wallet/models/finance_provider.dart';
import 'package:wallet/models/provider_helper.dart';
import 'package:wallet/services/finance_native_service.dart';
import 'package:wallet/services/vault_file_service.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: child,
  ),
);

InputDecoration _dec(String label, {String? hint, Widget? suffix}) => InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) => showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));

Future<String?> _pickEncryptedImage({bool camera = false}) async {
  final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, imageQuality: 94);
  if (x == null) return null;
  return VaultFileService.savePrivateCopy(File(x.path), preferredName: x.name);
}

String _normalizeWhatsApp(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
  if (digits.startsWith('8')) digits = '62$digits';
  return digits;
}

Future<void> openDebtWhatsApp(BuildContext context, FinanceDebt debt, FinanceProvider provider) async {
  final person = provider.personById(debt.personId);
  final number = _normalizeWhatsApp(person?.phone ?? '');
  if (number.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WhatsApp belum diisi.')));
    return;
  }
  final role = debt.isReceivable ? 'pinjaman' : 'utang';
  final due = debt.dueDate == null ? '' : ' jatuh tempo ${FinanceFormat.date(debt.dueDate)}';
  final text = 'Halo ${person?.name ?? ''}, mengingatkan $role ${FinanceFormat.rupiah(debt.remaining)}$due. Terima kasih.';
  final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp tidak bisa dibuka.')));
  }
}

Future<bool?> showFinanceAccountForm(BuildContext context, {FinanceAccount? account}) {
  return _sheet<bool>(context, _AccountForm(account: account));
}

class _AccountForm extends StatefulWidget {
  final FinanceAccount? account;
  const _AccountForm({this.account});
  @override State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final TextEditingController name, institution, balance, limit, statement, due, notes;
  late String type;
  int? linkedWalletId;
  bool includeNetWorth = true;
  @override void initState() {
    super.initState(); final a = widget.account;
    name = TextEditingController(text: a?.name ?? ''); institution = TextEditingController(text: a?.institution ?? '');
    balance = TextEditingController(text: a == null ? '' : a.openingBalance.toStringAsFixed(0)); limit = TextEditingController(text: a == null || a.creditLimit == 0 ? '' : a.creditLimit.toStringAsFixed(0));
    statement = TextEditingController(text: a?.statementDay?.toString() ?? ''); due = TextEditingController(text: a?.dueDay?.toString() ?? ''); notes = TextEditingController(text: a?.notes ?? '');
    type = a?.type ?? 'bank'; linkedWalletId = a?.linkedWalletId; includeNetWorth = a?.includeNetWorth ?? true;
  }
  @override void dispose() { for (final c in [name,institution,balance,limit,statement,due,notes]) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) {
    final liability = const {'credit_card','paylater','loan'}.contains(type);
    final walletCards = context.watch<WalletProvider>().wallets.where((w) => w.id != null).toList();
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18,0,18,24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.account == null ? 'Tambah Akun / Kantong' : 'Edit Akun', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16), TextField(controller: name, decoration: _dec('Nama akun', hint: 'BCA Utama / Brankas / Receh')),
      const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: type, decoration: _dec('Jenis'), items: financeAccountTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => type = v ?? type)),
      const SizedBox(height: 12), TextField(controller: institution, decoration: _dec('Institusi / Provider', hint: 'BCA, GoPay, ShopeePay...')),
      if (walletCards.isNotEmpty) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: linkedWalletId ?? -1,
          decoration: _dec('Tautkan kartu Wallet (opsional)'),
          items: [
            const DropdownMenuItem<int>(value: -1, child: Text('Tidak ditautkan')),
            ...walletCards.map((w) => DropdownMenuItem<int>(value: w.id!, child: Text(w.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => linkedWalletId = v == -1 ? null : v),
        ),
      ],
      const SizedBox(height: 12), TextField(controller: balance, keyboardType: TextInputType.number, decoration: _dec(liability ? 'Tagihan / saldo utang awal' : 'Saldo awal', hint: '0')),
      if (liability) ...[
        const SizedBox(height: 12), TextField(controller: limit, keyboardType: TextInputType.number, decoration: _dec('Limit kredit (opsional)')),
        const SizedBox(height: 12), Row(children: [Expanded(child: TextField(controller: statement, keyboardType: TextInputType.number, decoration: _dec('Tgl cetak'))), const SizedBox(width: 10), Expanded(child: TextField(controller: due, keyboardType: TextInputType.number, decoration: _dec('Tgl jatuh tempo')))]),
      ],
      const SizedBox(height: 12), TextField(controller: notes, minLines: 2, maxLines: 4, decoration: _dec('Catatan')),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Masukkan ke Net Worth'), subtitle: const Text('Matikan untuk akun hanya sebagai informasi.'), value: includeNetWorth, onChanged: (v) => setState(() => includeNetWorth = v)),
      const SizedBox(height: 10), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async {
        if (name.text.trim().isEmpty) return;
        final p = context.read<FinanceProvider>(); final opening = FinanceFormat.parseMoney(balance.text);
        final item = FinanceAccount(id: widget.account?.id, name: name.text.trim(), type: type, institution: institution.text.trim(), openingBalance: opening, currentBalance: widget.account?.currentBalance ?? opening, creditLimit: FinanceFormat.parseMoney(limit.text), statementDay: int.tryParse(statement.text), dueDay: int.tryParse(due.text), notes: notes.text.trim(), linkedWalletId: linkedWalletId, includeNetWorth: includeNetWorth, archived: widget.account?.archived ?? false, colorHex: widget.account?.colorHex ?? '', createdAt: widget.account?.createdAt ?? DateTime.now());
        if (widget.account == null) { await p.addAccount(item); } else { await p.updateAccount(item); }
        if (context.mounted) Navigator.pop(context, true);
      }, icon: const Icon(Icons.save_outlined), label: const Text('Simpan Akun'))),
    ]));
  }
}

Future<bool?> showFinanceTransactionForm(BuildContext context, {String initialType = 'expense', FinanceNotificationDraft? notificationDraft, FinanceTransaction? editing, String? initialSharedImagePath}) => _sheet<bool>(context, _TransactionForm(initialType: initialType, notificationDraft: notificationDraft, editing: editing, initialSharedImagePath: initialSharedImagePath));

class _TransactionForm extends StatefulWidget {
  final String initialType; final FinanceNotificationDraft? notificationDraft; final FinanceTransaction? editing; final String? initialSharedImagePath;
  const _TransactionForm({required this.initialType, this.notificationDraft, this.editing, this.initialSharedImagePath});
  @override State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  late String type; int? accountId, toAccountId; late TextEditingController amount, title, merchant, note, tags, reference; String category = ''; DateTime date = DateTime.now(); String attachmentPath = ''; bool ocrBusy = false;
  @override void initState() {
    super.initState(); final e = widget.editing; type = e?.type ?? widget.notificationDraft?.suggestedType ?? widget.initialType;
    accountId = e?.accountId; toAccountId = e?.toAccountId; amount = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : widget.notificationDraft?.amount == 0 ? '' : widget.notificationDraft?.amount.toStringAsFixed(0));
    title = TextEditingController(text: e?.title ?? widget.notificationDraft?.title ?? ''); merchant = TextEditingController(text: e?.merchant ?? ''); note = TextEditingController(text: e?.note ?? widget.notificationDraft?.body ?? ''); tags = TextEditingController(text: e?.tags ?? ''); reference = TextEditingController(text: e?.reference ?? '');
    category = e?.category ?? ''; date = e?.occurredAt ?? widget.notificationDraft?.time ?? DateTime.now(); attachmentPath = e?.attachmentPath ?? '';
    if (widget.initialSharedImagePath != null) { WidgetsBinding.instance.addPostFrameCallback((_) => _processShared(widget.initialSharedImagePath!)); }
  }
  Future<void> _processShared(String path) async {
    if (!mounted) return; setState(() => ocrBusy = true);
    final text = await FinanceNativeService.ocrImage(path);
    final encrypted = await VaultFileService.savePrivateCopy(File(path));
    if (encrypted != null) attachmentPath = encrypted;
    if (text.isNotEmpty) {
      final values = RegExp(r'(?:Rp\.?\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+(?:,[0-9]{1,2})?|[0-9]{4,})', caseSensitive: false).allMatches(text).map((m) => FinanceFormat.parseMoney(m.group(1))).where((v) => v > 0).toList();
      if (values.isNotEmpty && amount.text.trim().isEmpty) amount.text = values.reduce((a,b)=>a>b?a:b).toStringAsFixed(0);
      if (note.text.trim().isEmpty) note.text = text.length > 800 ? text.substring(0,800) : text;
      if (title.text.trim().isEmpty) title.text = text.split('\n').firstWhere((e)=>e.trim().length>3, orElse:()=> 'Transaksi dari bukti');
    }
    if (mounted) setState(() => ocrBusy = false);
  }
  @override void dispose() { for (final c in [amount,title,merchant,note,tags,reference]) { c.dispose(); } super.dispose(); }
  Future<void> _attachAndOcr() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95); if (x == null) return;
    setState(() => ocrBusy = true);
    final text = await FinanceNativeService.ocrImage(x.path);
    final encrypted = await VaultFileService.savePrivateCopy(File(x.path), preferredName: x.name);
    if (encrypted != null) attachmentPath = encrypted;
    if (text.isNotEmpty) {
      final m = RegExp(r'(?:Rp\.?\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+(?:,[0-9]{1,2})?|[0-9]{4,})', caseSensitive: false).allMatches(text).map((m) => FinanceFormat.parseMoney(m.group(1))).where((v) => v > 0).toList();
      if (m.isNotEmpty && amount.text.trim().isEmpty) amount.text = m.reduce((a,b) => a > b ? a : b).toStringAsFixed(0);
      if (note.text.trim().isEmpty) note.text = text.length > 800 ? text.substring(0,800) : text;
      if (title.text.trim().isEmpty) title.text = text.split('\n').firstWhere((e) => e.trim().length > 3, orElse: () => 'Transaksi dari bukti');
    }
    if (mounted) setState(() => ocrBusy = false);
  }
  @override Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final categories = type == 'income' ? financeIncomeCategories : financeExpenseCategories;
    if (category.isEmpty && type != 'transfer') category = categories.first;
    if (accountId == null && p.accounts.isNotEmpty) accountId = p.accounts.first.id;
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18,0,18,24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.editing == null ? 'Catat Transaksi' : 'Edit Transaksi', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
      SegmentedButton<String>(segments: const [ButtonSegment(value:'expense',label:Text('Keluar'),icon:Icon(Icons.north_east)), ButtonSegment(value:'income',label:Text('Masuk'),icon:Icon(Icons.south_west)), ButtonSegment(value:'transfer',label:Text('Transfer'),icon:Icon(Icons.swap_horiz))], selected: {type == 'transfer' ? 'transfer' : type == 'income' ? 'income' : 'expense'}, onSelectionChanged: (v) => setState(() { type = v.first; category = ''; })),
      const SizedBox(height: 14), TextField(controller: amount, autofocus: widget.notificationDraft == null, keyboardType: TextInputType.number, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800), decoration: _dec('Nominal', hint: 'Rp 0')),
      const SizedBox(height: 12), DropdownButtonFormField<int>(initialValue: accountId, decoration: _dec(type == 'transfer' ? 'Dari akun' : 'Akun'), items: p.accounts.map((a) => DropdownMenuItem(value:a.id,child:Text('${a.name} • ${FinanceFormat.rupiah(a.currentBalance, compact:true)}'))).toList(), onChanged:(v)=>setState(()=>accountId=v)),
      if (type == 'transfer') ...[const SizedBox(height:12), DropdownButtonFormField<int>(initialValue: toAccountId, decoration:_dec('Ke akun'), items:p.accounts.where((a)=>a.id!=accountId).map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(), onChanged:(v)=>setState(()=>toAccountId=v))],
      if (type != 'transfer') ...[const SizedBox(height:12), DropdownButtonFormField<String>(initialValue: categories.contains(category) ? category : null, decoration:_dec('Kategori'), items:categories.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged:(v)=>setState(()=>category=v??category))],
      const SizedBox(height:12), TextField(controller:title, decoration:_dec('Judul',hint:type=='expense'?'Makan siang / Belanja':'Gaji / Penjualan')),
      const SizedBox(height:12), TextField(controller:merchant, decoration:_dec('Merchant / lawan transaksi (opsional)')),
      const SizedBox(height:12), InkWell(onTap:() async { final d=await _pickDate(context,date); if(d!=null)setState(()=>date=d); }, child:InputDecorator(decoration:_dec('Tanggal'), child:Text(FinanceFormat.date(date)))),
      const SizedBox(height:12), TextField(controller:tags, decoration:_dec('Tags',hint:'#pribadi, #oisgrafika, #rumah')),
      const SizedBox(height:12), TextField(controller:reference, decoration:_dec('Nomor referensi (opsional)')),
      const SizedBox(height:12), TextField(controller:note,minLines:2,maxLines:5,decoration:_dec('Catatan')),
      const SizedBox(height:12), Row(children:[Expanded(child:OutlinedButton.icon(onPressed:ocrBusy?null:_attachAndOcr,icon:ocrBusy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.document_scanner_outlined),label:Text(attachmentPath.isEmpty?'Bukti / OCR':'Bukti terpasang'))), if(attachmentPath.isNotEmpty)...[const SizedBox(width:8),IconButton(onPressed:()=>setState(()=>attachmentPath=''),icon:const Icon(Icons.close))]]),
      const SizedBox(height:14), SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:p.accounts.isEmpty?null:() async {
        final value=FinanceFormat.parseMoney(amount.text); if(value<=0||accountId==null)return; if(type=='transfer'&&toAccountId==null)return;
        final tx=FinanceTransaction(id:widget.editing?.id,type:type,accountId:accountId,toAccountId:type=='transfer'?toAccountId:null,amount:value,category:type=='transfer'?'Transfer':category,title:title.text.trim(),merchant:merchant.text.trim(),note:note.text.trim(),tags:tags.text.trim(),source:widget.notificationDraft!=null?'notification':widget.editing?.source??'manual',attachmentPath:attachmentPath,reference:reference.text.trim(),personId:widget.editing?.personId,debtId:widget.editing?.debtId,recurringRuleId:widget.editing?.recurringRuleId,isDraft:false,occurredAt:date,createdAt:widget.editing?.createdAt??DateTime.now());
        if(widget.editing==null){await p.addTransaction(tx);}else{await p.updateTransaction(tx);} if(widget.notificationDraft!=null)await FinanceNativeService.removeNotificationDraft(widget.notificationDraft!.id); if(context.mounted)Navigator.pop(context,true);
      },icon:const Icon(Icons.check_rounded),label:const Text('Simpan Transaksi'))),
      if(p.accounts.isEmpty) const Padding(padding:EdgeInsets.only(top:10),child:Text('Buat akun dulu sebelum mencatat transaksi.')),
    ]));
  }
}

Future<bool?> showFinanceDebtForm(BuildContext context, {FinanceDebt? debt}) => _sheet<bool>(context, _DebtForm(debt: debt));

class _DebtForm extends StatefulWidget {
  final FinanceDebt? debt;
  const _DebtForm({this.debt});
  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  late String kind;
  int? personId;
  int? accountId;
  late TextEditingController name, provider, principal, total, interest, admin, notes, newPerson, newPhone;
  DateTime start = DateTime.now();
  DateTime? due;
  List<String> proofs = [];
  bool applyInitialFlow = true;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    kind = d?.kind ?? 'receivable';
    personId = d?.personId;
    accountId = d?.accountId;
    name = TextEditingController(text: d?.name ?? '');
    provider = TextEditingController(text: d?.provider ?? '');
    principal = TextEditingController(text: d == null ? '' : d.principal.toStringAsFixed(0));
    total = TextEditingController(text: d == null ? '' : d.totalDue.toStringAsFixed(0));
    interest = TextEditingController(text: d == null || d.interestAmount == 0 ? '' : d.interestAmount.toStringAsFixed(0));
    admin = TextEditingController(text: d == null || d.adminFee == 0 ? '' : d.adminFee.toStringAsFixed(0));
    notes = TextEditingController(text: d?.notes ?? '');
    newPerson = TextEditingController();
    newPhone = TextEditingController();
    start = d?.startDate ?? DateTime.now();
    due = d?.dueDate;
    proofs = List.from(d?.proofPaths ?? const []);
    applyInitialFlow = d == null;
  }

  @override
  void dispose() {
    for (final c in [name, provider, principal, total, interest, admin, notes, newPerson, newPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final personal = kind == 'receivable' || kind == 'payable';
    final accountOptions = personal
        ? p.accounts.where((a) => !a.isLiability && !a.archived).toList()
        : p.accounts.where((a) => a.isLiability && !a.archived).toList();
    if (accountId != null && !accountOptions.any((a) => a.id == accountId)) accountId = null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.debt == null ? 'Tambah Utang / Piutang' : 'Edit Utang / Piutang', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: _dec('Jenis'),
          items: const [
            DropdownMenuItem(value: 'receivable', child: Text('Piutang • orang berutang ke saya')),
            DropdownMenuItem(value: 'payable', child: Text('Utang pribadi • saya berutang')),
            DropdownMenuItem(value: 'credit', child: Text('Kartu Kredit')),
            DropdownMenuItem(value: 'paylater', child: Text('PayLater')),
            DropdownMenuItem(value: 'loan', child: Text('Pinjaman / Pinjol')),
          ],
          onChanged: (v) => setState(() {
            kind = v ?? kind;
            accountId = null;
          }),
        ),
        if (personal) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: personId,
            decoration: _dec('Orang'),
            items: p.people.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name}${e.phone.isEmpty ? '' : ' • ${e.phone}'}'))).toList(),
            onChanged: (v) => setState(() => personId = v),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Tambah orang baru'),
            children: [
              TextField(controller: newPerson, decoration: _dec('Nama')),
              const SizedBox(height: 8),
              TextField(controller: newPhone, keyboardType: TextInputType.phone, decoration: _dec('WhatsApp')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () async {
                    if (newPerson.text.trim().isEmpty) return;
                    final id = await p.addPerson(FinancePerson(name: newPerson.text.trim(), phone: newPhone.text.trim(), createdAt: DateTime.now()));
                    if (mounted) setState(() => personId = id);
                  },
                  child: const Text('Simpan Orang'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(controller: name, decoration: _dec('Nama / tujuan', hint: personal ? 'Talangan makan / Pinjaman laptop' : 'SPayLater September')),
        const SizedBox(height: 12),
        TextField(controller: provider, decoration: _dec('Provider / pemberi pinjaman', hint: 'Shopee, Akulaku, Kredivo...')),
        if (accountOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: accountId,
            decoration: _dec(personal ? 'Akun uang terkait (opsional)' : 'Akun kredit terkait (opsional)'),
            items: accountOptions.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
            onChanged: (v) => setState(() => accountId = v),
          ),
        ],
        if (widget.debt == null && personal && accountId != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sesuaikan saldo akun otomatis'),
            subtitle: Text(kind == 'receivable' ? 'Saldo akun berkurang sebesar pokok karena uang dipinjamkan.' : 'Saldo akun bertambah sebesar pokok karena menerima pinjaman.'),
            value: applyInitialFlow,
            onChanged: (v) => setState(() => applyInitialFlow = v),
          ),
        const SizedBox(height: 12),
        TextField(controller: principal, keyboardType: TextInputType.number, decoration: _dec('Pokok / nominal awal')),
        const SizedBox(height: 12),
        TextField(controller: total, keyboardType: TextInputType.number, decoration: _dec('Total harus dibayar / ditagih')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: interest, keyboardType: TextInputType.number, decoration: _dec('Bunga'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: admin, keyboardType: TextInputType.number, decoration: _dec('Admin'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: InkWell(onTap: () async { final d = await _pickDate(context, start); if (d != null) setState(() => start = d); }, child: InputDecorator(decoration: _dec('Tanggal mulai'), child: Text(FinanceFormat.dateShort(start))))),
          const SizedBox(width: 8),
          Expanded(child: InkWell(onTap: () async { final d = await _pickDate(context, due ?? DateTime.now()); if (d != null) setState(() => due = d); }, child: InputDecorator(decoration: _dec('Jatuh tempo'), child: Text(FinanceFormat.dateShort(due))))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: notes, minLines: 2, maxLines: 4, decoration: _dec('Catatan')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final path = await _pickEncryptedImage();
                if (path != null && mounted) setState(() => proofs.add(path));
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text('Bukti transfer (${proofs.length})'),
            ),
          ),
          if (proofs.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(onPressed: () => setState(() => proofs.removeLast()), icon: const Icon(Icons.undo)),
          ],
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final pr = FinanceFormat.parseMoney(principal.text);
              var td = FinanceFormat.parseMoney(total.text);
              if (td <= 0) td = pr + FinanceFormat.parseMoney(interest.text) + FinanceFormat.parseMoney(admin.text);
              if (pr <= 0 || name.text.trim().isEmpty) return;
              if (personal && personId == null && newPerson.text.trim().isNotEmpty) {
                personId = await p.addPerson(FinancePerson(name: newPerson.text.trim(), phone: newPhone.text.trim(), createdAt: DateTime.now()));
              }
              final old = widget.debt;
              final paidBefore = old == null ? 0.0 : (old.totalDue - old.remaining).clamp(0.0, old.totalDue).toDouble();
              final remaining = old == null ? td : (td - paidBefore).clamp(0.0, double.infinity).toDouble();
              final item = FinanceDebt(
                id: old?.id,
                kind: kind,
                name: name.text.trim(),
                personId: personal ? personId : null,
                accountId: accountId,
                provider: provider.text.trim(),
                principal: pr,
                totalDue: td,
                remaining: remaining,
                interestAmount: FinanceFormat.parseMoney(interest.text),
                adminFee: FinanceFormat.parseMoney(admin.text),
                startDate: start,
                dueDate: due,
                status: remaining <= 0 ? 'paid' : 'active',
                notes: notes.text.trim(),
                proofPaths: proofs,
                createdAt: old?.createdAt ?? DateTime.now(),
              );
              if (old == null) {
                final debtId = await p.addDebt(item);
                if (personal && applyInitialFlow && accountId != null) {
                  await p.addTransaction(FinanceTransaction(
                    type: kind == 'receivable' ? 'debt_lend' : 'debt_borrow',
                    accountId: accountId,
                    amount: pr,
                    category: kind == 'receivable' ? 'Piutang' : 'Utang',
                    title: name.text.trim(),
                    note: kind == 'receivable' ? 'Uang dipinjamkan' : 'Dana pinjaman diterima',
                    source: 'debt',
                    personId: personId,
                    debtId: debtId,
                    occurredAt: start,
                    createdAt: DateTime.now(),
                  ));
                }
              } else {
                await p.updateDebt(item);
              }
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan'),
          ),
        ),
      ]),
    );
  }
}

Future<bool?> showDebtPaymentForm(BuildContext context, FinanceDebt debt) => _sheet<bool>(context, _DebtPaymentForm(debt: debt));

class _DebtPaymentForm extends StatefulWidget {
  final FinanceDebt debt;
  const _DebtPaymentForm({required this.debt});
  @override
  State<_DebtPaymentForm> createState() => _DebtPaymentFormState();
}

class _DebtPaymentFormState extends State<_DebtPaymentForm> {
  int? accountId;
  final amount = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  String proof = '';

  @override
  void initState() {
    super.initState();
    amount.text = widget.debt.remaining.toStringAsFixed(0);
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final assetAccounts = p.accounts.where((a) => !a.isLiability && !a.archived).toList();
    if (accountId == null && assetAccounts.isNotEmpty) accountId = assetAccounts.first.id;
    if (accountId != null && !assetAccounts.any((a) => a.id == accountId)) accountId = assetAccounts.isEmpty ? null : assetAccounts.first.id;
    final linkedLiability = p.accountById(widget.debt.accountId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.debt.isReceivable ? 'Terima Pembayaran' : 'Bayar Utang / Cicilan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('Sisa ${FinanceFormat.rupiah(widget.debt.remaining)}'),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: _dec('Nominal')),
        const SizedBox(height: 12),
        if (assetAccounts.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: accountId,
            decoration: _dec(widget.debt.isReceivable ? 'Masuk ke akun' : 'Bayar dari akun'),
            items: assetAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
            onChanged: (v) => setState(() => accountId = v),
          ),
        const SizedBox(height: 12),
        InkWell(onTap: () async { final d = await _pickDate(context, date); if (d != null) setState(() => date = d); }, child: InputDecorator(decoration: _dec('Tanggal'), child: Text(FinanceFormat.date(date)))),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: _dec('Catatan')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final pth = await _pickEncryptedImage();
            if (pth != null && mounted) setState(() => proof = pth);
          },
          icon: const Icon(Icons.receipt_long),
          label: Text(proof.isEmpty ? 'Tambah bukti' : 'Bukti terpasang'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              final value = FinanceFormat.parseMoney(amount.text);
              if (value <= 0 || accountId == null || widget.debt.id == null) return;
              late FinanceTransaction tx;
              if (widget.debt.isReceivable) {
                tx = FinanceTransaction(
                  type: 'debt_receive', accountId: accountId, amount: value, category: 'Piutang Dibayar', title: widget.debt.name,
                  note: note.text.trim(), source: 'debt', debtId: widget.debt.id, personId: widget.debt.personId, occurredAt: date, createdAt: DateTime.now(),
                );
              } else if (linkedLiability?.isLiability == true) {
                tx = FinanceTransaction(
                  type: 'liability_payment', accountId: linkedLiability!.id, toAccountId: accountId, amount: value, category: 'Cicilan', title: widget.debt.name,
                  note: note.text.trim(), source: 'debt', debtId: widget.debt.id, personId: widget.debt.personId, occurredAt: date, createdAt: DateTime.now(),
                );
              } else {
                tx = FinanceTransaction(
                  type: 'debt_pay', accountId: accountId, amount: value, category: 'Bayar Utang', title: widget.debt.name,
                  note: note.text.trim(), source: 'debt', debtId: widget.debt.id, personId: widget.debt.personId, occurredAt: date, createdAt: DateTime.now(),
                );
              }
              await p.addDebtPayment(
                FinanceDebtPayment(debtId: widget.debt.id!, accountId: accountId, amount: value, paidAt: date, note: note.text.trim(), proofPath: proof),
                linkedTransaction: tx,
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Simpan Pembayaran'),
          ),
        ),
        if (assetAccounts.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Buat akun uang/cash terlebih dahulu untuk mencatat pembayaran.')),
      ]),
    );
  }
}

Future<bool?> showBudgetForm(BuildContext context,{FinanceBudget? budget})=>_sheet<bool>(context,_BudgetForm(budget:budget));
class _BudgetForm extends StatefulWidget{final FinanceBudget? budget;const _BudgetForm({this.budget});@override State<_BudgetForm> createState()=>_BudgetFormState();}
class _BudgetFormState extends State<_BudgetForm>{late String category;late TextEditingController amount;late int year,month;@override void initState(){super.initState();final now=DateTime.now();category=widget.budget?.category??financeExpenseCategories.first;amount=TextEditingController(text:widget.budget==null?'':widget.budget!.amount.toStringAsFixed(0));year=widget.budget?.year??now.year;month=widget.budget?.month??now.month;}@override void dispose(){amount.dispose();super.dispose();}@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(18,0,18,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Budget Bulanan',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:category,decoration:_dec('Kategori'),items:financeExpenseCategories.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>category=v??category)),const SizedBox(height:12),Row(children:[Expanded(child:DropdownButtonFormField<int>(initialValue:month,decoration:_dec('Bulan'),items:List.generate(12,(i)=>DropdownMenuItem(value:i+1,child:Text('${i+1}'))),onChanged:(v)=>setState(()=>month=v??month))),const SizedBox(width:8),Expanded(child:TextFormField(initialValue:year.toString(),keyboardType:TextInputType.number,decoration:_dec('Tahun'),onChanged:(v)=>year=int.tryParse(v)??year))]),const SizedBox(height:12),TextField(controller:amount,keyboardType:TextInputType.number,decoration:_dec('Limit budget')),const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{final v=FinanceFormat.parseMoney(amount.text);if(v<=0)return;await context.read<FinanceProvider>().upsertBudget(FinanceBudget(id:widget.budget?.id,category:category,year:year,month:month,amount:v));if(context.mounted)Navigator.pop(context,true);},child:const Text('Simpan Budget')))]));}

Future<bool?> showGoalForm(BuildContext context,{FinanceGoal? goal})=>_sheet<bool>(context,_GoalForm(goal:goal));
class _GoalForm extends StatefulWidget{final FinanceGoal? goal;const _GoalForm({this.goal});@override State<_GoalForm> createState()=>_GoalFormState();}
class _GoalFormState extends State<_GoalForm>{late TextEditingController name,target,notes;DateTime? date;int? accountId;@override void initState(){super.initState();final g=widget.goal;name=TextEditingController(text:g?.name??'');target=TextEditingController(text:g==null?'':g.targetAmount.toStringAsFixed(0));notes=TextEditingController(text:g?.notes??'');date=g?.targetDate;accountId=g?.linkedAccountId;}@override void dispose(){name.dispose();target.dispose();notes.dispose();super.dispose();}@override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,0,18,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Dana Tujuan / Sinking Fund',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:12),TextField(controller:name,decoration:_dec('Nama',hint:'Dana darurat / Servis motor')),const SizedBox(height:12),TextField(controller:target,keyboardType:TextInputType.number,decoration:_dec('Target')),const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:accountId,decoration:_dec('Akun referensi (opsional)'),items:p.accounts.where((a)=>!a.isLiability).map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(),onChanged:(v)=>setState(()=>accountId=v)),const SizedBox(height:12),InkWell(onTap:()async{final d=await _pickDate(context,date??DateTime.now().add(const Duration(days:30)));if(d!=null)setState(()=>date=d);},child:InputDecorator(decoration:_dec('Target tanggal'),child:Text(FinanceFormat.date(date)))),const SizedBox(height:12),TextField(controller:notes,minLines:2,maxLines:4,decoration:_dec('Catatan')),const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{final value=FinanceFormat.parseMoney(target.text);if(value<=0||name.text.trim().isEmpty)return;final g=widget.goal;final item=FinanceGoal(id:g?.id,name:name.text.trim(),targetAmount:value,savedAmount:g?.savedAmount??0,targetDate:date,linkedAccountId:accountId,notes:notes.text.trim(),completed:g?.completed??false);if(g==null){await p.addGoal(item);}else{await p.updateGoal(item);}if(context.mounted)Navigator.pop(context,true);},child:const Text('Simpan Goal')))]));}}

Future<bool?> showGoalContributionForm(BuildContext context,FinanceGoal goal)=>_sheet<bool>(context,_GoalContributionForm(goal:goal));
class _GoalContributionForm extends StatefulWidget{final FinanceGoal goal;const _GoalContributionForm({required this.goal});@override State<_GoalContributionForm> createState()=>_GoalContributionFormState();}
class _GoalContributionFormState extends State<_GoalContributionForm>{final amount=TextEditingController();final note=TextEditingController();@override void dispose(){amount.dispose();note.dispose();super.dispose();}@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(18,0,18,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Tambah ke ${widget.goal.name}',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:12),TextField(controller:amount,autofocus:true,keyboardType:TextInputType.number,decoration:_dec('Nominal alokasi')),const SizedBox(height:12),TextField(controller:note,decoration:_dec('Catatan')),const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{final v=FinanceFormat.parseMoney(amount.text);if(v==0||widget.goal.id==null)return;await context.read<FinanceProvider>().addGoalContribution(FinanceGoalContribution(goalId:widget.goal.id!,amount:v,date:DateTime.now(),note:note.text.trim()));if(context.mounted)Navigator.pop(context,true);},child:const Text('Simpan')))]));}

Future<bool?> showRecurringForm(BuildContext context,{FinanceRecurringRule? rule})=>_sheet<bool>(context,_RecurringForm(rule:rule));
class _RecurringForm extends StatefulWidget{final FinanceRecurringRule? rule;const _RecurringForm({this.rule});@override State<_RecurringForm> createState()=>_RecurringFormState();}
class _RecurringFormState extends State<_RecurringForm>{late String type,frequency,category;int? accountId,toAccountId;late TextEditingController name,amount,note;DateTime next=DateTime.now();bool enabled=true;@override void initState(){super.initState();final r=widget.rule;type=r?.transactionType??'expense';frequency=r?.frequency??'monthly';category=r?.category??financeExpenseCategories.first;accountId=r?.accountId;toAccountId=r?.toAccountId;name=TextEditingController(text:r?.name??'');amount=TextEditingController(text:r==null?'':r.amount.toStringAsFixed(0));note=TextEditingController(text:r?.note??'');next=r?.nextRun??DateTime.now();enabled=r?.enabled??true;}@override void dispose(){name.dispose();amount.dispose();note.dispose();super.dispose();}@override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();if(accountId==null&&p.accounts.isNotEmpty)accountId=p.accounts.first.id;final cats=type=='income'?financeIncomeCategories:financeExpenseCategories;if(!cats.contains(category))category=cats.first;return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,0,18,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Transaksi Berulang',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:12),TextField(controller:name,decoration:_dec('Nama',hint:'Internet / Gaji / Cicilan')),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:type,decoration:_dec('Jenis'),items:const[DropdownMenuItem(value:'expense',child:Text('Pengeluaran')),DropdownMenuItem(value:'income',child:Text('Pemasukan')),DropdownMenuItem(value:'transfer',child:Text('Transfer'))],onChanged:(v)=>setState(()=>type=v??type)),const SizedBox(height:12),TextField(controller:amount,keyboardType:TextInputType.number,decoration:_dec('Nominal')),const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:accountId,decoration:_dec(type=='transfer'?'Dari akun':'Akun'),items:p.accounts.map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(),onChanged:(v)=>setState(()=>accountId=v)),if(type=='transfer')...[const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:toAccountId,decoration:_dec('Ke akun'),items:p.accounts.where((a)=>a.id!=accountId).map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(),onChanged:(v)=>setState(()=>toAccountId=v))]else...[const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:category,decoration:_dec('Kategori'),items:cats.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>category=v??category))],const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:frequency,decoration:_dec('Frekuensi'),items:const[DropdownMenuItem(value:'daily',child:Text('Harian')),DropdownMenuItem(value:'weekly',child:Text('Mingguan')),DropdownMenuItem(value:'monthly',child:Text('Bulanan')),DropdownMenuItem(value:'yearly',child:Text('Tahunan'))],onChanged:(v)=>setState(()=>frequency=v??frequency)),const SizedBox(height:12),InkWell(onTap:()async{final d=await _pickDate(context,next);if(d!=null)setState(()=>next=d);},child:InputDecorator(decoration:_dec('Mulai / run berikutnya'),child:Text(FinanceFormat.date(next)))),const SizedBox(height:12),TextField(controller:note,decoration:_dec('Catatan')),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Aktif'),value:enabled,onChanged:(v)=>setState(()=>enabled=v)),const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{final v=FinanceFormat.parseMoney(amount.text);if(v<=0||name.text.trim().isEmpty||accountId==null)return;final r=FinanceRecurringRule(id:widget.rule?.id,name:name.text.trim(),transactionType:type,accountId:accountId,toAccountId:type=='transfer'?toAccountId:null,amount:v,category:type=='transfer'?'Transfer':category,frequency:frequency,nextRun:next,note:note.text.trim(),enabled:enabled);if(widget.rule==null){await p.addRecurring(r);}else{await p.updateRecurring(r);}if(context.mounted)Navigator.pop(context,true);},child:const Text('Simpan Recurring')))]));}}

Future<bool?> showReconcileForm(BuildContext context)=>_sheet<bool>(context,const _ReconcileForm());
class _ReconcileForm extends StatefulWidget{const _ReconcileForm();@override State<_ReconcileForm> createState()=>_ReconcileFormState();}
class _ReconcileFormState extends State<_ReconcileForm>{int? accountId;final actual=TextEditingController();@override void dispose(){actual.dispose();super.dispose();}@override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();if(accountId==null&&p.accounts.isNotEmpty)accountId=p.accounts.first.id;final acc=p.accountById(accountId);final target=FinanceFormat.parseMoney(actual.text);final delta=target-(acc?.currentBalance??0);return Padding(padding:const EdgeInsets.fromLTRB(18,0,18,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Rekonsiliasi Saldo',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Cocokkan saldo aplikasi dengan saldo sebenarnya tanpa memburu transaksi yang terlewat.'),const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:accountId,decoration:_dec('Akun'),items:p.accounts.map((a)=>DropdownMenuItem(value:a.id,child:Text('${a.name} • ${FinanceFormat.rupiah(a.currentBalance)}'))).toList(),onChanged:(v)=>setState(()=>accountId=v)),const SizedBox(height:12),TextField(controller:actual,keyboardType:TextInputType.number,onChanged:(_)=>setState((){}),decoration:_dec('Saldo sebenarnya')),if(actual.text.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text('Selisih: ${FinanceFormat.rupiah(delta)}',style:TextStyle(fontWeight:FontWeight.w700,color:delta==0?Colors.green:null))),const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton(onPressed:acc==null||delta==0?null:()async{await p.addTransaction(FinanceTransaction(type:delta>0?'income':'expense',accountId:acc.id,amount:delta.abs(),category:'Penyesuaian',title:'Penyesuaian saldo',note:'Rekonsiliasi dari ${FinanceFormat.rupiah(acc.currentBalance)} ke ${FinanceFormat.rupiah(target)}',source:'reconcile',occurredAt:DateTime.now(),createdAt:DateTime.now()));if(context.mounted)Navigator.pop(context,true);},child:const Text('Buat Penyesuaian')))]));}}

Future<bool?> showCashCounter(BuildContext context)=>_sheet<bool>(context,const _CashCounter());
class _CashCounter extends StatefulWidget{const _CashCounter();@override State<_CashCounter> createState()=>_CashCounterState();}
class _CashCounterState extends State<_CashCounter>{static const denoms=[100000,50000,20000,10000,5000,2000,1000,500,200,100];final ctrls=<int,TextEditingController>{};int? accountId;@override void initState(){super.initState();for(final d in denoms)ctrls[d]=TextEditingController();}@override void dispose(){for(final c in ctrls.values)c.dispose();super.dispose();}double get total=>denoms.fold(0,(s,d)=>s+d*(int.tryParse(ctrls[d]!.text)??0)).toDouble();@override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();final cashAccounts=p.accounts.where((a)=>a.isCash).toList();if(accountId==null&&cashAccounts.isNotEmpty)accountId=cashAccounts.first.id;return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,0,18,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Hitung Uang Cash',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(FinanceFormat.rupiah(total),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:12),...denoms.map((d)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[Expanded(child:Text(FinanceFormat.rupiah(d),style:const TextStyle(fontWeight:FontWeight.w600))),const Text('×'),const SizedBox(width:8),SizedBox(width:92,child:TextField(controller:ctrls[d],keyboardType:TextInputType.number,onChanged:(_)=>setState((){}),decoration:_dec('Lembar'))),const SizedBox(width:8),SizedBox(width:110,child:Text(FinanceFormat.rupiah(d*(int.tryParse(ctrls[d]!.text)??0)),textAlign:TextAlign.right))]))),if(cashAccounts.isNotEmpty)...[const SizedBox(height:8),DropdownButtonFormField<int>(initialValue:accountId,decoration:_dec('Update ke akun cash'),items:cashAccounts.map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(),onChanged:(v)=>setState(()=>accountId=v)),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:total<=0||accountId==null?null:()async{final acc=p.accountById(accountId)!;final delta=total-acc.currentBalance;if(delta!=0)await p.addTransaction(FinanceTransaction(type:delta>0?'income':'expense',accountId:acc.id,amount:delta.abs(),category:'Penyesuaian',title:'Hitung cash fisik',note:'Hasil hitung pecahan uang fisik',source:'cash_counter',occurredAt:DateTime.now(),createdAt:DateTime.now()));if(context.mounted)Navigator.pop(context,true);},child:const Text('Set Saldo Sesuai Hasil Hitung')))]else const Padding(padding:EdgeInsets.only(top:12),child:Text('Buat akun jenis Cash / Brankas / Receh terlebih dahulu.'))]));}}
