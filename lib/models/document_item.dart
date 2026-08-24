import 'package:wallet/services/encryption_service.dart';

class DocumentItem {
  final int? id;
  final String title;
  final String category;
  final String fileName;
  final String fileType;
  final String orientation;
  final String encryptedPath;
  final String notes;
  int orderIndex;

  DocumentItem({
    this.id,
    required this.title,
    this.category = 'Document',
    required this.fileName,
    required this.fileType,
    this.orientation = 'portrait',
    required this.encryptedPath,
    this.notes = '',
    this.orderIndex = 0,
  });

  bool get isImage => ['png', 'jpg', 'jpeg', 'webp'].contains(fileType.toLowerCase());
  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isDocx => fileType.toLowerCase() == 'docx';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'fileName': fileName,
        'fileType': fileType,
        'orientation': orientation,
        'encryptedPath': encryptedPath,
        'notes': notes,
        'orderIndex': orderIndex,
      };

  factory DocumentItem.fromMap(Map<String, dynamic> map) => DocumentItem(
        id: map['id'] as int?,
        title: map['title']?.toString() ?? '',
        category: map['category']?.toString() ?? 'Document',
        fileName: map['fileName']?.toString() ?? '',
        fileType: map['fileType']?.toString() ?? '',
        orientation: map['orientation']?.toString() ?? 'portrait',
        encryptedPath: map['encryptedPath']?.toString() ?? '',
        notes: map['notes']?.toString() ?? '',
        orderIndex: int.tryParse(map['orderIndex']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toEncryptedMap() {
    final enc = EncryptionService.instance;
    return {
      'id': id,
      'title': enc.encryptText(title),
      'category': enc.encryptText(category),
      'fileName': enc.encryptText(fileName),
      'fileType': enc.encryptText(fileType),
      'orientation': enc.encryptText(orientation),
      'encryptedPath': encryptedPath,
      'notes': enc.encryptText(notes),
      'orderIndex': orderIndex,
    };
  }

  factory DocumentItem.fromEncryptedMap(Map<String, dynamic> map) {
    final enc = EncryptionService.instance;
    return DocumentItem(
      id: map['id'] as int?,
      title: enc.decryptText(map['title']) ?? '',
      category: enc.decryptText(map['category']) ?? 'Document',
      fileName: enc.decryptText(map['fileName']) ?? '',
      fileType: enc.decryptText(map['fileType']) ?? '',
      orientation: enc.decryptText(map['orientation']) ?? 'portrait',
      encryptedPath: map['encryptedPath'] as String? ?? '',
      notes: enc.decryptText(map['notes']) ?? '',
      orderIndex: map['orderIndex'] as int? ?? 0,
    );
  }
}
