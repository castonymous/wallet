import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wallet/models/finance_models.dart';

class FinanceDatabase {
  FinanceDatabase._();
  static final FinanceDatabase instance = FinanceDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'finance.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _create,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''CREATE TABLE finance_accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      institution TEXT,
      openingBalance TEXT,
      currentBalance TEXT,
      creditLimit TEXT,
      statementDay INTEGER,
      dueDay INTEGER,
      notes TEXT,
      linkedWalletId INTEGER,
      includeNetWorth INTEGER DEFAULT 1,
      archived INTEGER DEFAULT 0,
      colorHex TEXT,
      createdAt INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE finance_transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      accountId INTEGER,
      toAccountId INTEGER,
      amount TEXT NOT NULL,
      category TEXT,
      title TEXT,
      merchant TEXT,
      note TEXT,
      tags TEXT,
      source TEXT,
      attachmentPath TEXT,
      reference TEXT,
      personId INTEGER,
      debtId INTEGER,
      recurringRuleId INTEGER,
      isDraft INTEGER DEFAULT 0,
      occurredAt INTEGER NOT NULL,
      createdAt INTEGER NOT NULL
    )''');
    await db.execute('CREATE INDEX idx_fin_tx_date ON finance_transactions(occurredAt DESC)');
    await db.execute('CREATE INDEX idx_fin_tx_account ON finance_transactions(accountId)');
    await db.execute('''CREATE TABLE finance_people(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT,
      notes TEXT,
      createdAt INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE finance_debts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      personId INTEGER,
      accountId INTEGER,
      provider TEXT,
      principal TEXT,
      totalDue TEXT,
      remaining TEXT,
      interestAmount TEXT,
      adminFee TEXT,
      startDate INTEGER,
      dueDate INTEGER,
      status TEXT,
      notes TEXT,
      proofPaths TEXT,
      createdAt INTEGER NOT NULL
    )''');
    await db.execute('CREATE INDEX idx_fin_debt_due ON finance_debts(dueDate)');
    await db.execute('''CREATE TABLE finance_debt_payments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      debtId INTEGER NOT NULL,
      accountId INTEGER,
      amount TEXT NOT NULL,
      paidAt INTEGER NOT NULL,
      note TEXT,
      proofPath TEXT
    )''');
    await db.execute('''CREATE TABLE finance_installments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      debtId INTEGER NOT NULL,
      label TEXT,
      amount TEXT NOT NULL,
      dueDate INTEGER NOT NULL,
      paid INTEGER DEFAULT 0,
      paidAt INTEGER
    )''');
    await db.execute('CREATE INDEX idx_fin_installment_due ON finance_installments(dueDate)');
    await db.execute('''CREATE TABLE finance_budgets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      amount TEXT NOT NULL
    )''');
    await db.execute('CREATE UNIQUE INDEX idx_fin_budget_unique ON finance_budgets(category, year, month)');
    await db.execute('''CREATE TABLE finance_goals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      targetAmount TEXT NOT NULL,
      savedAmount TEXT NOT NULL,
      targetDate INTEGER,
      linkedAccountId INTEGER,
      notes TEXT,
      completed INTEGER DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE finance_goal_contributions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      goalId INTEGER NOT NULL,
      amount TEXT NOT NULL,
      date INTEGER NOT NULL,
      note TEXT
    )''');
    await db.execute('''CREATE TABLE finance_recurring(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      transactionType TEXT NOT NULL,
      accountId INTEGER,
      toAccountId INTEGER,
      amount TEXT NOT NULL,
      category TEXT,
      frequency TEXT NOT NULL,
      nextRun INTEGER NOT NULL,
      note TEXT,
      enabled INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE finance_snapshots(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date INTEGER NOT NULL,
      assets TEXT NOT NULL,
      liabilities TEXT NOT NULL,
      receivables TEXT NOT NULL,
      netWorth TEXT NOT NULL
    )''');
    await db.execute('CREATE INDEX idx_fin_snap_date ON finance_snapshots(date DESC)');
  }

  Future<int> insertAccount(FinanceAccount account) async {
    final db = await database;
    final map = account.toDb()..remove('id');
    return db.insert('finance_accounts', map);
  }

  Future<void> updateAccount(FinanceAccount account) async {
    if (account.id == null) return;
    final db = await database;
    final map = account.toDb()..remove('id');
    await db.update('finance_accounts', map, where: 'id = ?', whereArgs: [account.id]);
  }

  Future<void> deleteAccount(int id) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM finance_transactions WHERE accountId = ? OR toAccountId = ?', [id, id])) ?? 0;
    if (count > 0) {
      await db.update('finance_accounts', {'archived': 1}, where: 'id = ?', whereArgs: [id]);
      return;
    }
    await db.delete('finance_accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FinanceAccount>> getAccounts({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query('finance_accounts', where: includeArchived ? null : 'archived = 0', orderBy: 'createdAt ASC');
    return rows.map(FinanceAccount.fromDb).toList();
  }

  Future<int> insertTransaction(FinanceTransaction tx, {bool rebuild = true}) async {
    final db = await database;
    final map = tx.toDb()..remove('id');
    final id = await db.insert('finance_transactions', map);
    if (rebuild && !tx.isDraft) await rebuildBalances();
    return id;
  }

  Future<void> updateTransaction(FinanceTransaction tx) async {
    if (tx.id == null) return;
    final db = await database;
    final map = tx.toDb()..remove('id');
    await db.update('finance_transactions', map, where: 'id = ?', whereArgs: [tx.id]);
    await rebuildBalances();
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    final rows = await db.query('finance_transactions', columns: ['attachmentPath'], where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) await _deleteEncryptedFile(rows.first['attachmentPath']?.toString());
    await db.delete('finance_transactions', where: 'id = ?', whereArgs: [id]);
    await rebuildBalances();
  }

  Future<List<FinanceTransaction>> getTransactions({int? limit}) async {
    final db = await database;
    final rows = await db.query('finance_transactions', orderBy: 'occurredAt DESC, id DESC', limit: limit);
    return rows.map(FinanceTransaction.fromDb).toList();
  }

  Future<void> rebuildBalances() async {
    final db = await database;
    final accountRows = await db.query('finance_accounts');
    final accounts = accountRows.map(FinanceAccount.fromDb).toList();
    final balances = <int, double>{};
    for (final a in accounts) {
      if (a.id != null) balances[a.id!] = a.openingBalance;
    }
    final txRows = await db.query('finance_transactions', where: 'isDraft = 0', orderBy: 'occurredAt ASC, id ASC');
    for (final row in txRows) {
      final tx = FinanceTransaction.fromDb(row);
      final amount = tx.amount.abs();
      switch (tx.type) {
        case 'income':
          if (tx.accountId != null) balances[tx.accountId!] = (balances[tx.accountId!] ?? 0) + amount;
          break;
        case 'expense':
          if (tx.accountId != null) balances[tx.accountId!] = (balances[tx.accountId!] ?? 0) - amount;
          break;
        case 'transfer':
          if (tx.accountId != null) balances[tx.accountId!] = (balances[tx.accountId!] ?? 0) - amount;
          if (tx.toAccountId != null) balances[tx.toAccountId!] = (balances[tx.toAccountId!] ?? 0) + amount;
          break;
        case 'liability_charge':
          if (tx.accountId != null) balances[tx.accountId!] = (balances[tx.accountId!] ?? 0) + amount;
          break;
        case 'liability_payment':
          if (tx.accountId != null) balances[tx.accountId!] = ((balances[tx.accountId!] ?? 0) - amount).clamp(0.0, double.infinity).toDouble();
          if (tx.toAccountId != null) balances[tx.toAccountId!] = (balances[tx.toAccountId!] ?? 0) - amount;
          break;
        case 'debt_lend':
        case 'debt_pay':
          if (tx.accountId != null) balances[tx.accountId!] = (balances[tx.accountId!] ?? 0) - amount;
          break;
        case 'debt_borrow':
        case 'debt_receive':
          if (tx.accountId != null) balances[tx.accountId!] = (balances[tx.accountId!] ?? 0) + amount;
          break;
        default:
          break;
      }
    }
    final batch = db.batch();
    for (final entry in balances.entries) {
      batch.update('finance_accounts', {'currentBalance': FinanceCrypto.encDouble(entry.value)}, where: 'id = ?', whereArgs: [entry.key]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> insertPerson(FinancePerson person) async {
    final db = await database;
    final map = person.toDb()..remove('id');
    return db.insert('finance_people', map);
  }

  Future<void> updatePerson(FinancePerson person) async {
    if (person.id == null) return;
    final db = await database;
    final map = person.toDb()..remove('id');
    await db.update('finance_people', map, where: 'id = ?', whereArgs: [person.id]);
  }

  Future<List<FinancePerson>> getPeople() async {
    final db = await database;
    final rows = await db.query('finance_people', orderBy: 'createdAt DESC');
    return rows.map(FinancePerson.fromDb).toList();
  }

  Future<int> insertDebt(FinanceDebt debt) async {
    final db = await database;
    final map = debt.toDb()..remove('id');
    return db.insert('finance_debts', map);
  }

  Future<void> updateDebt(FinanceDebt debt) async {
    if (debt.id == null) return;
    final db = await database;
    final map = debt.toDb()..remove('id');
    await db.update('finance_debts', map, where: 'id = ?', whereArgs: [debt.id]);
  }

  Future<void> deleteDebt(int id) async {
    final db = await database;
    final rows = await db.query('finance_debts', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final debt = FinanceDebt.fromDb(rows.first);
      for (final path in debt.proofPaths) { await _deleteEncryptedFile(path); }
    }
    final paymentRows = await db.query('finance_debt_payments', where: 'debtId = ?', whereArgs: [id]);
    for (final row in paymentRows) { await _deleteEncryptedFile(row['proofPath']?.toString()); }
    await db.delete('finance_debt_payments', where: 'debtId = ?', whereArgs: [id]);
    await db.delete('finance_transactions', where: 'debtId = ?', whereArgs: [id]);
    await db.delete('finance_debts', where: 'id = ?', whereArgs: [id]);
    await rebuildBalances();
  }

  Future<List<FinanceDebt>> getDebts() async {
    final db = await database;
    final rows = await db.query('finance_debts', orderBy: 'CASE WHEN dueDate IS NULL THEN 1 ELSE 0 END, dueDate ASC, createdAt DESC');
    return rows.map(FinanceDebt.fromDb).toList();
  }

  Future<int> addDebtPayment(FinanceDebtPayment payment, {FinanceTransaction? linkedTransaction}) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final map = payment.toDb()..remove('id');
      final id = await txn.insert('finance_debt_payments', map);
      final debtRows = await txn.query('finance_debts', where: 'id = ?', whereArgs: [payment.debtId], limit: 1);
      if (debtRows.isNotEmpty) {
        final debt = FinanceDebt.fromDb(debtRows.first);
        final remaining = (debt.remaining - payment.amount).clamp(0.0, double.infinity).toDouble();
        final updated = FinanceDebt(
          id: debt.id, kind: debt.kind, name: debt.name, personId: debt.personId, accountId: debt.accountId,
          provider: debt.provider, principal: debt.principal, totalDue: debt.totalDue, remaining: remaining,
          interestAmount: debt.interestAmount, adminFee: debt.adminFee, startDate: debt.startDate, dueDate: debt.dueDate,
          status: remaining <= 0 ? 'paid' : 'active', notes: debt.notes, proofPaths: debt.proofPaths, createdAt: debt.createdAt,
        );
        final dm = updated.toDb()..remove('id');
        await txn.update('finance_debts', dm, where: 'id = ?', whereArgs: [debt.id]);
      }
      if (linkedTransaction != null) {
        final txMap = linkedTransaction.toDb()..remove('id');
        await txn.insert('finance_transactions', txMap);
      }
      return id;
    }).whenComplete(rebuildBalances);
  }

  Future<List<FinanceDebtPayment>> getDebtPayments(int debtId) async {
    final db = await database;
    final rows = await db.query('finance_debt_payments', where: 'debtId = ?', whereArgs: [debtId], orderBy: 'paidAt DESC');
    return rows.map(FinanceDebtPayment.fromDb).toList();
  }

  Future<int> insertInstallment(FinanceInstallment item) async { final db=await database; final map=item.toDb()..remove('id'); return db.insert('finance_installments',map); }
  Future<List<FinanceInstallment>> getInstallments(int debtId) async => (await database).query('finance_installments',where:'debtId = ?',whereArgs:[debtId],orderBy:'dueDate ASC').then((r)=>r.map(FinanceInstallment.fromDb).toList());
  Future<void> markInstallmentPaid(FinanceInstallment item,bool paid) async { if(item.id==null)return; await (await database).update('finance_installments',{'paid':paid?1:0,'paidAt':paid?DateTime.now().millisecondsSinceEpoch:null},where:'id = ?',whereArgs:[item.id]); }
  Future<void> deleteInstallment(int id) async => (await database).delete('finance_installments',where:'id = ?',whereArgs:[id]);

  Future<void> upsertBudget(FinanceBudget budget) async {
    final db = await database;
    final existing = await db.query('finance_budgets', where: 'year = ? AND month = ?', whereArgs: [budget.year, budget.month]);
    FinanceBudget? match;
    for (final row in existing) {
      final candidate = FinanceBudget.fromDb(row);
      if (candidate.category.toLowerCase() == budget.category.toLowerCase()) { match = candidate; break; }
    }
    if (match == null) {
      final map = budget.toDb()..remove('id');
      await db.insert('finance_budgets', map);
    } else {
      final map = budget.toDb()..remove('id');
      await db.update('finance_budgets', map, where: 'id = ?', whereArgs: [match.id]);
    }
  }

  Future<void> deleteBudget(int id) async => (await database).delete('finance_budgets', where: 'id = ?', whereArgs: [id]);
  Future<List<FinanceBudget>> getBudgets() async => (await database).query('finance_budgets', orderBy: 'year DESC, month DESC').then((r) => r.map(FinanceBudget.fromDb).toList());

  Future<int> insertGoal(FinanceGoal goal) async { final db = await database; final map = goal.toDb()..remove('id'); return db.insert('finance_goals', map); }
  Future<void> updateGoal(FinanceGoal goal) async { if (goal.id == null) return; final db = await database; final map = goal.toDb()..remove('id'); await db.update('finance_goals', map, where: 'id = ?', whereArgs: [goal.id]); }
  Future<void> deleteGoal(int id) async { final db = await database; await db.delete('finance_goal_contributions', where: 'goalId = ?', whereArgs: [id]); await db.delete('finance_goals', where: 'id = ?', whereArgs: [id]); }
  Future<List<FinanceGoal>> getGoals() async => (await database).query('finance_goals', orderBy: 'completed ASC, id DESC').then((r) => r.map(FinanceGoal.fromDb).toList());
  Future<void> addGoalContribution(FinanceGoalContribution contribution) async {
    final db = await database;
    await db.transaction((txn) async {
      final cm = contribution.toDb()..remove('id');
      await txn.insert('finance_goal_contributions', cm);
      final rows = await txn.query('finance_goals', where: 'id = ?', whereArgs: [contribution.goalId], limit: 1);
      if (rows.isNotEmpty) {
        final goal = FinanceGoal.fromDb(rows.first);
        final saved = (goal.savedAmount + contribution.amount).clamp(0.0, double.infinity).toDouble();
        final updated = FinanceGoal(id: goal.id, name: goal.name, targetAmount: goal.targetAmount, savedAmount: saved, targetDate: goal.targetDate, linkedAccountId: goal.linkedAccountId, notes: goal.notes, completed: saved >= goal.targetAmount && goal.targetAmount > 0);
        final gm = updated.toDb()..remove('id');
        await txn.update('finance_goals', gm, where: 'id = ?', whereArgs: [goal.id]);
      }
    });
  }
  Future<List<FinanceGoalContribution>> getGoalContributions(int goalId) async => (await database).query('finance_goal_contributions', where: 'goalId = ?', whereArgs: [goalId], orderBy: 'date DESC').then((r) => r.map(FinanceGoalContribution.fromDb).toList());

  Future<int> insertRecurring(FinanceRecurringRule rule) async { final db = await database; final map = rule.toDb()..remove('id'); return db.insert('finance_recurring', map); }
  Future<void> updateRecurring(FinanceRecurringRule rule) async { if (rule.id == null) return; final db = await database; final map = rule.toDb()..remove('id'); await db.update('finance_recurring', map, where: 'id = ?', whereArgs: [rule.id]); }
  Future<void> deleteRecurring(int id) async => (await database).delete('finance_recurring', where: 'id = ?', whereArgs: [id]);
  Future<List<FinanceRecurringRule>> getRecurring() async => (await database).query('finance_recurring', orderBy: 'nextRun ASC').then((r) => r.map(FinanceRecurringRule.fromDb).toList());

  DateTime _advance(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily': return date.add(const Duration(days: 1));
      case 'weekly': return date.add(const Duration(days: 7));
      case 'yearly': return DateTime(date.year + 1, date.month, date.day);
      default:
        final nextMonth = date.month == 12 ? 1 : date.month + 1;
        final nextYear = date.month == 12 ? date.year + 1 : date.year;
        final last = DateTime(nextYear, nextMonth + 1, 0).day;
        return DateTime(nextYear, nextMonth, date.day.clamp(1, last).toInt(), date.hour, date.minute);
    }
  }

  Future<int> runRecurringRules() async {
    final rules = await getRecurring();
    final now = DateTime.now();
    int created = 0;
    for (var rule in rules.where((r) => r.enabled)) {
      var next = rule.nextRun;
      int guard = 0;
      while (!next.isAfter(now) && guard < 24) {
        final tx = FinanceTransaction(
          type: rule.transactionType, accountId: rule.accountId, toAccountId: rule.toAccountId,
          amount: rule.amount, category: rule.category, title: rule.name, note: rule.note,
          source: 'recurring', recurringRuleId: rule.id, occurredAt: next, createdAt: DateTime.now(),
        );
        await insertTransaction(tx, rebuild: false);
        created++;
        next = _advance(next, rule.frequency);
        guard++;
      }
      if (next != rule.nextRun) {
        await updateRecurring(FinanceRecurringRule(id: rule.id, name: rule.name, transactionType: rule.transactionType, accountId: rule.accountId, toAccountId: rule.toAccountId, amount: rule.amount, category: rule.category, frequency: rule.frequency, nextRun: next, note: rule.note, enabled: rule.enabled));
      }
    }
    if (created > 0) await rebuildBalances();
    return created;
  }

  Future<void> saveSnapshot(FinanceSnapshot snapshot) async {
    final db = await database;
    final start = DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day).millisecondsSinceEpoch;
    final end = DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day + 1).millisecondsSinceEpoch;
    final existing = await db.query('finance_snapshots', where: 'date >= ? AND date < ?', whereArgs: [start, end], limit: 1);
    final map = snapshot.toDb()..remove('id');
    if (existing.isEmpty) {
      await db.insert('finance_snapshots', map);
    } else {
      await db.update('finance_snapshots', map, where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<List<FinanceSnapshot>> getSnapshots({int limit = 120}) async => (await database).query('finance_snapshots', orderBy: 'date ASC', limit: limit).then((r) => r.map(FinanceSnapshot.fromDb).toList());

  Future<Map<String, dynamic>> exportAll() async {
    return {
      'accounts': (await getAccounts(includeArchived: true)).map((e) => e.toBackup()).toList(),
      'transactions': (await getTransactions()).map((e) => e.toBackup()).toList(),
      'people': (await getPeople()).map((e) => e.toBackup()).toList(),
      'debts': (await getDebts()).map((e) => e.toBackup()).toList(),
      'debtPayments': await _allDebtPaymentsBackup(),
      'installments': await _allInstallmentsBackup(),
      'budgets': (await getBudgets()).map((e) => e.toBackup()).toList(),
      'goals': (await getGoals()).map((e) => e.toBackup()).toList(),
      'goalContributions': await _allGoalContributionsBackup(),
      'recurring': (await getRecurring()).map((e) => e.toBackup()).toList(),
      'snapshots': (await getSnapshots(limit: 10000)).map((e) => e.toBackup()).toList(),
    };
  }

  Future<List<Map<String,dynamic>>> _allInstallmentsBackup() async { final rows=await (await database).query('finance_installments'); return rows.map(FinanceInstallment.fromDb).map((e)=>e.toBackup()).toList(); }

  Future<List<Map<String, dynamic>>> _allDebtPaymentsBackup() async {
    final rows = await (await database).query('finance_debt_payments');
    return rows.map(FinanceDebtPayment.fromDb).map((e) => e.toBackup()).toList();
  }
  Future<List<Map<String, dynamic>>> _allGoalContributionsBackup() async {
    final rows = await (await database).query('finance_goal_contributions');
    return rows.map(FinanceGoalContribution.fromDb).map((e) => e.toBackup()).toList();
  }

  Future<List<String>> encryptedAttachmentPaths() async {
    final paths = <String>{};
    for (final tx in await getTransactions()) { if (tx.attachmentPath.isNotEmpty) paths.add(tx.attachmentPath); }
    for (final debt in await getDebts()) { paths.addAll(debt.proofPaths.where((e) => e.isNotEmpty)); }
    final paymentRows = await (await database).query('finance_debt_payments');
    for (final row in paymentRows) { final pth = row['proofPath']?.toString() ?? ''; if (pth.isNotEmpty) paths.add(pth); }
    return paths.toList();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in ['finance_transactions','finance_debt_payments','finance_installments','finance_debts','finance_people','finance_budgets','finance_goal_contributions','finance_goals','finance_recurring','finance_snapshots','finance_accounts']) {
        await txn.delete(table);
      }
    });
  }

  Future<void> importAll(Map<String, dynamic> data, {Map<String, String>? attachmentPathMap}) async {
    await clearAll();
    final db = await database;
    String remap(String raw) => attachmentPathMap?[raw] ?? raw;
    await db.transaction((txn) async {
      for (final raw in (data['accounts'] as List? ?? const [])) { final item = FinanceAccount.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_accounts', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final raw in (data['people'] as List? ?? const [])) { final item = FinancePerson.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_people', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final raw in (data['debts'] as List? ?? const [])) {
        final original = FinanceDebt.fromBackup(Map<String,dynamic>.from(raw));
        final item = FinanceDebt(id: original.id, kind: original.kind, name: original.name, personId: original.personId, accountId: original.accountId, provider: original.provider, principal: original.principal, totalDue: original.totalDue, remaining: original.remaining, interestAmount: original.interestAmount, adminFee: original.adminFee, startDate: original.startDate, dueDate: original.dueDate, status: original.status, notes: original.notes, proofPaths: original.proofPaths.map(remap).toList(), createdAt: original.createdAt);
        await txn.insert('finance_debts', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final raw in (data['transactions'] as List? ?? const [])) {
        final original = FinanceTransaction.fromBackup(Map<String,dynamic>.from(raw));
        final item = FinanceTransaction(id: original.id, type: original.type, accountId: original.accountId, toAccountId: original.toAccountId, amount: original.amount, category: original.category, title: original.title, merchant: original.merchant, note: original.note, tags: original.tags, source: original.source, attachmentPath: remap(original.attachmentPath), reference: original.reference, personId: original.personId, debtId: original.debtId, recurringRuleId: original.recurringRuleId, isDraft: original.isDraft, occurredAt: original.occurredAt, createdAt: original.createdAt);
        await txn.insert('finance_transactions', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final raw in (data['debtPayments'] as List? ?? const [])) {
        final original = FinanceDebtPayment.fromBackup(Map<String,dynamic>.from(raw));
        final item = FinanceDebtPayment(id: original.id, debtId: original.debtId, accountId: original.accountId, amount: original.amount, paidAt: original.paidAt, note: original.note, proofPath: remap(original.proofPath));
        await txn.insert('finance_debt_payments', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final raw in (data['installments'] as List? ?? const [])) { final item=FinanceInstallment.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_installments',item.toDb(),conflictAlgorithm:ConflictAlgorithm.replace); }
      for (final raw in (data['budgets'] as List? ?? const [])) { final item = FinanceBudget.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_budgets', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final raw in (data['goals'] as List? ?? const [])) { final item = FinanceGoal.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_goals', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final raw in (data['goalContributions'] as List? ?? const [])) { final item = FinanceGoalContribution.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_goal_contributions', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final raw in (data['recurring'] as List? ?? const [])) { final item = FinanceRecurringRule.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_recurring', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final raw in (data['snapshots'] as List? ?? const [])) { final item = FinanceSnapshot.fromBackup(Map<String,dynamic>.from(raw)); await txn.insert('finance_snapshots', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace); }
    });
    await rebuildBalances();
  }

  Future<void> _deleteEncryptedFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try { final file = File(path); if (await file.exists()) await file.delete(); } catch (_) {}
  }
}
