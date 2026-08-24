import 'package:wallet/services/encryption_service.dart';

class EWalletAccount {
  final int? id;
  final String provider;
  final String accountName;
  final String phoneNumber;
  final String balance;
  final String limit;
  final String notes;
  final String? logoImagePath;
  int orderIndex;

  EWalletAccount({
    this.id,
    required this.provider,
    this.accountName = '',
    this.phoneNumber = '',
    this.balance = '',
    this.limit = '',
    this.notes = '',
    this.logoImagePath,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'provider': provider,
        'accountName': accountName,
        'phoneNumber': phoneNumber,
        'balance': balance,
        'limitAmount': limit,
        'notes': notes,
        'logoImagePath': logoImagePath,
        'orderIndex': orderIndex,
      };

  factory EWalletAccount.fromMap(Map<String, dynamic> map) => EWalletAccount(
        id: map['id'] as int?,
        provider: map['provider']?.toString() ?? '',
        accountName: map['accountName']?.toString() ?? '',
        phoneNumber: map['phoneNumber']?.toString() ?? '',
        balance: map['balance']?.toString() ?? '',
        limit: map['limitAmount']?.toString() ?? '',
        notes: map['notes']?.toString() ?? '',
        logoImagePath: map['logoImagePath']?.toString(),
        orderIndex: int.tryParse(map['orderIndex']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toEncryptedMap() {
    final enc = EncryptionService.instance;
    return {
      'id': id,
      'provider': enc.encryptText(provider),
      'accountName': enc.encryptText(accountName),
      'phoneNumber': enc.encryptText(phoneNumber),
      'balance': enc.encryptText(balance),
      'limitAmount': enc.encryptText(limit),
      'notes': enc.encryptText(notes),
      'logoImagePath': logoImagePath,
      'orderIndex': orderIndex,
    };
  }

  factory EWalletAccount.fromEncryptedMap(Map<String, dynamic> map) {
    final enc = EncryptionService.instance;
    return EWalletAccount(
      id: map['id'] as int?,
      provider: enc.decryptText(map['provider']) ?? '',
      accountName: enc.decryptText(map['accountName']) ?? '',
      phoneNumber: enc.decryptText(map['phoneNumber']) ?? '',
      balance: enc.decryptText(map['balance']) ?? '',
      limit: enc.decryptText(map['limitAmount']) ?? '',
      notes: enc.decryptText(map['notes']) ?? '',
      logoImagePath: map['logoImagePath'] as String?,
      orderIndex: map['orderIndex'] as int? ?? 0,
    );
  }
}
