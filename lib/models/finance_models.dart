import 'dart:convert';
import 'package:wallet/services/encryption_service.dart';

class FinanceFormat {
  static double parseMoney(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    var raw = value.toString().trim();
    if (raw.isEmpty) return 0;
    raw = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (raw.contains(',') && raw.contains('.')) {
      if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
    } else if (raw.contains(',')) {
      final parts = raw.split(',');
      if (parts.last.length <= 2) {
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
    } else if (raw.contains('.')) {
      final parts = raw.split('.');
      if (parts.length > 2 || parts.last.length == 3) raw = raw.replaceAll('.', '');
    }
    return double.tryParse(raw) ?? 0;
  }

  static String rupiah(num value, {bool compact = false}) {
    final negative = value < 0;
    final n = value.abs().round();
    if (compact) {
      if (n >= 1000000000) return '${negative ? '-' : ''}Rp ${(n / 1000000000).toStringAsFixed(n % 1000000000 == 0 ? 0 : 1)} M';
      if (n >= 1000000) return '${negative ? '-' : ''}Rp ${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)} jt';
      if (n >= 1000) return '${negative ? '-' : ''}Rp ${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)} rb';
    }
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '${negative ? '-' : ''}Rp ${buffer.toString()}';
  }

  static String date(DateTime? value) {
    if (value == null) return '-';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
  }

  static String dateShort(DateTime? value) {
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class FinanceCrypto {
  static String enc(String value) => EncryptionService.instance.encryptText(value) ?? '';
  static String dec(dynamic value) => EncryptionService.instance.decryptText(value?.toString()) ?? '';
  static String encDouble(double value) => enc(value.toStringAsFixed(2));
  static double decDouble(dynamic value) => double.tryParse(dec(value)) ?? 0;
  static String encJson(Object value) => enc(jsonEncode(value));
  static dynamic decJson(dynamic value, dynamic fallback) {
    try {
      final raw = dec(value);
      if (raw.isEmpty) return fallback;
      return jsonDecode(raw);
    } catch (_) {
      return fallback;
    }
  }
}

class FinanceAccount {
  final int? id;
  final String name;
  final String type;
  final String institution;
  final double openingBalance;
  final double currentBalance;
  final double creditLimit;
  final int? statementDay;
  final int? dueDay;
  final String notes;
  final int? linkedWalletId;
  final bool includeNetWorth;
  final bool archived;
  final String colorHex;
  final DateTime createdAt;

  const FinanceAccount({
    this.id,
    required this.name,
    this.type = 'bank',
    this.institution = '',
    this.openingBalance = 0,
    this.currentBalance = 0,
    this.creditLimit = 0,
    this.statementDay,
    this.dueDay,
    this.notes = '',
    this.linkedWalletId,
    this.includeNetWorth = true,
    this.archived = false,
    this.colorHex = '',
    required this.createdAt,
  });

  bool get isLiability => const {'credit_card', 'paylater', 'loan'}.contains(type);
  bool get isCash => const {'cash', 'safe', 'drawer', 'coins', 'wallet_cash'}.contains(type);
  double get availableLimit => creditLimit <= 0 ? 0 : (creditLimit - currentBalance).clamp(0.0, creditLimit).toDouble();

  FinanceAccount copyWith({
    int? id,
    String? name,
    String? type,
    String? institution,
    double? openingBalance,
    double? currentBalance,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
    String? notes,
    int? linkedWalletId,
    bool? includeNetWorth,
    bool? archived,
    String? colorHex,
    DateTime? createdAt,
  }) => FinanceAccount(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    institution: institution ?? this.institution,
    openingBalance: openingBalance ?? this.openingBalance,
    currentBalance: currentBalance ?? this.currentBalance,
    creditLimit: creditLimit ?? this.creditLimit,
    statementDay: statementDay ?? this.statementDay,
    dueDay: dueDay ?? this.dueDay,
    notes: notes ?? this.notes,
    linkedWalletId: linkedWalletId ?? this.linkedWalletId,
    includeNetWorth: includeNetWorth ?? this.includeNetWorth,
    archived: archived ?? this.archived,
    colorHex: colorHex ?? this.colorHex,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toDb() => {
    'id': id,
    'name': FinanceCrypto.enc(name),
    'type': type,
    'institution': FinanceCrypto.enc(institution),
    'openingBalance': FinanceCrypto.encDouble(openingBalance),
    'currentBalance': FinanceCrypto.encDouble(currentBalance),
    'creditLimit': FinanceCrypto.encDouble(creditLimit),
    'statementDay': statementDay,
    'dueDay': dueDay,
    'notes': FinanceCrypto.enc(notes),
    'linkedWalletId': linkedWalletId,
    'includeNetWorth': includeNetWorth ? 1 : 0,
    'archived': archived ? 1 : 0,
    'colorHex': colorHex,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic> toBackup() => {
    'id': id, 'name': name, 'type': type, 'institution': institution,
    'openingBalance': openingBalance, 'currentBalance': currentBalance,
    'creditLimit': creditLimit, 'statementDay': statementDay, 'dueDay': dueDay,
    'notes': notes, 'linkedWalletId': linkedWalletId, 'includeNetWorth': includeNetWorth,
    'archived': archived, 'colorHex': colorHex, 'createdAt': createdAt.toIso8601String(),
  };

  factory FinanceAccount.fromDb(Map<String, dynamic> m) => FinanceAccount(
    id: m['id'] as int?,
    name: FinanceCrypto.dec(m['name']),
    type: m['type']?.toString() ?? 'bank',
    institution: FinanceCrypto.dec(m['institution']),
    openingBalance: FinanceCrypto.decDouble(m['openingBalance']),
    currentBalance: FinanceCrypto.decDouble(m['currentBalance']),
    creditLimit: FinanceCrypto.decDouble(m['creditLimit']),
    statementDay: m['statementDay'] as int?,
    dueDay: m['dueDay'] as int?,
    notes: FinanceCrypto.dec(m['notes']),
    linkedWalletId: m['linkedWalletId'] as int?,
    includeNetWorth: (m['includeNetWorth'] as int? ?? 1) == 1,
    archived: (m['archived'] as int? ?? 0) == 1,
    colorHex: m['colorHex']?.toString() ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int? ?? 0),
  );

  factory FinanceAccount.fromBackup(Map<String, dynamic> m) => FinanceAccount(
    id: m['id'] as int?, name: m['name']?.toString() ?? '', type: m['type']?.toString() ?? 'bank',
    institution: m['institution']?.toString() ?? '', openingBalance: FinanceFormat.parseMoney(m['openingBalance']),
    currentBalance: FinanceFormat.parseMoney(m['currentBalance']), creditLimit: FinanceFormat.parseMoney(m['creditLimit']),
    statementDay: m['statementDay'] as int?, dueDay: m['dueDay'] as int?, notes: m['notes']?.toString() ?? '',
    linkedWalletId: m['linkedWalletId'] as int?, includeNetWorth: m['includeNetWorth'] != false,
    archived: m['archived'] == true, colorHex: m['colorHex']?.toString() ?? '',
    createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class FinanceTransaction {
  final int? id;
  final String type;
  final int? accountId;
  final int? toAccountId;
  final double amount;
  final String category;
  final String title;
  final String merchant;
  final String note;
  final String tags;
  final String source;
  final String attachmentPath;
  final String reference;
  final int? personId;
  final int? debtId;
  final int? recurringRuleId;
  final bool isDraft;
  final DateTime occurredAt;
  final DateTime createdAt;

  const FinanceTransaction({
    this.id,
    required this.type,
    this.accountId,
    this.toAccountId,
    required this.amount,
    this.category = '',
    this.title = '',
    this.merchant = '',
    this.note = '',
    this.tags = '',
    this.source = 'manual',
    this.attachmentPath = '',
    this.reference = '',
    this.personId,
    this.debtId,
    this.recurringRuleId,
    this.isDraft = false,
    required this.occurredAt,
    required this.createdAt,
  });

  Map<String, dynamic> toDb() => {
    'id': id, 'type': type, 'accountId': accountId, 'toAccountId': toAccountId,
    'amount': FinanceCrypto.encDouble(amount), 'category': FinanceCrypto.enc(category),
    'title': FinanceCrypto.enc(title), 'merchant': FinanceCrypto.enc(merchant), 'note': FinanceCrypto.enc(note),
    'tags': FinanceCrypto.enc(tags), 'source': source, 'attachmentPath': attachmentPath,
    'reference': FinanceCrypto.enc(reference), 'personId': personId, 'debtId': debtId,
    'recurringRuleId': recurringRuleId, 'isDraft': isDraft ? 1 : 0,
    'occurredAt': occurredAt.millisecondsSinceEpoch, 'createdAt': createdAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic> toBackup() => {
    'id': id, 'type': type, 'accountId': accountId, 'toAccountId': toAccountId, 'amount': amount,
    'category': category, 'title': title, 'merchant': merchant, 'note': note, 'tags': tags, 'source': source,
    'attachmentPath': attachmentPath, 'reference': reference, 'personId': personId, 'debtId': debtId,
    'recurringRuleId': recurringRuleId, 'isDraft': isDraft, 'occurredAt': occurredAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory FinanceTransaction.fromDb(Map<String, dynamic> m) => FinanceTransaction(
    id: m['id'] as int?, type: m['type']?.toString() ?? 'expense', accountId: m['accountId'] as int?,
    toAccountId: m['toAccountId'] as int?, amount: FinanceCrypto.decDouble(m['amount']),
    category: FinanceCrypto.dec(m['category']), title: FinanceCrypto.dec(m['title']), merchant: FinanceCrypto.dec(m['merchant']),
    note: FinanceCrypto.dec(m['note']), tags: FinanceCrypto.dec(m['tags']), source: m['source']?.toString() ?? 'manual',
    attachmentPath: m['attachmentPath']?.toString() ?? '', reference: FinanceCrypto.dec(m['reference']),
    personId: m['personId'] as int?, debtId: m['debtId'] as int?, recurringRuleId: m['recurringRuleId'] as int?,
    isDraft: (m['isDraft'] as int? ?? 0) == 1,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(m['occurredAt'] as int? ?? 0),
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int? ?? 0),
  );

  factory FinanceTransaction.fromBackup(Map<String, dynamic> m) => FinanceTransaction(
    id: m['id'] as int?, type: m['type']?.toString() ?? 'expense', accountId: m['accountId'] as int?,
    toAccountId: m['toAccountId'] as int?, amount: FinanceFormat.parseMoney(m['amount']), category: m['category']?.toString() ?? '',
    title: m['title']?.toString() ?? '', merchant: m['merchant']?.toString() ?? '', note: m['note']?.toString() ?? '',
    tags: m['tags']?.toString() ?? '', source: m['source']?.toString() ?? 'manual', attachmentPath: m['attachmentPath']?.toString() ?? '',
    reference: m['reference']?.toString() ?? '', personId: m['personId'] as int?, debtId: m['debtId'] as int?,
    recurringRuleId: m['recurringRuleId'] as int?, isDraft: m['isDraft'] == true,
    occurredAt: DateTime.tryParse(m['occurredAt']?.toString() ?? '') ?? DateTime.now(),
    createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class FinancePerson {
  final int? id;
  final String name;
  final String phone;
  final String notes;
  final DateTime createdAt;
  const FinancePerson({this.id, required this.name, this.phone = '', this.notes = '', required this.createdAt});
  Map<String, dynamic> toDb() => {'id': id, 'name': FinanceCrypto.enc(name), 'phone': FinanceCrypto.enc(phone), 'notes': FinanceCrypto.enc(notes), 'createdAt': createdAt.millisecondsSinceEpoch};
  Map<String, dynamic> toBackup() => {'id': id, 'name': name, 'phone': phone, 'notes': notes, 'createdAt': createdAt.toIso8601String()};
  factory FinancePerson.fromDb(Map<String, dynamic> m) => FinancePerson(id: m['id'] as int?, name: FinanceCrypto.dec(m['name']), phone: FinanceCrypto.dec(m['phone']), notes: FinanceCrypto.dec(m['notes']), createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int? ?? 0));
  factory FinancePerson.fromBackup(Map<String, dynamic> m) => FinancePerson(id: m['id'] as int?, name: m['name']?.toString() ?? '', phone: m['phone']?.toString() ?? '', notes: m['notes']?.toString() ?? '', createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now());
}

class FinanceDebt {
  final int? id;
  final String kind;
  final String name;
  final int? personId;
  final int? accountId;
  final String provider;
  final double principal;
  final double totalDue;
  final double remaining;
  final double interestAmount;
  final double adminFee;
  final DateTime startDate;
  final DateTime? dueDate;
  final String status;
  final String notes;
  final List<String> proofPaths;
  final DateTime createdAt;

  const FinanceDebt({
    this.id, required this.kind, required this.name, this.personId, this.accountId, this.provider = '',
    required this.principal, required this.totalDue, required this.remaining, this.interestAmount = 0, this.adminFee = 0,
    required this.startDate, this.dueDate, this.status = 'active', this.notes = '', this.proofPaths = const [], required this.createdAt,
  });

  bool get isReceivable => kind == 'receivable';
  bool get isLiability => !isReceivable;

  Map<String, dynamic> toDb() => {
    'id': id, 'kind': kind, 'name': FinanceCrypto.enc(name), 'personId': personId, 'accountId': accountId,
    'provider': FinanceCrypto.enc(provider), 'principal': FinanceCrypto.encDouble(principal), 'totalDue': FinanceCrypto.encDouble(totalDue),
    'remaining': FinanceCrypto.encDouble(remaining), 'interestAmount': FinanceCrypto.encDouble(interestAmount), 'adminFee': FinanceCrypto.encDouble(adminFee),
    'startDate': startDate.millisecondsSinceEpoch, 'dueDate': dueDate?.millisecondsSinceEpoch, 'status': status,
    'notes': FinanceCrypto.enc(notes), 'proofPaths': FinanceCrypto.encJson(proofPaths), 'createdAt': createdAt.millisecondsSinceEpoch,
  };
  Map<String, dynamic> toBackup() => {
    'id': id, 'kind': kind, 'name': name, 'personId': personId, 'accountId': accountId, 'provider': provider,
    'principal': principal, 'totalDue': totalDue, 'remaining': remaining, 'interestAmount': interestAmount, 'adminFee': adminFee,
    'startDate': startDate.toIso8601String(), 'dueDate': dueDate?.toIso8601String(), 'status': status, 'notes': notes,
    'proofPaths': proofPaths, 'createdAt': createdAt.toIso8601String(),
  };
  factory FinanceDebt.fromDb(Map<String, dynamic> m) => FinanceDebt(
    id: m['id'] as int?, kind: m['kind']?.toString() ?? 'payable', name: FinanceCrypto.dec(m['name']), personId: m['personId'] as int?, accountId: m['accountId'] as int?,
    provider: FinanceCrypto.dec(m['provider']), principal: FinanceCrypto.decDouble(m['principal']), totalDue: FinanceCrypto.decDouble(m['totalDue']), remaining: FinanceCrypto.decDouble(m['remaining']),
    interestAmount: FinanceCrypto.decDouble(m['interestAmount']), adminFee: FinanceCrypto.decDouble(m['adminFee']),
    startDate: DateTime.fromMillisecondsSinceEpoch(m['startDate'] as int? ?? 0), dueDate: m['dueDate'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['dueDate'] as int),
    status: m['status']?.toString() ?? 'active', notes: FinanceCrypto.dec(m['notes']), proofPaths: List<String>.from(FinanceCrypto.decJson(m['proofPaths'], const <String>[]) as List),
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int? ?? 0),
  );
  factory FinanceDebt.fromBackup(Map<String, dynamic> m) => FinanceDebt(
    id: m['id'] as int?, kind: m['kind']?.toString() ?? 'payable', name: m['name']?.toString() ?? '', personId: m['personId'] as int?, accountId: m['accountId'] as int?, provider: m['provider']?.toString() ?? '',
    principal: FinanceFormat.parseMoney(m['principal']), totalDue: FinanceFormat.parseMoney(m['totalDue']), remaining: FinanceFormat.parseMoney(m['remaining']),
    interestAmount: FinanceFormat.parseMoney(m['interestAmount']), adminFee: FinanceFormat.parseMoney(m['adminFee']), startDate: DateTime.tryParse(m['startDate']?.toString() ?? '') ?? DateTime.now(),
    dueDate: DateTime.tryParse(m['dueDate']?.toString() ?? ''), status: m['status']?.toString() ?? 'active', notes: m['notes']?.toString() ?? '',
    proofPaths: List<String>.from((m['proofPaths'] as List?) ?? const []), createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class FinanceDebtPayment {
  final int? id;
  final int debtId;
  final int? accountId;
  final double amount;
  final DateTime paidAt;
  final String note;
  final String proofPath;
  const FinanceDebtPayment({this.id, required this.debtId, this.accountId, required this.amount, required this.paidAt, this.note = '', this.proofPath = ''});
  Map<String, dynamic> toDb() => {'id': id, 'debtId': debtId, 'accountId': accountId, 'amount': FinanceCrypto.encDouble(amount), 'paidAt': paidAt.millisecondsSinceEpoch, 'note': FinanceCrypto.enc(note), 'proofPath': proofPath};
  Map<String, dynamic> toBackup() => {'id': id, 'debtId': debtId, 'accountId': accountId, 'amount': amount, 'paidAt': paidAt.toIso8601String(), 'note': note, 'proofPath': proofPath};
  factory FinanceDebtPayment.fromDb(Map<String, dynamic> m) => FinanceDebtPayment(id: m['id'] as int?, debtId: m['debtId'] as int, accountId: m['accountId'] as int?, amount: FinanceCrypto.decDouble(m['amount']), paidAt: DateTime.fromMillisecondsSinceEpoch(m['paidAt'] as int? ?? 0), note: FinanceCrypto.dec(m['note']), proofPath: m['proofPath']?.toString() ?? '');
  factory FinanceDebtPayment.fromBackup(Map<String, dynamic> m) => FinanceDebtPayment(id: m['id'] as int?, debtId: m['debtId'] as int, accountId: m['accountId'] as int?, amount: FinanceFormat.parseMoney(m['amount']), paidAt: DateTime.tryParse(m['paidAt']?.toString() ?? '') ?? DateTime.now(), note: m['note']?.toString() ?? '', proofPath: m['proofPath']?.toString() ?? '');
}

class FinanceBudget {
  final int? id;
  final String category;
  final int year;
  final int month;
  final double amount;
  const FinanceBudget({this.id, required this.category, required this.year, required this.month, required this.amount});
  Map<String, dynamic> toDb() => {'id': id, 'category': FinanceCrypto.enc(category), 'year': year, 'month': month, 'amount': FinanceCrypto.encDouble(amount)};
  Map<String, dynamic> toBackup() => {'id': id, 'category': category, 'year': year, 'month': month, 'amount': amount};
  factory FinanceBudget.fromDb(Map<String, dynamic> m) => FinanceBudget(id: m['id'] as int?, category: FinanceCrypto.dec(m['category']), year: m['year'] as int, month: m['month'] as int, amount: FinanceCrypto.decDouble(m['amount']));
  factory FinanceBudget.fromBackup(Map<String, dynamic> m) => FinanceBudget(id: m['id'] as int?, category: m['category']?.toString() ?? '', year: m['year'] as int, month: m['month'] as int, amount: FinanceFormat.parseMoney(m['amount']));
}

class FinanceGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final int? linkedAccountId;
  final String notes;
  final bool completed;
  const FinanceGoal({this.id, required this.name, required this.targetAmount, this.savedAmount = 0, this.targetDate, this.linkedAccountId, this.notes = '', this.completed = false});
  double get progress => targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0).toDouble();
  Map<String, dynamic> toDb() => {'id': id, 'name': FinanceCrypto.enc(name), 'targetAmount': FinanceCrypto.encDouble(targetAmount), 'savedAmount': FinanceCrypto.encDouble(savedAmount), 'targetDate': targetDate?.millisecondsSinceEpoch, 'linkedAccountId': linkedAccountId, 'notes': FinanceCrypto.enc(notes), 'completed': completed ? 1 : 0};
  Map<String, dynamic> toBackup() => {'id': id, 'name': name, 'targetAmount': targetAmount, 'savedAmount': savedAmount, 'targetDate': targetDate?.toIso8601String(), 'linkedAccountId': linkedAccountId, 'notes': notes, 'completed': completed};
  factory FinanceGoal.fromDb(Map<String, dynamic> m) => FinanceGoal(id: m['id'] as int?, name: FinanceCrypto.dec(m['name']), targetAmount: FinanceCrypto.decDouble(m['targetAmount']), savedAmount: FinanceCrypto.decDouble(m['savedAmount']), targetDate: m['targetDate'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['targetDate'] as int), linkedAccountId: m['linkedAccountId'] as int?, notes: FinanceCrypto.dec(m['notes']), completed: (m['completed'] as int? ?? 0) == 1);
  factory FinanceGoal.fromBackup(Map<String, dynamic> m) => FinanceGoal(id: m['id'] as int?, name: m['name']?.toString() ?? '', targetAmount: FinanceFormat.parseMoney(m['targetAmount']), savedAmount: FinanceFormat.parseMoney(m['savedAmount']), targetDate: DateTime.tryParse(m['targetDate']?.toString() ?? ''), linkedAccountId: m['linkedAccountId'] as int?, notes: m['notes']?.toString() ?? '', completed: m['completed'] == true);
}

class FinanceGoalContribution {
  final int? id;
  final int goalId;
  final double amount;
  final DateTime date;
  final String note;
  const FinanceGoalContribution({this.id, required this.goalId, required this.amount, required this.date, this.note = ''});
  Map<String, dynamic> toDb() => {'id': id, 'goalId': goalId, 'amount': FinanceCrypto.encDouble(amount), 'date': date.millisecondsSinceEpoch, 'note': FinanceCrypto.enc(note)};
  Map<String, dynamic> toBackup() => {'id': id, 'goalId': goalId, 'amount': amount, 'date': date.toIso8601String(), 'note': note};
  factory FinanceGoalContribution.fromDb(Map<String, dynamic> m) => FinanceGoalContribution(id: m['id'] as int?, goalId: m['goalId'] as int, amount: FinanceCrypto.decDouble(m['amount']), date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int? ?? 0), note: FinanceCrypto.dec(m['note']));
  factory FinanceGoalContribution.fromBackup(Map<String, dynamic> m) => FinanceGoalContribution(id: m['id'] as int?, goalId: m['goalId'] as int, amount: FinanceFormat.parseMoney(m['amount']), date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(), note: m['note']?.toString() ?? '');
}

class FinanceRecurringRule {
  final int? id;
  final String name;
  final String transactionType;
  final int? accountId;
  final int? toAccountId;
  final double amount;
  final String category;
  final String frequency;
  final DateTime nextRun;
  final String note;
  final bool enabled;
  const FinanceRecurringRule({this.id, required this.name, required this.transactionType, this.accountId, this.toAccountId, required this.amount, this.category = '', this.frequency = 'monthly', required this.nextRun, this.note = '', this.enabled = true});
  Map<String, dynamic> toDb() => {'id': id, 'name': FinanceCrypto.enc(name), 'transactionType': transactionType, 'accountId': accountId, 'toAccountId': toAccountId, 'amount': FinanceCrypto.encDouble(amount), 'category': FinanceCrypto.enc(category), 'frequency': frequency, 'nextRun': nextRun.millisecondsSinceEpoch, 'note': FinanceCrypto.enc(note), 'enabled': enabled ? 1 : 0};
  Map<String, dynamic> toBackup() => {'id': id, 'name': name, 'transactionType': transactionType, 'accountId': accountId, 'toAccountId': toAccountId, 'amount': amount, 'category': category, 'frequency': frequency, 'nextRun': nextRun.toIso8601String(), 'note': note, 'enabled': enabled};
  factory FinanceRecurringRule.fromDb(Map<String, dynamic> m) => FinanceRecurringRule(id: m['id'] as int?, name: FinanceCrypto.dec(m['name']), transactionType: m['transactionType']?.toString() ?? 'expense', accountId: m['accountId'] as int?, toAccountId: m['toAccountId'] as int?, amount: FinanceCrypto.decDouble(m['amount']), category: FinanceCrypto.dec(m['category']), frequency: m['frequency']?.toString() ?? 'monthly', nextRun: DateTime.fromMillisecondsSinceEpoch(m['nextRun'] as int? ?? 0), note: FinanceCrypto.dec(m['note']), enabled: (m['enabled'] as int? ?? 1) == 1);
  factory FinanceRecurringRule.fromBackup(Map<String, dynamic> m) => FinanceRecurringRule(id: m['id'] as int?, name: m['name']?.toString() ?? '', transactionType: m['transactionType']?.toString() ?? 'expense', accountId: m['accountId'] as int?, toAccountId: m['toAccountId'] as int?, amount: FinanceFormat.parseMoney(m['amount']), category: m['category']?.toString() ?? '', frequency: m['frequency']?.toString() ?? 'monthly', nextRun: DateTime.tryParse(m['nextRun']?.toString() ?? '') ?? DateTime.now(), note: m['note']?.toString() ?? '', enabled: m['enabled'] != false);
}

class FinanceSnapshot {
  final int? id;
  final DateTime date;
  final double assets;
  final double liabilities;
  final double receivables;
  final double netWorth;
  const FinanceSnapshot({this.id, required this.date, required this.assets, required this.liabilities, required this.receivables, required this.netWorth});
  Map<String, dynamic> toDb() => {'id': id, 'date': date.millisecondsSinceEpoch, 'assets': FinanceCrypto.encDouble(assets), 'liabilities': FinanceCrypto.encDouble(liabilities), 'receivables': FinanceCrypto.encDouble(receivables), 'netWorth': FinanceCrypto.encDouble(netWorth)};
  Map<String, dynamic> toBackup() => {'id': id, 'date': date.toIso8601String(), 'assets': assets, 'liabilities': liabilities, 'receivables': receivables, 'netWorth': netWorth};
  factory FinanceSnapshot.fromDb(Map<String, dynamic> m) => FinanceSnapshot(id: m['id'] as int?, date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int? ?? 0), assets: FinanceCrypto.decDouble(m['assets']), liabilities: FinanceCrypto.decDouble(m['liabilities']), receivables: FinanceCrypto.decDouble(m['receivables']), netWorth: FinanceCrypto.decDouble(m['netWorth']));
  factory FinanceSnapshot.fromBackup(Map<String, dynamic> m) => FinanceSnapshot(id: m['id'] as int?, date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(), assets: FinanceFormat.parseMoney(m['assets']), liabilities: FinanceFormat.parseMoney(m['liabilities']), receivables: FinanceFormat.parseMoney(m['receivables']), netWorth: FinanceFormat.parseMoney(m['netWorth']));
}

class FinanceNotificationDraft {
  final String id;
  final String packageName;
  final String title;
  final String body;
  final DateTime time;
  final double amount;
  final String suggestedType;
  const FinanceNotificationDraft({required this.id, required this.packageName, required this.title, required this.body, required this.time, required this.amount, required this.suggestedType});
  factory FinanceNotificationDraft.fromNative(Map<dynamic, dynamic> m) {
    final title = m['title']?.toString() ?? '';
    final body = m['body']?.toString() ?? '';
    final all = '$title $body';
    final amount = _extractRupiah(all);
    final lower = all.toLowerCase();
    final income = lower.contains('kredit') || lower.contains('masuk') || lower.contains('diterima') || lower.contains('received') || lower.contains('refund');
    return FinanceNotificationDraft(id: m['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(), packageName: m['package']?.toString() ?? '', title: title, body: body, time: DateTime.fromMillisecondsSinceEpoch(int.tryParse(m['time']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch), amount: amount, suggestedType: income ? 'income' : 'expense');
  }
  static double _extractRupiah(String value) {
    final matches = RegExp(r'(?:rp\.?\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+(?:,[0-9]{1,2})?|[0-9]{4,})', caseSensitive: false).allMatches(value).toList();
    if (matches.isEmpty) return 0;
    return matches.map((m) => FinanceFormat.parseMoney(m.group(1))).fold<double>(0, (a, b) => b > a ? b : a);
  }
}

const financeExpenseCategories = <String>[
  'Makan & Minum', 'Belanja', 'Transportasi', 'BBM', 'Tagihan', 'Cicilan',
  'Kesehatan', 'Pendidikan', 'Hiburan', 'Rumah', 'Keluarga', 'Sedekah',
  'Usaha', 'Pajak & Administrasi', 'Lainnya',
];

const financeIncomeCategories = <String>[
  'Gaji', 'Penjualan', 'Bonus', 'Komisi', 'Refund', 'Piutang Dibayar',
  'Hadiah', 'Bunga', 'Lainnya',
];

const financeAccountTypes = <String, String>{
  'bank': 'Rekening Bank',
  'ewallet': 'E-Wallet',
  'cash': 'Cash / Dompet',
  'safe': 'Brankas',
  'drawer': 'Laci / Kas',
  'coins': 'Uang Receh',
  'debit_card': 'Kartu Debit',
  'credit_card': 'Kartu Kredit',
  'paylater': 'PayLater',
  'loan': 'Pinjaman / Pinjol',
  'other': 'Lainnya',
};

class FinanceInstallment {
  final int? id;
  final int debtId;
  final String label;
  final double amount;
  final DateTime dueDate;
  final bool paid;
  final DateTime? paidAt;
  const FinanceInstallment({this.id, required this.debtId, required this.label, required this.amount, required this.dueDate, this.paid = false, this.paidAt});
  Map<String,dynamic> toDb()=>{'id':id,'debtId':debtId,'label':FinanceCrypto.enc(label),'amount':FinanceCrypto.encDouble(amount),'dueDate':dueDate.millisecondsSinceEpoch,'paid':paid?1:0,'paidAt':paidAt?.millisecondsSinceEpoch};
  Map<String,dynamic> toBackup()=>{'id':id,'debtId':debtId,'label':label,'amount':amount,'dueDate':dueDate.toIso8601String(),'paid':paid,'paidAt':paidAt?.toIso8601String()};
  factory FinanceInstallment.fromDb(Map<String,dynamic> m)=>FinanceInstallment(id:m['id'] as int?,debtId:m['debtId'] as int,label:FinanceCrypto.dec(m['label']),amount:FinanceCrypto.decDouble(m['amount']),dueDate:DateTime.fromMillisecondsSinceEpoch(m['dueDate'] as int? ?? 0),paid:(m['paid'] as int? ?? 0)==1,paidAt:m['paidAt']==null?null:DateTime.fromMillisecondsSinceEpoch(m['paidAt'] as int));
  factory FinanceInstallment.fromBackup(Map<String,dynamic> m)=>FinanceInstallment(id:m['id'] as int?,debtId:m['debtId'] as int,label:m['label']?.toString()??'',amount:FinanceFormat.parseMoney(m['amount']),dueDate:DateTime.tryParse(m['dueDate']?.toString()??'')??DateTime.now(),paid:m['paid']==true,paidAt:DateTime.tryParse(m['paidAt']?.toString()??''));
}
