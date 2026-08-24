import 'package:wallet/services/encryption_service.dart';

class IdentityCard {
  final int? id;
  final String name;
  final String value;
  final String cardType; // e.g., Passport, License, etc.
  final String? frontImagePath;
  final String? backImagePath;
  final String? color;
  final String? category;
  final String displayMode;
  int orderIndex;

  IdentityCard({
    this.id,
    required this.name,
    required this.value,
    this.cardType = 'Identity Card',
    this.frontImagePath,
    this.backImagePath,
    this.color,
    this.category,
    this.displayMode = 'generated',
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'cardType': cardType,
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'color': color,
      'category': category,
      'displayMode': displayMode,
      'orderIndex': orderIndex,
    };
  }

  Map<String, dynamic> toEncryptedMap() {
    final enc = EncryptionService.instance;
    return {
      'id': id,
      'name': enc.encryptText(name),
      'value': enc.encryptText(value),
      'cardType': enc.encryptText(cardType),
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'color': color,
      'category': enc.encryptText(category),
      'displayMode': enc.encryptText(displayMode),
      'orderIndex': orderIndex,
    };
  }

  factory IdentityCard.fromMap(Map<String, dynamic> map) {
    return IdentityCard(
      id: map['id'],
      name: map['name'],
      value: map['value'],
      cardType: map['cardType'] ?? 'Identity Card',
      frontImagePath: map['frontImagePath'],
      backImagePath: map['backImagePath'],
      color: map['color'],
      category: map['category'],
      displayMode: map['displayMode'] ?? ((map['frontImagePath'] as String?)?.isNotEmpty == true ? 'photo' : 'generated'),
      orderIndex: map['orderIndex'] ?? 0,
    );
  }

  factory IdentityCard.fromEncryptedMap(Map<String, dynamic> map) {
    final enc = EncryptionService.instance;
    return IdentityCard(
      id: map['id'],
      name: enc.decryptText(map['name']) ?? '',
      value: enc.decryptText(map['value']) ?? '',
      cardType: enc.decryptText(map['cardType']) ?? 'Identity Card',
      frontImagePath: map['frontImagePath'],
      backImagePath: map['backImagePath'],
      color: map['color'],
      category: enc.decryptText(map['category']),
      displayMode: enc.decryptText(map['displayMode']) ?? ((map['frontImagePath'] as String?)?.isNotEmpty == true ? 'photo' : 'generated'),
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
}
