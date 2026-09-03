import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet/models/finance_models.dart';
import 'package:wallet/models/finance_provider.dart';
import 'package:wallet/screens/finance_forms.dart';
import 'package:wallet/widgets/finance_common.dart';

class FinanceDashboardScreen extends StatelessWidget {
  final VoidCallback? onOpenFinance;
  const FinanceDashboardScreen({super.key, this.onOpenFinance});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(builder: (context, p, _) {
      if (p.loading && p.accounts.isEmpty) return const Center(child: CircularProgressIndicator());
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final creditDue = <({FinanceAccount account, DateTime date})>[];
      for (final a in p.accounts.where((a) => a.isLiability && !a.archived && a.dueDay != null)) {
        DateTime dueFor(int year, int month) {
          final last = DateTime(year, month + 1, 0).day;
          return DateTime(year, month, a.dueDay!.clamp(1, last).toInt());
        }
        var due = dueFor(now.year, now.month);
        if (due.isBefore(today)) {
          final next = DateTime(now.year, now.month + 1, 1);
          due = dueFor(next.year, next.month);
        }
        creditDue.add((account: a, date: due));
      }
      creditDue.sort((a, b) => a.date.compareTo(b.date));
      return RefreshIndicator(
        onRefresh: () => p.refresh(saveSnapshot: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Ringkasan Keuangan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: FinanceCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('KEKAYAAN BERSIH', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 6),
                  MoneyText(p.netWorth, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  NetWorthSparkline(snapshots: p.snapshots),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _metric(context, 'Uang tersedia', p.availableMoney, Icons.account_balance_wallet_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _metric(context, 'Piutang', p.totalReceivables, Icons.call_received_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _metric(context, 'Utang', p.totalLiabilities, Icons.call_made_rounded)),
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                FinanceQuickButton(icon: Icons.remove_rounded, label: 'Keluar', onTap: () => showFinanceTransactionForm(context, initialType: 'expense')),
                const SizedBox(width: 8),
                FinanceQuickButton(icon: Icons.add_rounded, label: 'Masuk', onTap: () => showFinanceTransactionForm(context, initialType: 'income')),
                const SizedBox(width: 8),
                FinanceQuickButton(icon: Icons.swap_horiz_rounded, label: 'Transfer', onTap: () => showFinanceTransactionForm(context, initialType: 'transfer')),
                const SizedBox(width: 8),
                FinanceQuickButton(icon: Icons.handshake_outlined, label: 'Utang', onTap: () => showFinanceDebtForm(context)),
              ]),
            ),
            FinanceSection(
              title: 'Bulan ini',
              child: FinanceCard(child: Row(children: [
                Expanded(child: _bigMetric(context, 'Pemasukan', p.monthIncome, Icons.south_west_rounded)),
                Container(width: 1, height: 46, color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                Expanded(child: _bigMetric(context, 'Pengeluaran', p.monthExpense, Icons.north_east_rounded)),
              ])),
            ),
            FinanceSection(
              title: 'Akun & kantong',
              trailing: TextButton(onPressed: onOpenFinance, child: const Text('Lihat semua')),
              child: p.accounts.isEmpty
                  ? FinanceCard(onTap: () => showFinanceAccountForm(context), child: const Row(children: [Icon(Icons.add_circle_outline), SizedBox(width: 10), Expanded(child: Text('Belum ada akun. Tambahkan bank, e-wallet, cash, brankas atau receh.'))]))
                  : Column(children: p.accounts.take(5).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FinanceCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          CircleAvatar(radius: 18, child: Icon(financeAccountIcon(a.type), size: 19)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text(financeAccountTypes[a.type] ?? a.type, style: Theme.of(context).textTheme.bodySmall)])),
                          MoneyText(a.currentBalance, compact: true, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    )).toList()),
            ),
            FinanceSection(
              title: 'Jatuh tempo terdekat',
              child: p.upcomingDebts.isEmpty && creditDue.isEmpty
                  ? const FinanceCard(child: Text('Belum ada tagihan atau utang yang punya jatuh tempo.'))
                  : Column(children: [
                      ...p.upcomingDebts.take(4).map((d) {
                        final days = d.dueDate!.difference(today).inDays;
                        return Padding(padding: const EdgeInsets.only(bottom: 8), child: FinanceCard(child: Row(children: [
                          CircleAvatar(child: Icon(d.isReceivable ? Icons.call_received_rounded : Icons.event_busy_outlined, size: 19)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${FinanceFormat.dateShort(d.dueDate)} • ${days < 0 ? 'lewat ${days.abs()} hari' : '$days hari lagi'}', style: Theme.of(context).textTheme.bodySmall)])),
                          MoneyText(d.remaining, compact: true, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ])));
                      }),
                      ...creditDue.take(4).map((item) {
                        final days = item.date.difference(today).inDays;
                        return Padding(padding: const EdgeInsets.only(bottom: 8), child: FinanceCard(child: Row(children: [
                          const CircleAvatar(child: Icon(Icons.credit_score_outlined, size: 19)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.account.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${FinanceFormat.dateShort(item.date)} • $days hari lagi', style: Theme.of(context).textTheme.bodySmall)])),
                          MoneyText(item.account.currentBalance, compact: true, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ])));
                      }),
                    ]),
            ),
            if (p.error != null) Padding(padding: const EdgeInsets.all(16), child: Text('Finance: ${p.error}', style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      );
    });
  }

  Widget _metric(BuildContext context, String label, double value, IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 17), const SizedBox(height: 6), MoneyText(value, compact: true, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))]),
  );

  Widget _bigMetric(BuildContext context, String label, double value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 17), const SizedBox(width: 6), Text(label, style: Theme.of(context).textTheme.bodySmall)]), const SizedBox(height: 6), MoneyText(value, compact: true, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );
}
