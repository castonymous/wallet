import 'package:flutter/foundation.dart';
import 'package:wallet/models/finance_models.dart';
import 'package:wallet/services/finance_database.dart';
import 'package:wallet/services/finance_native_service.dart';

class FinanceProvider extends ChangeNotifier {
  final FinanceDatabase db = FinanceDatabase.instance;
  List<FinanceAccount> accounts = [];
  List<FinanceTransaction> transactions = [];
  List<FinancePerson> people = [];
  List<FinanceDebt> debts = [];
  List<FinanceBudget> budgets = [];
  List<FinanceGoal> goals = [];
  List<FinanceRecurringRule> recurring = [];
  List<FinanceSnapshot> snapshots = [];
  bool loading = false;
  String? error;

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    try {
      await db.database;
      await db.runRecurringRules();
      await refresh(saveSnapshot: true);
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool saveSnapshot = false}) async {
    try {
      accounts = await db.getAccounts();
      transactions = await db.getTransactions();
      people = await db.getPeople();
      debts = await db.getDebts();
      budgets = await db.getBudgets();
      goals = await db.getGoals();
      recurring = await db.getRecurring();
      snapshots = await db.getSnapshots();
      if (saveSnapshot) {
        await db.saveSnapshot(FinanceSnapshot(
          date: DateTime.now(),
          assets: totalAssets,
          liabilities: totalLiabilities,
          receivables: totalReceivables,
          netWorth: netWorth,
        ));
        snapshots = await db.getSnapshots();
      }
      await FinanceNativeService.updateWidgets(
        available: availableMoney,
        liabilities: totalLiabilities,
        receivables: totalReceivables,
        netWorth: netWorth,
        nextDue: nextDueText,
      );
      error = null;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  double get totalAssets => accounts
      .where((a) => a.includeNetWorth && !a.isLiability)
      .fold(0.0, (sum, a) => sum + a.currentBalance);

  double get availableMoney => accounts
      .where((a) => !a.isLiability && !a.archived)
      .fold(0.0, (sum, a) => sum + a.currentBalance);

  double get linkedLiabilities => accounts
      .where((a) => a.includeNetWorth && a.isLiability)
      .fold(0.0, (sum, a) => sum + a.currentBalance.abs());

  double get unlinkedDebtLiabilities => debts
      .where((d) => d.isLiability && d.status != 'paid' && (d.accountId == null || accountById(d.accountId)?.isLiability != true))
      .fold(0.0, (sum, d) => sum + d.remaining);

  double get totalLiabilities => linkedLiabilities + unlinkedDebtLiabilities;

  double get totalReceivables => debts
      .where((d) => d.isReceivable && d.status != 'paid')
      .fold(0.0, (sum, d) => sum + d.remaining);

  double get netWorth => totalAssets + totalReceivables - totalLiabilities;

  double get monthIncome {
    final now = DateTime.now();
    return transactions.where((t) => t.type == 'income' && t.occurredAt.year == now.year && t.occurredAt.month == now.month && !t.isDraft).fold(0.0, (s, t) => s + t.amount);
  }

  double get monthExpense {
    final now = DateTime.now();
    return transactions.where((t) => t.type == 'expense' && t.occurredAt.year == now.year && t.occurredAt.month == now.month && !t.isDraft).fold(0.0, (s, t) => s + t.amount);
  }

  List<FinanceDebt> get upcomingDebts {
    final result = debts.where((d) => d.status != 'paid' && d.dueDate != null).toList();
    result.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return result;
  }

  String get nextDueText {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final candidates = <({DateTime date, String name, double amount})>[];
    for (final d in upcomingDebts) {
      if (d.dueDate != null) candidates.add((date: d.dueDate!, name: d.name, amount: d.remaining));
    }
    for (final a in accounts.where((a) => a.isLiability && !a.archived && a.dueDay != null)) {
      DateTime dueFor(int year, int month) {
        final last = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, a.dueDay!.clamp(1, last).toInt());
      }
      var due = dueFor(now.year, now.month);
      if (due.isBefore(today)) {
        final next = DateTime(now.year, now.month + 1, 1);
        due = dueFor(next.year, next.month);
      }
      candidates.add((date: due, name: a.name, amount: a.currentBalance));
    }
    if (candidates.isEmpty) return 'Tidak ada jatuh tempo';
    candidates.sort((a, b) => a.date.compareTo(b.date));
    final item = candidates.first;
    return '${item.name} • ${FinanceFormat.dateShort(item.date)} • ${FinanceFormat.rupiah(item.amount, compact: true)}';
  }

  FinanceAccount? accountById(int? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  FinancePerson? personById(int? id) {
    if (id == null) return null;
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  FinanceDebt? debtById(int? id) {
    if (id == null) return null;
    for (final d in debts) {
      if (d.id == id) return d;
    }
    return null;
  }

  double spentForBudget(FinanceBudget budget) => transactions.where((t) =>
      t.type == 'expense' &&
      t.category.toLowerCase() == budget.category.toLowerCase() &&
      t.occurredAt.year == budget.year &&
      t.occurredAt.month == budget.month &&
      !t.isDraft).fold(0.0, (s, t) => s + t.amount);

  Map<String, double> expenseByCategory({DateTime? month}) {
    final target = month ?? DateTime.now();
    final result = <String, double>{};
    for (final tx in transactions) {
      if (tx.type != 'expense' || tx.isDraft || tx.occurredAt.year != target.year || tx.occurredAt.month != target.month) continue;
      final key = tx.category.trim().isEmpty ? 'Lainnya' : tx.category.trim();
      result[key] = (result[key] ?? 0) + tx.amount;
    }
    return result;
  }

  Future<void> addAccount(FinanceAccount account) async { await db.insertAccount(account); await refresh(saveSnapshot: true); }
  Future<void> updateAccount(FinanceAccount account) async { await db.updateAccount(account); await refresh(saveSnapshot: true); }
  Future<void> deleteAccount(int id) async { await db.deleteAccount(id); await refresh(saveSnapshot: true); }
  Future<void> addTransaction(FinanceTransaction tx) async { await db.insertTransaction(tx); await refresh(saveSnapshot: true); }
  Future<void> updateTransaction(FinanceTransaction tx) async { await db.updateTransaction(tx); await refresh(saveSnapshot: true); }
  Future<void> deleteTransaction(int id) async { await db.deleteTransaction(id); await refresh(saveSnapshot: true); }
  Future<int> addPerson(FinancePerson p) async { final id = await db.insertPerson(p); await refresh(); return id; }
  Future<void> updatePerson(FinancePerson p) async { await db.updatePerson(p); await refresh(); }
  Future<int> addDebt(FinanceDebt debt) async { final id = await db.insertDebt(debt); await refresh(saveSnapshot: true); return id; }
  Future<void> updateDebt(FinanceDebt debt) async { await db.updateDebt(debt); await refresh(saveSnapshot: true); }
  Future<void> deleteDebt(int id) async { await db.deleteDebt(id); await refresh(saveSnapshot: true); }
  Future<void> addDebtPayment(FinanceDebtPayment payment, {FinanceTransaction? linkedTransaction}) async { await db.addDebtPayment(payment, linkedTransaction: linkedTransaction); await refresh(saveSnapshot: true); }
  Future<void> upsertBudget(FinanceBudget budget) async { await db.upsertBudget(budget); await refresh(); }
  Future<void> deleteBudget(int id) async { await db.deleteBudget(id); await refresh(); }
  Future<void> addGoal(FinanceGoal goal) async { await db.insertGoal(goal); await refresh(); }
  Future<void> updateGoal(FinanceGoal goal) async { await db.updateGoal(goal); await refresh(); }
  Future<void> deleteGoal(int id) async { await db.deleteGoal(id); await refresh(); }
  Future<void> addGoalContribution(FinanceGoalContribution c) async { await db.addGoalContribution(c); await refresh(); }
  Future<void> addRecurring(FinanceRecurringRule r) async { await db.insertRecurring(r); await refresh(); }
  Future<void> updateRecurring(FinanceRecurringRule r) async { await db.updateRecurring(r); await refresh(); }
  Future<void> deleteRecurring(int id) async { await db.deleteRecurring(id); await refresh(); }
  Future<int> runRecurring() async { final count = await db.runRecurringRules(); await refresh(saveSnapshot: count > 0); return count; }
}
