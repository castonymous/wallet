import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:wallet/models/finance_provider.dart';
import 'package:wallet/models/provider_helper.dart';
import 'package:wallet/pages/settings_page.dart';
import 'package:wallet/screens/document_vault_screen.dart';
import 'package:wallet/screens/ewallet_screen.dart';
import 'package:wallet/screens/finance_dashboard_screen.dart';
import 'package:wallet/screens/finance_forms.dart';
import 'package:wallet/screens/finance_hub_screen.dart';
import 'package:wallet/screens/homescreen.dart';
import 'package:wallet/services/finance_native_service.dart';
import 'package:wallet/widgets/finance_common.dart';

class SuperAppShell extends StatefulWidget {
  const SuperAppShell({super.key});
  @override State<SuperAppShell> createState()=>_SuperAppShellState();
}

class _SuperAppShellState extends State<SuperAppShell> with WidgetsBindingObserver {
  int index=0;
  StreamSubscription? _shareSub;
  final titles=const ['Home','Finance','Wallet','Vault','More'];
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);WidgetsBinding.instance.addPostFrameCallback((_){_handleNativeLaunch();_initSharing();_warmProviders();});}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed){_handleNativeLaunch();context.read<FinanceProvider>().runRecurring();}}
  void _warmProviders(){context.read<WalletProvider>().fetchWallets();context.read<PassProvider>().fetchPasses();context.read<IdentityProvider>().fetchIdentities();context.read<EWalletProvider>().fetchItems();context.read<DocumentProvider>().fetchItems();}
  Future<void> _handleNativeLaunch()async{final action=await FinanceNativeService.consumeLaunchAction();if(!mounted||action==null)return;setState(()=>index=1);WidgetsBinding.instance.addPostFrameCallback((_){if(!mounted)return;if(action=='quick_income')showFinanceTransactionForm(context,initialType:'income');else if(action=='quick_transfer')showFinanceTransactionForm(context,initialType:'transfer');else if(action=='quick_expense')showFinanceTransactionForm(context,initialType:'expense');});}
  void _initSharing(){if(!Platform.isAndroid)return;_shareSub=ReceiveSharingIntent.instance.getMediaStream().listen(_handleShared,onError:(_){ });ReceiveSharingIntent.instance.getInitialMedia().then((v){_handleShared(v);ReceiveSharingIntent.instance.reset();});}
  void _handleShared(List<SharedMediaFile> files){if(files.isEmpty||!mounted)return;final path=files.first.path;if(path.isEmpty)return;WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_showShareDestination(path);});}
  Future<void> _showShareDestination(String path)async{await showModalBottomSheet(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Simpan ke OIS Finance',style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:10),ListTile(leading:const CircleAvatar(child:Icon(Icons.receipt_long_outlined)),title:const Text('Transaksi Finance'),subtitle:const Text('OCR screenshot / bukti transfer lalu isi transaksi'),onTap:(){Navigator.pop(ctx);setState(()=>index=1);showFinanceTransactionForm(context,initialSharedImagePath:path);}),ListTile(leading:const CircleAvatar(child:Icon(Icons.folder_copy_outlined)),title:const Text('Document Vault'),subtitle:const Text('Buka Vault untuk menyimpan file sebagai dokumen'),onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>DocumentEditScreen(initialFilePath:path)));}),ListTile(leading:const CircleAvatar(child:Icon(Icons.credit_card_outlined)),title:const Text('Wallet / Identity'),subtitle:const Text('Buka penyimpanan kartu untuk foto kartu/identitas'),onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>const HomeScreen()));})]))));}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_shareSub?.cancel();super.dispose();}
  @override Widget build(BuildContext context){final pages=[FinanceDashboardScreen(onOpenFinance:()=>setState(()=>index=1)),const FinanceHubScreen(),const WalletLandingScreen(),const VaultLandingScreen(),const MoreLandingScreen()];return Scaffold(appBar:AppBar(title:Text(titles[index],style:const TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const GlobalSearchScreen())),icon:const Icon(Icons.search_rounded),tooltip:'Cari semua'),if(index==0||index==1)IconButton(onPressed:()=>context.read<FinanceProvider>().refresh(saveSnapshot:true),icon:const Icon(Icons.sync_rounded),tooltip:'Refresh')]),body:IndexedStack(index:index,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v){HapticFeedback.selectionClick();setState(()=>index=v);},destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),selectedIcon:Icon(Icons.account_balance_wallet),label:'Finance'),NavigationDestination(icon:Icon(Icons.credit_card_outlined),selectedIcon:Icon(Icons.credit_card),label:'Wallet'),NavigationDestination(icon:Icon(Icons.folder_copy_outlined),selectedIcon:Icon(Icons.folder_copy),label:'Vault'),NavigationDestination(icon:Icon(Icons.more_horiz),selectedIcon:Icon(Icons.more_horiz),label:'More')]));}
}

class WalletLandingScreen extends StatelessWidget{const WalletLandingScreen({super.key});@override Widget build(BuildContext context){final wallets=context.watch<WalletProvider>().wallets;final passes=context.watch<PassProvider>().passes;final ewallets=context.watch<EWalletProvider>().items;return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,100),children:[Text('Wallet & Payment Identity',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Kartu fisik, pass, dan identitas akun pembayaran tetap terpisah dari ledger Finance.'),const SizedBox(height:14),Row(children:[Expanded(child:_count(context,'Kartu',wallets.length,Icons.credit_card)),const SizedBox(width:8),Expanded(child:_count(context,'Pass',passes.length,Icons.confirmation_number)),const SizedBox(width:8),Expanded(child:_count(context,'E-Wallet',ewallets.length,Icons.account_balance_wallet))]),const SizedBox(height:14),_open(context,'Kartu Bank & Kredit','Foto kartu, NFC, network Visa/GPN, template dan detail.',Icons.credit_card_outlined,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const HomeScreen(initialIndex:0)))),_open(context,'Pass / Loyalty','Barcode, QR, membership dan pass.',Icons.confirmation_number_outlined,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const HomeScreen(initialIndex:1)))),_open(context,'E-Wallet Identity','Nomor akun, logo, balance/limit manual.',Icons.account_balance_wallet_outlined,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const HomeScreen(initialIndex:3))))]);}Widget _count(BuildContext c,String l,int n,IconData i)=>FinanceCard(child:Column(children:[Icon(i),const SizedBox(height:6),Text('$n',style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),Text(l,style:Theme.of(c).textTheme.bodySmall)]));Widget _open(BuildContext c,String t,String s,IconData i,VoidCallback tap)=>Padding(padding:const EdgeInsets.only(bottom:9),child:FinanceCard(onTap:tap,child:Row(children:[CircleAvatar(child:Icon(i)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(fontWeight:FontWeight.w800)),Text(s,style:Theme.of(c).textTheme.bodySmall)])),const Icon(Icons.chevron_right)])));}

class VaultLandingScreen extends StatelessWidget{const VaultLandingScreen({super.key});@override Widget build(BuildContext context){final ids=context.watch<IdentityProvider>().identities;final docs=context.watch<DocumentProvider>().items;return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,100),children:[Text('Personal Vault',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Identitas dan dokumen penting tersimpan lokal terenkripsi.'),const SizedBox(height:14),Row(children:[Expanded(child:FinanceCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const HomeScreen(initialIndex:2))),child:Column(children:[const Icon(Icons.badge_outlined),const SizedBox(height:6),Text('${ids.length}',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const Text('Identity')]))),const SizedBox(width:10),Expanded(child:FinanceCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const HomeScreen(initialIndex:4))),child:Column(children:[const Icon(Icons.description_outlined),const SizedBox(height:6),Text('${docs.length}',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const Text('Documents')])))]),const SizedBox(height:14),FinanceCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DocumentEditScreen())),child:const Row(children:[CircleAvatar(child:Icon(Icons.add)),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Tambah Dokumen',style:TextStyle(fontWeight:FontWeight.w800)),Text('PNG, JPG, PDF, DOCX • A4 portrait / landscape')])),Icon(Icons.chevron_right)]))]);}}

class MoreLandingScreen extends StatelessWidget {
  const MoreLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _item(context, Icons.settings_outlined, 'Pengaturan & Backup', 'Biometric, tema, backup terenkripsi, restore.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
        const _WidgetPrivacyCard(),
        _item(context, Icons.notifications_active_outlined, 'Notification Parser', 'Atur akses notifikasi transaksi.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationInboxScreen()))),
        _item(context, Icons.repeat, 'Recurring', 'Kelola transaksi rutin.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen()))),
        _item(context, Icons.file_upload_outlined, 'Import Mutasi', 'CSV / Excel bank dan e-wallet.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceImportScreen()))),
        _item(context, Icons.calculate_outlined, 'Cash Counter', 'Hitung pecahan cash fisik.', () => showCashCounter(context)),
        _item(context, Icons.balance_outlined, 'Rekonsiliasi', 'Cocokkan saldo aktual.', () => showReconcileForm(context)),
      ],
    );
  }

  Widget _item(BuildContext c, IconData i, String t, String s, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: FinanceCard(
          onTap: tap,
          child: Row(children: [
            CircleAvatar(child: Icon(i)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w800)), Text(s, style: Theme.of(c).textTheme.bodySmall)])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
}

class _WidgetPrivacyCard extends StatefulWidget {
  const _WidgetPrivacyCard();
  @override
  State<_WidgetPrivacyCard> createState() => _WidgetPrivacyCardState();
}

class _WidgetPrivacyCardState extends State<_WidgetPrivacyCard> {
  bool hidden = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    FinanceNativeService.getWidgetPrivacy().then((value) {
      if (mounted) setState(() { hidden = value; loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: FinanceCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const CircleAvatar(child: Icon(Icons.visibility_off_outlined)),
            title: const Text('Privacy Widget', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(hidden ? 'Nominal widget disembunyikan.' : 'Nominal widget terlihat di home screen.'),
            value: hidden,
            onChanged: loading
                ? null
                : (value) async {
                    setState(() => hidden = value);
                    await FinanceNativeService.setWidgetPrivacy(value);
                    if (mounted) await context.read<FinanceProvider>().refresh();
                  },
          ),
        ),
      );
}

class GlobalSearchScreen extends StatefulWidget{const GlobalSearchScreen({super.key});@override State<GlobalSearchScreen> createState()=>_GlobalSearchScreenState();}
class _GlobalSearchScreenState extends State<GlobalSearchScreen>{String q='';@override Widget build(BuildContext context){final fin=context.watch<FinanceProvider>();final wallets=context.watch<WalletProvider>().wallets;final ids=context.watch<IdentityProvider>().identities;final ew=context.watch<EWalletProvider>().items;final docs=context.watch<DocumentProvider>().items;final query=q.toLowerCase().trim();final tx=query.isEmpty?<dynamic>[]:fin.transactions.where((x)=>'${x.title} ${x.merchant} ${x.category} ${x.note} ${x.tags} ${x.amount}'.toLowerCase().contains(query)).take(20).toList();final ac=query.isEmpty?<dynamic>[]:fin.accounts.where((x)=>'${x.name} ${x.institution} ${x.type}'.toLowerCase().contains(query)).toList();final debt=query.isEmpty?<dynamic>[]:fin.debts.where((x)=>'${x.name} ${x.provider} ${x.notes}'.toLowerCase().contains(query)).toList();final wc=query.isEmpty?<dynamic>[]:wallets.where((x)=>'${x.name} ${x.network} ${x.issuer} ${x.category}'.toLowerCase().contains(query)).toList();final ic=query.isEmpty?<dynamic>[]:ids.where((x)=>'${x.name} ${x.cardType} ${x.category} ${x.value}'.toLowerCase().contains(query)).toList();final ec=query.isEmpty?<dynamic>[]:ew.where((x)=>'${x.provider} ${x.accountName} ${x.phoneNumber}'.toLowerCase().contains(query)).toList();final dc=query.isEmpty?<dynamic>[]:docs.where((x)=>'${x.title} ${x.category} ${x.fileName} ${x.notes}'.toLowerCase().contains(query)).toList();return Scaffold(appBar:AppBar(title:TextField(autofocus:true,onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(hintText:'Cari Budi, BCA, 350000, #usaha...',border:InputBorder.none))),body:query.isEmpty?const FinanceEmpty(icon:Icons.search,title:'Cari semua data',subtitle:'Finance, kartu, identitas, e-wallet dan dokumen.'):ListView(padding:const EdgeInsets.fromLTRB(16,8,16,100),children:[if(ac.isNotEmpty)...[const _SearchHeader('Akun'),...ac.map((x)=>ListTile(leading:const Icon(Icons.account_balance_wallet_outlined),title:Text(x.name),trailing:MoneyText(x.currentBalance,compact:true)))],if(tx.isNotEmpty)...[const _SearchHeader('Transaksi'),...tx.map((x)=>FinanceTransactionTile(tx:x,provider:fin))],if(debt.isNotEmpty)...[const _SearchHeader('Utang / Piutang'),...debt.map((x)=>ListTile(leading:const Icon(Icons.handshake_outlined),title:Text(x.name),trailing:MoneyText(x.remaining,compact:true)))],if(wc.isNotEmpty)...[const _SearchHeader('Kartu'),...wc.map((x)=>ListTile(leading:const Icon(Icons.credit_card),title:Text(x.name),subtitle:Text(x.network)))],if(ic.isNotEmpty)...[const _SearchHeader('Identity'),...ic.map((x)=>ListTile(leading:const Icon(Icons.badge_outlined),title:Text(x.name),subtitle:Text(x.cardType)))],if(ec.isNotEmpty)...[const _SearchHeader('E-Wallet'),...ec.map((x)=>ListTile(leading:const Icon(Icons.account_balance_wallet),title:Text(x.provider),subtitle:Text(x.accountName)))],if(dc.isNotEmpty)...[const _SearchHeader('Documents'),...dc.map((x)=>ListTile(leading:const Icon(Icons.description_outlined),title:Text(x.title),subtitle:Text(x.fileName)))],if([ac,tx,debt,wc,ic,ec,dc].every((x)=>x.isEmpty))const FinanceEmpty(icon:Icons.search_off,title:'Tidak ditemukan',subtitle:'Coba kata kunci lain.')])) ;}}
class _SearchHeader extends StatelessWidget{final String title;const _SearchHeader(this.title);@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(0,12,0,4),child:Text(title,style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w900)));}
