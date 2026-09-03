import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wallet/models/finance_models.dart';

class FinanceSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const FinanceSection({super.key, required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))), if (trailing != null) trailing!]),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class FinanceCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const FinanceCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark ? Colors.white.withValues(alpha: 0.055) : Colors.black.withValues(alpha: 0.035),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(20), onTap: () { HapticFeedback.selectionClick(); onTap!(); }, child: content);
  }
}

class MoneyText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final bool compact;
  const MoneyText(this.value, {super.key, this.style, this.compact = false});
  @override
  Widget build(BuildContext context) => Text(FinanceFormat.rupiah(value, compact: compact), style: style);
}

IconData financeAccountIcon(String type) {
  switch (type) {
    case 'bank': return Icons.account_balance_outlined;
    case 'ewallet': return Icons.account_balance_wallet_outlined;
    case 'cash': case 'wallet_cash': return Icons.payments_outlined;
    case 'safe': return Icons.lock_outline_rounded;
    case 'drawer': return Icons.point_of_sale_outlined;
    case 'coins': return Icons.toll_outlined;
    case 'debit_card': return Icons.credit_card_outlined;
    case 'credit_card': return Icons.credit_score_outlined;
    case 'paylater': return Icons.calendar_month_outlined;
    case 'loan': return Icons.request_quote_outlined;
    default: return Icons.account_balance_wallet_outlined;
  }
}

IconData financeTransactionIcon(String type) {
  switch (type) {
    case 'income': return Icons.south_west_rounded;
    case 'transfer': return Icons.swap_horiz_rounded;
    case 'liability_charge': return Icons.credit_card_rounded;
    case 'liability_payment': return Icons.done_all_rounded;
    case 'debt_lend': return Icons.call_made_rounded;
    case 'debt_borrow': return Icons.call_received_rounded;
    case 'debt_receive': return Icons.south_west_rounded;
    case 'debt_pay': return Icons.north_east_rounded;
    default: return Icons.north_east_rounded;
  }
}

String financeTransactionLabel(String type) {
  switch (type) {
    case 'income': return 'Pemasukan';
    case 'transfer': return 'Transfer';
    case 'liability_charge': return 'Pemakaian kredit';
    case 'liability_payment': return 'Bayar kredit';
    case 'debt_lend': return 'Meminjamkan uang';
    case 'debt_borrow': return 'Menerima pinjaman';
    case 'debt_receive': return 'Piutang dibayar';
    case 'debt_pay': return 'Bayar utang';
    default: return 'Pengeluaran';
  }
}

class FinanceEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const FinanceEmpty({super.key, required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 54, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.28)),
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
    ])),
  );
}

class FinanceQuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const FinanceQuickButton({super.key, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

class NetWorthSparkline extends StatelessWidget {
  final List<FinanceSnapshot> snapshots;
  const NetWorthSparkline({super.key, required this.snapshots});
  @override
  Widget build(BuildContext context) {
    if (snapshots.length < 2) return const SizedBox(height: 42);
    return SizedBox(height: 54, width: double.infinity, child: CustomPaint(painter: _SparkPainter(snapshots.map((e) => e.netWorth).toList(), Theme.of(context).colorScheme.primary)));
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce((a,b) => a < b ? a : b);
    final maxV = data.reduce((a,b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    final path = Path();
    for (int i=0;i<data.length;i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((data[i] - minV) / range) * (size.height - 8) - 4;
      if (i == 0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.data != data || oldDelegate.color != color;
}
