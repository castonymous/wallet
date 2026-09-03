import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet/models/finance_models.dart';
import 'package:wallet/models/finance_provider.dart';
import 'package:wallet/screens/finance_forms.dart';
import 'package:wallet/services/finance_database.dart';
import 'package:wallet/services/finance_import_service.dart';
import 'package:wallet/services/finance_native_service.dart';
import 'package:wallet/services/vault_file_service.dart';
import 'package:wallet/widgets/finance_common.dart';

class FinanceHubScreen extends StatelessWidget {
  const FinanceHubScreen({super.key});
  @override Widget build(BuildContext context) {
    final p=context.watch<FinanceProvider>();
    final items=<({String title,String sub,IconData icon,Widget page})>[
      (title:'Akun & Kantong',sub:'Bank, e-wallet, cash, brankas, receh',icon:Icons.account_balance_wallet_outlined,page:const FinanceAccountsScreen()),
      (title:'Transaksi',sub:'Masuk, keluar, transfer, split',icon:Icons.receipt_long_outlined,page:const FinanceTransactionsScreen()),
      (title:'Utang & Piutang',sub:'Orang, bukti transfer, WhatsApp',icon:Icons.handshake_outlined,page:const FinanceDebtsScreen()),
      (title:'Kredit & PayLater',sub:'Limit, tagihan, cicilan, jatuh tempo',icon:Icons.credit_score_outlined,page:const CreditCenterScreen()),
      (title:'Budget & Goal',sub:'Amplop bulanan dan dana tujuan',icon:Icons.savings_outlined,page:const BudgetGoalsScreen()),
      (title:'Kalender Finance',sub:'Jatuh tempo dan transaksi berulang',icon:Icons.calendar_month_outlined,page:const FinanceCalendarScreen()),
      (title:'Analitik',sub:'Net worth, arus kas, kategori',icon:Icons.query_stats_outlined,page:const FinanceAnalyticsScreen()),
      (title:'Otomasi & Tools',sub:'Notifikasi, OCR, import, cash counter',icon:Icons.auto_awesome_motion_outlined,page:const FinanceAutomationScreen()),
    ];
    return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,120),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Finance',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),Text('${p.accounts.length} akun • ${p.transactions.length} transaksi',style:Theme.of(context).textTheme.bodySmall)])),IconButton(onPressed:()=>p.refresh(saveSnapshot:true),icon:const Icon(Icons.refresh_rounded))]),
      const SizedBox(height:12),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.22),itemCount:items.length,itemBuilder:(context,i){final item=items[i];return FinanceCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>item.page)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(child:Icon(item.icon)),const Spacer(),Text(item.title,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(item.sub,maxLines:2,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall)]));}),
      const SizedBox(height:16),
      FinanceCard(child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Net Worth',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:5),MoneyText(p.netWorth,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900))])),FilledButton.tonalIcon(onPressed:()=>showFinanceTransactionForm(context),icon:const Icon(Icons.add),label:const Text('Catat'))])),
    ]);
  }
}

class FinanceAccountsScreen extends StatelessWidget {
  const FinanceAccountsScreen({super.key});
  @override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();return Scaffold(appBar:AppBar(title:const Text('Akun & Kantong')),floatingActionButton:FloatingActionButton(onPressed:()=>showFinanceAccountForm(context),child:const Icon(Icons.add)),body:p.accounts.isEmpty?const FinanceEmpty(icon:Icons.account_balance_wallet_outlined,title:'Belum ada akun',subtitle:'Tambahkan rekening, e-wallet, cash, brankas, receh, kartu kredit atau PayLater.'):ListView.builder(padding:const EdgeInsets.fromLTRB(16,10,16,100),itemCount:p.accounts.length,itemBuilder:(context,i){final a=p.accounts[i];return Padding(padding:const EdgeInsets.only(bottom:9),child:FinanceCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FinanceAccountDetailScreen(accountId:a.id!))),child:Row(children:[CircleAvatar(child:Icon(financeAccountIcon(a.type))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a.name,style:const TextStyle(fontWeight:FontWeight.w800)),Text('${financeAccountTypes[a.type]??a.type}${a.institution.isEmpty?'':' • ${a.institution}'}',style:Theme.of(context).textTheme.bodySmall)])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[MoneyText(a.currentBalance,style:const TextStyle(fontWeight:FontWeight.w900)),if(a.isLiability&&a.creditLimit>0)Text('sisa limit ${FinanceFormat.rupiah(a.availableLimit,compact:true)}',style:Theme.of(context).textTheme.bodySmall)])]))); }));}
}

class FinanceAccountDetailScreen extends StatelessWidget {
  final int accountId; const FinanceAccountDetailScreen({super.key,required this.accountId});
  @override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();final a=p.accountById(accountId);if(a==null)return const Scaffold(body:Center(child:Text('Akun tidak ditemukan')));final txs=p.transactions.where((t)=>t.accountId==a.id||t.toAccountId==a.id).take(50).toList();return Scaffold(appBar:AppBar(title:Text(a.name),actions:[IconButton(onPressed:()=>showFinanceAccountForm(context,account:a),icon:const Icon(Icons.edit_outlined)),PopupMenuButton<String>(onSelected:(v)async{if(v=='delete'){await p.deleteAccount(a.id!);if(context.mounted)Navigator.pop(context);}},itemBuilder:(_)=>const[PopupMenuItem(value:'delete',child:Text('Arsipkan / Hapus'))])]),body:ListView(padding:const EdgeInsets.fromLTRB(16,10,16,100),children:[FinanceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(financeAccountTypes[a.type]??a.type),const SizedBox(height:8),MoneyText(a.currentBalance,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),if(a.isLiability&&a.creditLimit>0)...[const SizedBox(height:10),LinearProgressIndicator(value:(a.currentBalance/a.creditLimit).clamp(0.0,1.0).toDouble()),const SizedBox(height:6),Text('Limit ${FinanceFormat.rupiah(a.creditLimit)} • Tersedia ${FinanceFormat.rupiah(a.availableLimit)}')],if(a.statementDay!=null||a.dueDay!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text('Cetak tagihan: ${a.statementDay??'-'} • Jatuh tempo: ${a.dueDay??'-'}'))])),const SizedBox(height:12),Row(children:[FinanceQuickButton(icon:Icons.remove,label:'Keluar',onTap:()=>showFinanceTransactionForm(context,initialType:'expense')),const SizedBox(width:8),FinanceQuickButton(icon:Icons.add,label:'Masuk',onTap:()=>showFinanceTransactionForm(context,initialType:'income')),if(a.isLiability)...[const SizedBox(width:8),FinanceQuickButton(icon:Icons.credit_card,label:'Pakai',onTap:()=>_showCreditOperation(context,a,charge:true)),const SizedBox(width:8),FinanceQuickButton(icon:Icons.done_all,label:'Bayar',onTap:()=>_showCreditOperation(context,a,charge:false))]]),const SizedBox(height:18),Text('Riwayat',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:8),...txs.map((t)=>FinanceTransactionTile(tx:t,provider:p))]));}
}

Future<void> _showCreditOperation(BuildContext context,FinanceAccount liability,{required bool charge})async{final p=context.read<FinanceProvider>();final amount=TextEditingController();int? sourceId=p.accounts.where((a)=>!a.isLiability).firstOrNull?.id;final title=TextEditingController();await showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>Padding(padding:EdgeInsets.fromLTRB(18,0,18,MediaQuery.of(ctx).viewInsets.bottom+20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(charge?'Tambah Pemakaian Kredit':'Bayar Tagihan',style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:12),TextField(controller:amount,autofocus:true,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nominal',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:title,decoration:InputDecoration(labelText:charge?'Keterangan belanja':'Catatan pembayaran',border:const OutlineInputBorder())),if(!charge)...[const SizedBox(height:10),DropdownButtonFormField<int>(initialValue:sourceId,decoration:const InputDecoration(labelText:'Bayar dari',border:OutlineInputBorder()),items:p.accounts.where((a)=>!a.isLiability).map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(),onChanged:(v)=>sourceId=v)],const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{final v=FinanceFormat.parseMoney(amount.text);if(v<=0)return;await p.addTransaction(FinanceTransaction(type:charge?'liability_charge':'liability_payment',accountId:liability.id,toAccountId:charge?null:sourceId,amount:v,category:charge?'Kredit':'Cicilan',title:title.text.trim().isEmpty?(charge?'Pemakaian ${liability.name}':'Pembayaran ${liability.name}'):title.text.trim(),source:'credit_center',occurredAt:DateTime.now(),createdAt:DateTime.now()));if(ctx.mounted)Navigator.pop(ctx);},child:Text(charge?'Simpan Pemakaian':'Simpan Pembayaran')))])));amount.dispose();title.dispose();}

class FinanceTransactionsScreen extends StatefulWidget{const FinanceTransactionsScreen({super.key});@override State<FinanceTransactionsScreen> createState()=>_FinanceTransactionsScreenState();}
class _FinanceTransactionsScreenState extends State<FinanceTransactionsScreen>{String filter='all';String query='';@override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();final list=p.transactions.where((t)=>(filter=='all'||t.type==filter)&&(query.isEmpty||'${t.title} ${t.merchant} ${t.category} ${t.tags} ${t.note}'.toLowerCase().contains(query.toLowerCase()))).toList();return Scaffold(appBar:AppBar(title:const Text('Transaksi'),actions:[IconButton(tooltip:'Split transaksi',onPressed:()=>showSplitTransactionForm(context),icon:const Icon(Icons.call_split_rounded))]),floatingActionButton:FloatingActionButton(onPressed:()=>showFinanceTransactionForm(context),child:const Icon(Icons.add)),body:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,16,8),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Cari transaksi, tag, merchant...',border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))))),SizedBox(height:42,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16),children:[for(final e in const {'all':'Semua','expense':'Keluar','income':'Masuk','transfer':'Transfer'}.entries)Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(e.value),selected:filter==e.key,onSelected:(_)=>setState(()=>filter=e.key)))])),const SizedBox(height:4),Expanded(child:list.isEmpty?const FinanceEmpty(icon:Icons.receipt_long_outlined,title:'Tidak ada transaksi',subtitle:'Catat transaksi pertama atau ubah filter pencarian.'):ListView.builder(padding:const EdgeInsets.fromLTRB(16,8,16,100),itemCount:list.length,itemBuilder:(context,i)=>Dismissible(key:ValueKey(list[i].id),direction:DismissDirection.endToStart,background:Container(alignment:Alignment.centerRight,padding:const EdgeInsets.only(right:20),color:Colors.red.withValues(alpha:.15),child:const Icon(Icons.delete,color:Colors.red)),confirmDismiss:(_)=>showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Hapus transaksi?'),content:const Text('Saldo akun akan dihitung ulang.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Hapus'))])),onDismissed:(_)=>p.deleteTransaction(list[i].id!),child:FinanceTransactionTile(tx:list[i],provider:p,onTap:()=>showFinanceTransactionForm(context,editing:list[i])))))]) );}}

class FinanceTransactionTile extends StatelessWidget {
  final FinanceTransaction tx;
  final FinanceProvider provider;
  final VoidCallback? onTap;
  const FinanceTransactionTile({required this.tx, required this.provider, this.onTap});
  @override Widget build(BuildContext context) {
    final from = provider.accountById(tx.accountId)?.name ?? '-';
    final to = provider.accountById(tx.toAccountId)?.name;
    final positive = const {'income', 'debt_borrow', 'debt_receive'}.contains(tx.type);
    final liability = tx.type.startsWith('liability_');
    final sign = tx.type == 'transfer' ? '' : positive ? '+' : liability && tx.type == 'liability_payment' ? '-' : '-';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      leading: CircleAvatar(child: Icon(financeTransactionIcon(tx.type), size: 19)),
      title: Text(tx.title.trim().isEmpty ? financeTransactionLabel(tx.type) : tx.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(tx.type == 'transfer' ? '$from → ${to ?? '-'} • ${FinanceFormat.dateShort(tx.occurredAt)}' : '${tx.category.isEmpty ? from : tx.category} • $from • ${FinanceFormat.dateShort(tx.occurredAt)}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('$sign${FinanceFormat.rupiah(tx.amount, compact: true)}', style: TextStyle(fontWeight: FontWeight.w800, color: positive ? Colors.green : null)),
    );
  }
}

Future<bool?> showSplitTransactionForm(BuildContext context) => showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => const _SplitTransactionForm());
class _SplitItem { String category; final TextEditingController amount = TextEditingController(); _SplitItem(this.category); void dispose()=>amount.dispose(); }
class _SplitTransactionForm extends StatefulWidget { const _SplitTransactionForm(); @override State<_SplitTransactionForm> createState()=>_SplitTransactionFormState(); }
class _SplitTransactionFormState extends State<_SplitTransactionForm> {
  int? accountId; final total=TextEditingController(); final title=TextEditingController(); DateTime date=DateTime.now(); final items=< _SplitItem >[_SplitItem(financeExpenseCategories[0]), _SplitItem(financeExpenseCategories[1])];
  @override void dispose(){total.dispose();title.dispose();for(final i in items)i.dispose();super.dispose();}
  double get splitTotal=>items.fold(0.0,(s,i)=>s+FinanceFormat.parseMoney(i.amount.text));
  @override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();if(accountId==null&&p.accounts.isNotEmpty)accountId=p.accounts.where((a)=>!a.isLiability).firstOrNull?.id??p.accounts.first.id;final expected=FinanceFormat.parseMoney(total.text);return Padding(padding:EdgeInsets.fromLTRB(18,0,18,MediaQuery.of(context).viewInsets.bottom+20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Split Transaksi',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:6),const Text('Satu pembayaran bisa dibagi ke beberapa kategori. Saldo tetap berkurang sesuai total split.'),const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:accountId,decoration:const InputDecoration(labelText:'Akun',border:OutlineInputBorder()),items:p.accounts.where((a)=>!a.isLiability).map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name))).toList(),onChanged:(v)=>setState(()=>accountId=v)),const SizedBox(height:10),TextField(controller:total,keyboardType:TextInputType.number,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Total pembayaran (opsional untuk cek)',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:title,decoration:const InputDecoration(labelText:'Judul / merchant',border:OutlineInputBorder())),const SizedBox(height:12),...List.generate(items.length,(i){final item=items[i];return Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[Expanded(flex:3,child:DropdownButtonFormField<String>(initialValue:item.category,decoration:const InputDecoration(labelText:'Kategori',border:OutlineInputBorder()),items:financeExpenseCategories.map((e)=>DropdownMenuItem(value:e,child:Text(e,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>item.category=v??item.category))),const SizedBox(width:8),Expanded(flex:2,child:TextField(controller:item.amount,keyboardType:TextInputType.number,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Nominal',border:OutlineInputBorder()))),IconButton(onPressed:items.length<=2?null:(){setState((){items.removeAt(i).dispose();});},icon:const Icon(Icons.remove_circle_outline))]));}),TextButton.icon(onPressed:()=>setState(()=>items.add(_SplitItem(financeExpenseCategories.last))),icon:const Icon(Icons.add),label:const Text('Tambah bagian')),const SizedBox(height:6),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Total split',style:TextStyle(fontWeight:FontWeight.w700)),MoneyText(splitTotal,style:const TextStyle(fontWeight:FontWeight.w900))]),if(expected>0&&((expected-splitTotal).abs()>.5))Padding(padding:const EdgeInsets.only(top:4),child:Text('Selisih ${FinanceFormat.rupiah(expected-splitTotal)}',style:TextStyle(color:Theme.of(context).colorScheme.error))),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:accountId==null||splitTotal<=0||(expected>0&&(expected-splitTotal).abs()>.5)?null:()async{final group='split:${DateTime.now().microsecondsSinceEpoch}';for(final item in items){final v=FinanceFormat.parseMoney(item.amount.text);if(v<=0)continue;await p.addTransaction(FinanceTransaction(type:'expense',accountId:accountId,amount:v,category:item.category,title:title.text.trim().isEmpty?'Split transaksi':title.text.trim(),tags:'#split',reference:group,source:'split',occurredAt:date,createdAt:DateTime.now()));}if(context.mounted)Navigator.pop(context,true);},child:const Text('Simpan Split')))])) );}
}

class FinanceDebtsScreen extends StatefulWidget{const FinanceDebtsScreen({super.key});@override State<FinanceDebtsScreen> createState()=>_FinanceDebtsScreenState();}
class _FinanceDebtsScreenState extends State<FinanceDebtsScreen>{String filter='all';@override Widget build(BuildContext context){final p=context.watch<FinanceProvider>();final list=p.debts.where((d)=>filter=='all'||d.kind==filter).toList();return Scaffold(appBar:AppBar(title:const Text('Utang & Piutang')),floatingActionButton:FloatingActionButton(onPressed:()=>showFinanceDebtForm(context),child:const Icon(Icons.add)),body:Column(children:[SizedBox(height:50,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.fromLTRB(16,6,16,4),children:[for(final e in const {'all':'Semua','receivable':'Piutang','payable':'Utang','loan':'Pinjaman','paylater':'PayLater','credit':'Kredit'}.entries)Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(e.value),selected:filter==e.key,onSelected:(_)=>setState(()=>filter=e.key)))])),Expanded(child:list.isEmpty?const FinanceEmpty(icon:Icons.handshake_outlined,title:'Belum ada data',subtitle:'Catat uang yang lo pinjamkan, pinjam, PayLater, kartu kredit atau pinjol.'):ListView.builder(padding:const EdgeInsets.fromLTRB(16,8,16,100),itemCount:list.length,itemBuilder:(context,i){final d=list[i];final person=p.personById(d.personId);return Padding(padding:const EdgeInsets.only(bottom:9),child:FinanceCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FinanceDebtDetailScreen(debtId:d.id!))),child:Row(children:[CircleAvatar(child:Icon(d.isReceivable?Icons.call_received:Icons.call_made)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(d.name,style:const TextStyle(fontWeight:FontWeight.w800)),Text('${person?.name??d.provider}${d.dueDate==null?'':' • ${FinanceFormat.dateShort(d.dueDate)}'}',style:Theme.of(context).textTheme.bodySmall)])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[MoneyText(d.remaining,style:const TextStyle(fontWeight:FontWeight.w900)),Text(d.status=='paid'?'Lunas':d.isReceivable?'Piutang':'Kewajiban',style:Theme.of(context).textTheme.bodySmall)])])));}))]));}}

class FinanceDebtDetailScreen extends StatefulWidget {
  final int debtId;
  const FinanceDebtDetailScreen({super.key, required this.debtId});

  @override
  State<FinanceDebtDetailScreen> createState() => _FinanceDebtDetailScreenState();
}

class _FinanceDebtDetailScreenState extends State<FinanceDebtDetailScreen> {
  List<FinanceDebtPayment> payments = [];
  List<FinanceInstallment> installments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    payments = await FinanceDatabase.instance.getDebtPayments(widget.debtId);
    installments = await FinanceDatabase.instance.getInstallments(widget.debtId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final d = p.debtById(widget.debtId);
    if (d == null) return const Scaffold(body: Center(child: Text('Data tidak ditemukan')));
    final person = p.personById(d.personId);

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          if (person?.phone.isNotEmpty == true)
            IconButton(onPressed: () => openDebtWhatsApp(context, d, p), icon: const Icon(Icons.chat_outlined), tooltip: 'WhatsApp'),
          IconButton(
            onPressed: () async {
              await showFinanceDebtForm(context, debt: d);
              await _load();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                await p.deleteDebt(d.id!);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Hapus'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          FinanceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.isReceivable ? 'PIUTANG' : 'KEWAJIBAN', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              MoneyText(d.remaining, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Awal ${FinanceFormat.rupiah(d.principal)} • Total ${FinanceFormat.rupiah(d.totalDue)}'),
              if (d.interestAmount > 0 || d.adminFee > 0) Text('Bunga ${FinanceFormat.rupiah(d.interestAmount)} • Admin ${FinanceFormat.rupiah(d.adminFee)}'),
              if (d.dueDate != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Jatuh tempo ${FinanceFormat.date(d.dueDate)}', style: const TextStyle(fontWeight: FontWeight.w700))),
              if (person != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${person.name}${person.phone.isEmpty ? '' : ' • ${person.phone}'}')),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: d.status == 'paid'
                    ? null
                    : () async {
                        await showDebtPaymentForm(context, d);
                        await _load();
                      },
                icon: Icon(d.isReceivable ? Icons.call_received : Icons.payments_outlined),
                label: Text(d.isReceivable ? 'Terima Bayar' : 'Bayar'),
              ),
            ),
            if (person?.phone.isNotEmpty == true) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () => openDebtWhatsApp(context, d, p), icon: const Icon(Icons.chat_outlined), label: const Text('WA')),
            ],
          ]),
          if (d.proofPaths.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Bukti Transfer / Dokumen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.proofPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _FinanceProofThumb(path: d.proofPaths[i], label: 'Bukti ${i + 1}'),
              ),
            ),
          ],
          if (const {'credit', 'paylater', 'loan'}.contains(d.kind)) ...[
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text('Jadwal Cicilan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: () => _addInstallment(context, d), icon: const Icon(Icons.add), label: const Text('Tambah')),
            ]),
            if (installments.isEmpty)
              const Text('Belum ada jadwal cicilan.')
            else
              ...installments.map(
                (it) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: it.paid,
                  onChanged: (v) async {
                    await FinanceDatabase.instance.markInstallmentPaid(it, v ?? false);
                    await _load();
                  },
                  title: Text(it.label.isEmpty ? 'Cicilan' : it.label),
                  subtitle: Text(FinanceFormat.date(it.dueDate)),
                  secondary: MoneyText(it.amount, compact: true),
                ),
              ),
          ],
          const SizedBox(height: 18),
          Text('Riwayat Pembayaran', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (payments.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Belum ada pembayaran.'))
          else
            ...payments.map(
              (x) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.check)),
                title: MoneyText(x.amount, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${FinanceFormat.date(x.paidAt)}${x.note.isEmpty ? '' : ' • ${x.note}'}'),
                trailing: x.proofPath.isEmpty ? null : const Icon(Icons.attachment_rounded),
                onTap: x.proofPath.isEmpty ? null : () => _showFinanceProof(context, x.proofPath, 'Bukti Pembayaran'),
              ),
            ),
          if (d.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Catatan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(d.notes),
          ],
        ],
      ),
    );
  }

  Future<void> _addInstallment(BuildContext context, FinanceDebt d) async {
    final amount = TextEditingController();
    final label = TextEditingController(text: 'Cicilan ${installments.length + 1}');
    DateTime date = d.dueDate ?? DateTime.now().add(const Duration(days: 30));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (ctx, setInner) => InkWell(
              onTap: () async {
                final x = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (x != null) setInner(() => date = x);
              },
              child: InputDecorator(decoration: const InputDecoration(labelText: 'Jatuh tempo', border: OutlineInputBorder()), child: Text(FinanceFormat.date(date))),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final v = FinanceFormat.parseMoney(amount.text);
                if (v <= 0) return;
                await FinanceDatabase.instance.insertInstallment(FinanceInstallment(debtId: d.id!, label: label.text.trim(), amount: v, dueDate: date));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ),
        ]),
      ),
    );
    amount.dispose();
    label.dispose();
    await _load();
  }
}

class _FinanceProofThumb extends StatelessWidget {
  final String path;
  final String label;
  const _FinanceProofThumb({required this.path, required this.label});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _showFinanceProof(context, path, label),
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 112,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FutureBuilder(
              future: VaultFileService.readEncryptedBytes(path),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.receipt_long_outlined)));
                return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.insert_drive_file_outlined))));
              },
            ),
          ),
        ),
      );
}

Future<void> _showFinanceProof(BuildContext context, String path, String label) async {
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))]),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
            child: FutureBuilder(
              future: VaultFileService.readEncryptedBytes(path),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator());
                return InteractiveViewer(minScale: .5, maxScale: 5, child: Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(40), child: Icon(Icons.insert_drive_file_outlined, size: 48))));
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

class CreditCenterScreen extends StatelessWidget {
  const CreditCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final accounts = p.accounts.where((a) => a.isLiability).toList();
    final debts = p.debts
        .where((d) => const {'credit', 'paylater', 'loan'}.contains(d.kind) && d.status != 'paid')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kredit & PayLater Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          if (accounts.isEmpty)
            FinanceCard(
              onTap: () => showFinanceAccountForm(context),
              child: const Text(
                'Tambahkan akun jenis Kartu Kredit / PayLater / Pinjaman untuk mulai memantau limit dan tagihan.',
              ),
            ),
          ...accounts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FinanceCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FinanceAccountDetailScreen(accountId: a.id!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Icon(financeAccountIcon(a.type))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                        MoneyText(a.currentBalance, compact: true, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    if (a.creditLimit > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: (a.currentBalance / a.creditLimit).clamp(0.0, 1.0).toDouble()),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Limit ${FinanceFormat.rupiah(a.creditLimit, compact: true)}'),
                          Text('Sisa ${FinanceFormat.rupiah(a.availableLimit, compact: true)}'),
                        ],
                      ),
                    ],
                    if (a.statementDay != null || a.dueDay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Cetak ${a.statementDay ?? '-'} • Jatuh tempo ${a.dueDay ?? '-'}'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Tagihan & Cicilan Aktif', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (debts.isEmpty)
            const Text('Belum ada tagihan/cicilan terjadwal.')
          else
            ...debts.map(
              (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FinanceDebtDetailScreen(debtId: d.id!)),
                ),
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(d.dueDate == null ? 'Tanpa jatuh tempo' : FinanceFormat.date(d.dueDate)),
                trailing: MoneyText(d.remaining, compact: true, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class BudgetGoalsScreen extends StatelessWidget {
  const BudgetGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final now = DateTime.now();
    final budgets = p.budgets.where((b) => b.year == now.year && b.month == now.month).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Budget & Dana Tujuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          Row(
            children: [
              Expanded(child: Text('Budget ${now.month}/${now.year}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: () => showBudgetForm(context), icon: const Icon(Icons.add), label: const Text('Tambah')),
            ],
          ),
          if (budgets.isEmpty)
            const FinanceCard(child: Text('Belum ada budget bulan ini. Buat amplop seperti Makan, BBM, Belanja, atau Hiburan.'))
          else
            ...budgets.map((b) {
              final spent = p.spentForBudget(b);
              final ratio = b.amount <= 0 ? 0.0 : (spent / b.amount).clamp(0.0, 2.0).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FinanceCard(
                  onTap: () => showBudgetForm(context, budget: b),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(b.category, style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text('${FinanceFormat.rupiah(spent, compact: true)} / ${FinanceFormat.rupiah(b.amount, compact: true)}'),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (v) async { if (v == 'delete' && b.id != null) await p.deleteBudget(b.id!); },
                            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Hapus budget'))],
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble()),
                      if (ratio > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text('Melebihi budget ${FinanceFormat.rupiah(spent - b.amount)}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Dana Tujuan / Sinking Fund', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: () => showGoalForm(context), icon: const Icon(Icons.add), label: const Text('Tambah')),
            ],
          ),
          if (p.goals.isEmpty)
            const FinanceCard(child: Text('Contoh: dana darurat, servis motor, pajak kendaraan, liburan, beli printer.'))
          else
            ...p.goals.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FinanceCard(
                  onTap: () => showGoalContributionForm(context, g),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text('${(g.progress * 100).round()}%'),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (v) async {
                            if (v == 'edit') await showGoalForm(context, goal: g);
                            if (v == 'delete' && g.id != null) await p.deleteGoal(g.id!);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus goal')),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: g.progress),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(FinanceFormat.rupiah(g.savedAmount, compact: true)), Text('Target ${FinanceFormat.rupiah(g.targetAmount, compact: true)}')]),
                      if (g.targetDate != null)
                        Padding(padding: const EdgeInsets.only(top: 5), child: Text('Target ${FinanceFormat.date(g.targetDate)}', style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FinanceCalendarScreen extends StatefulWidget {
  const FinanceCalendarScreen({super.key});
  @override State<FinanceCalendarScreen> createState() => _FinanceCalendarScreenState();
}

class _FinanceCalendarScreenState extends State<FinanceCalendarScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final events = <({DateTime date, String title, String type, String amount})>[];
    for (final d in p.debts) {
      if (d.status != 'paid' && d.dueDate != null && d.dueDate!.year == month.year && d.dueDate!.month == month.month) {
        events.add((date: d.dueDate!, title: d.name, type: d.isReceivable ? 'Piutang' : 'Jatuh tempo', amount: FinanceFormat.rupiah(d.remaining, compact: true)));
      }
    }
    for (final r in p.recurring) {
      if (r.enabled && r.nextRun.year == month.year && r.nextRun.month == month.month) {
        events.add((date: r.nextRun, title: r.name, type: 'Recurring', amount: FinanceFormat.rupiah(r.amount, compact: true)));
      }
    }
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    for (final a in p.accounts.where((a) => a.isLiability && !a.archived)) {
      if (a.statementDay != null) {
        final day = a.statementDay!.clamp(1, lastDay).toInt();
        events.add((date: DateTime(month.year, month.month, day), title: a.name, type: 'Cetak tagihan', amount: FinanceFormat.rupiah(a.currentBalance, compact: true)));
      }
      if (a.dueDay != null) {
        final day = a.dueDay!.clamp(1, lastDay).toInt();
        events.add((date: DateTime(month.year, month.month, day), title: a.name, type: 'Jatuh tempo kredit', amount: FinanceFormat.rupiah(a.currentBalance, compact: true)));
      }
    }
    events.sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender Finance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text('${month.month}/${month.year}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            const FinanceEmpty(icon: Icons.calendar_month_outlined, title: 'Kalender kosong', subtitle: 'Jatuh tempo utang dan transaksi recurring akan muncul di sini.')
          else
            ...events.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FinanceCard(
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withValues(alpha: .08)),
                        child: Column(children: [Text('${e.date.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('${e.date.month}/${e.date.year}', style: const TextStyle(fontSize: 9))]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(e.type, style: Theme.of(context).textTheme.bodySmall)])),
                      Text(e.amount, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FinanceAnalyticsScreen extends StatelessWidget {
  const FinanceAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final by = p.expenseByCategory();
    final sorted = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxV = sorted.isEmpty ? 1.0 : sorted.first.value;
    final savings = p.monthIncome - p.monthExpense;

    return Scaffold(
      appBar: AppBar(title: const Text('Analitik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          FinanceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Net Worth', style: TextStyle(fontWeight: FontWeight.w700)),
              MoneyText(p.netWorth, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              NetWorthSparkline(snapshots: p.snapshots),
            ]),
          ),
          const SizedBox(height: 10),
          FinanceCard(
            child: Row(children: [Expanded(child: _analyticMetric(context, 'Pemasukan', p.monthIncome)), Expanded(child: _analyticMetric(context, 'Pengeluaran', p.monthExpense)), Expanded(child: _analyticMetric(context, 'Selisih', savings))]),
          ),
          const SizedBox(height: 18),
          Text('Pengeluaran per kategori', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            const Text('Belum ada pengeluaran bulan ini.')
          else
            ...sorted.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(e.key)), MoneyText(e.value, compact: true, style: const TextStyle(fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: (e.value / maxV).clamp(0.0, 1.0).toDouble()),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _analyticMetric(BuildContext c, String l, double v) => Column(children: [Text(l, style: Theme.of(c).textTheme.bodySmall), const SizedBox(height: 4), MoneyText(v, compact: true, style: const TextStyle(fontWeight: FontWeight.w800))]);
}

class FinanceAutomationScreen extends StatelessWidget {
  const FinanceAutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Otomasi & Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          _tool(context, Icons.notifications_active_outlined, 'Notifikasi Bank & E-Wallet', 'Baca notifikasi transaksi secara lokal lalu konfirmasi sebelum dicatat.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationInboxScreen()))),
          _tool(context, Icons.document_scanner_outlined, 'OCR Bukti Transfer', 'Ada di form transaksi: pilih screenshot, nominal dan teks dicoba dibaca offline.', () => showFinanceTransactionForm(context)),
          _tool(context, Icons.file_upload_outlined, 'Import CSV / Excel', 'Import mutasi bank/e-wallet dan auto-detect tanggal, nominal, debit/kredit.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceImportScreen()))),
          _tool(context, Icons.repeat_rounded, 'Recurring Transaction', 'Gaji, internet, BPJS, cicilan dan transaksi rutin.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen()))),
          _tool(context, Icons.calculate_outlined, 'Cash Counter Indonesia', 'Hitung lembar Rp100rb sampai koin lalu cocokkan ke cash/brankas.', () => showCashCounter(context)),
          _tool(context, Icons.balance_outlined, 'Rekonsiliasi Saldo', 'Cocokkan saldo aplikasi dengan saldo sebenarnya.', () => showReconcileForm(context)),
          _tool(context, Icons.widgets_outlined, 'Widget Android', 'Widget saldo, quick entry, dan jatuh tempo diperbarui otomatis.', () => _widgetInfo(context)),
        ],
      ),
    );
  }

  Widget _tool(BuildContext c, IconData i, String t, String s, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: FinanceCard(onTap: onTap, child: Row(children: [CircleAvatar(child: Icon(i)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(s, style: Theme.of(c).textTheme.bodySmall)])), const Icon(Icons.chevron_right)])),
  );

  void _widgetInfo(BuildContext c) => showDialog(
    context: c,
    builder: (x) => AlertDialog(
      title: const Text('Widget OIS Finance'),
      content: const Text('Tekan lama home screen Android → Widgets → OIS Finance. Tersedia Balance, Quick Entry, dan Due Date. Mode privacy bisa diatur dari menu More.'),
      actions: [TextButton(onPressed: () => Navigator.pop(x), child: const Text('OK'))],
    ),
  );
}

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            onPressed: () async {
              final n = await p.runRecurring();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n transaksi recurring dibuat.')));
            },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => showRecurringForm(context), child: const Icon(Icons.add)),
      body: p.recurring.isEmpty
          ? const FinanceEmpty(icon: Icons.repeat, title: 'Belum ada recurring', subtitle: 'Tambah transaksi rutin seperti gaji, internet, listrik, BPJS atau cicilan.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              itemCount: p.recurring.length,
              itemBuilder: (c, i) {
                final r = p.recurring[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FinanceCard(
                    onTap: () => showRecurringForm(context, rule: r),
                    child: Row(children: [
                      CircleAvatar(child: Icon(r.enabled ? Icons.repeat : Icons.pause)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${r.frequency} • berikutnya ${FinanceFormat.date(r.nextRun)}', style: Theme.of(c).textTheme.bodySmall)])),
                      MoneyText(r.amount, compact: true, style: const TextStyle(fontWeight: FontWeight.w800)),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (v) async {
                          if (v == 'edit') await showRecurringForm(context, rule: r);
                          if (v == 'delete' && r.id != null) await p.deleteRecurring(r.id!);
                        },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Hapus'))],
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});
  @override State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  bool access = false;
  bool loading = true;
  List<FinanceNotificationDraft> drafts = [];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    access = await FinanceNativeService.isNotificationAccessEnabled();
    drafts = await FinanceNativeService.getNotificationDrafts();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi Terdeteksi'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              children: [
                if (!access)
                  FinanceCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Notification Access belum aktif', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('OIS Finance hanya mengambil notifikasi yang terlihat seperti transaksi dan menyimpannya lokal sebagai draft.'),
                      const SizedBox(height: 10),
                      FilledButton.icon(onPressed: FinanceNativeService.openNotificationAccessSettings, icon: const Icon(Icons.settings), label: const Text('Buka Pengaturan Android')),
                    ]),
                  ),
                if (access)
                  const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Tidak ada transaksi yang disimpan otomatis. Pilih notifikasi lalu konfirmasi akun dan kategori.')),
                if (drafts.isEmpty)
                  const FinanceEmpty(icon: Icons.notifications_none, title: 'Belum ada draft', subtitle: 'Notifikasi bank/e-wallet yang mengandung nominal transaksi akan muncul di sini.')
                else
                  ...drafts.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FinanceCard(
                        onTap: () async { await showFinanceTransactionForm(context, notificationDraft: d); _load(); },
                        child: Row(children: [const CircleAvatar(child: Icon(Icons.notifications_outlined)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.title.isEmpty ? d.packageName : d.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(d.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)])), if (d.amount > 0) MoneyText(d.amount, compact: true, style: const TextStyle(fontWeight: FontWeight.w800))]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class FinanceImportScreen extends StatefulWidget {
  const FinanceImportScreen({super.key});
  @override State<FinanceImportScreen> createState() => _FinanceImportScreenState();
}

class _FinanceImportScreenState extends State<FinanceImportScreen> {
  FinanceImportResult? result;
  int? accountId;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    if (accountId == null && p.accounts.isNotEmpty) accountId = p.accounts.where((a) => !a.isLiability).firstOrNull?.id ?? p.accounts.first.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Import Mutasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          FinanceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CSV / Excel Bank & E-Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Importer mencoba mengenali kolom tanggal, deskripsi, nominal, debit dan kredit. Hasil tetap ditinjau sebelum disimpan.'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: loading ? null : () async {
                  setState(() => loading = true);
                  try { result = await FinanceImportService.pickAndParse(); }
                  finally { if (mounted) setState(() => loading = false); }
                },
                icon: const Icon(Icons.file_open),
                label: Text(loading ? 'Membaca...' : 'Pilih CSV / XLSX'),
              ),
            ]),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Masukkan ke akun', border: OutlineInputBorder()),
              items: p.accounts.where((a) => !a.isLiability).map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => accountId = v),
            ),
            const SizedBox(height: 12),
            Text('${result!.fileName} • ${result!.rows.length} transaksi terdeteksi', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...result!.rows.take(20).map(
              (r) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(r.type == 'income' ? Icons.south_west : Icons.north_east), title: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(FinanceFormat.date(r.date)), trailing: MoneyText(r.amount, compact: true)),
            ),
            if (result!.rows.length > 20) Text('+ ${result!.rows.length - 20} transaksi lainnya'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: accountId == null || result!.rows.isEmpty ? null : () async {
                  for (final r in result!.rows) {
                    await p.addTransaction(FinanceTransaction(type: r.type, accountId: accountId, amount: r.amount, category: 'Lainnya', title: r.description, reference: r.reference, source: 'import', occurredAt: r.date, createdAt: DateTime.now()));
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result!.rows.length} transaksi diimport.')));
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.download_done),
                label: const Text('Import Semua'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
