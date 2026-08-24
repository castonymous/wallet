import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wallet/services/encryption_service.dart';

class VaultFileService {
  static const MethodChannel _channel = MethodChannel('com.oisgrafika.wallet/save_file');

  static Future<String?> savePrivateCopy(File source, {String? preferredName}) async {
    final docs = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(docs.path, 'vault_files'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);

    final originalName = preferredName ?? p.basename(source.path);
    final extension = p.extension(originalName).toLowerCase();
    final safeExtension = extension.isEmpty ? '.bin' : extension;
    final target = File(
      p.join(vaultDir.path, '${DateTime.now().microsecondsSinceEpoch}$safeExtension'),
    );
    await source.copy(target.path);
    return EncryptionService.instance.encryptImageFile(target.path);
  }

  static Future<Uint8List?> readEncryptedBytes(String encryptedPath) {
    return EncryptionService.instance.decryptImageToBytes(encryptedPath, useCache: false);
  }

  static Future<Uint8List?> renderPdfFirstPage(String encryptedPath) async {
    final bytes = await readEncryptedBytes(encryptedPath);
    if (bytes == null) return null;
    return _channel.invokeMethod<Uint8List>('renderPdfFirstPage', {'bytes': bytes});
  }

  static Future<String?> saveEncryptedImageAsPngToGallery(
    String encryptedPath, {
    required String fileName,
  }) async {
    final bytes = await readEncryptedBytes(encryptedPath);
    if (bytes == null) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unsupported image format.');
    final pngBytes = Uint8List.fromList(img.encodePng(decoded));
    final cleanName = _safeFileName(fileName, extension: 'png');
    return _channel.invokeMethod<String>('saveImageToGallery', {
      'bytes': pngBytes,
      'name': cleanName,
    });
  }

  static Future<String?> shareEncryptedImageAsPng(
    String encryptedPath, {
    required String fileName,
  }) async {
    final uri = await saveEncryptedImageAsPngToGallery(
      encryptedPath,
      fileName: fileName,
    );
    if (uri == null) return null;
    await _channel.invokeMethod('shareMediaUri', {
      'uri': uri,
      'mimeType': 'image/png',
    });
    return uri;
  }

  static Future<String?> exportEncryptedFile({
    required String encryptedPath,
    required String suggestedName,
  }) async {
    final bytes = await readEncryptedBytes(encryptedPath);
    if (bytes == null) return null;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save a decrypted copy',
      fileName: _safeFileName(suggestedName),
      bytes: bytes,
      type: FileType.any,
    );
    return path;
  }

  static Future<String> docxTextPreview(String encryptedPath) async {
    final bytes = await readEncryptedBytes(encryptedPath);
    if (bytes == null) return 'Unable to decrypt this DOCX file.';
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = archive.findFile('word/document.xml');
      if (documentXml == null) return 'DOCX preview is unavailable.';
      final content = documentXml.content;
      final xmlBytes = content is Uint8List
          ? content
          : Uint8List.fromList(List<int>.from(content as List));
      var xml = utf8.decode(xmlBytes, allowMalformed: true);
      // Convert Word structural breaks into synthetic text runs first so
      // paragraph/tab/newline information survives the later <w:t> extraction.
      xml = xml
          .replaceAll(RegExp(r'</w:p>'), '<w:t>\n</w:t>')
          .replaceAll(RegExp(r'<w:tab[^>]*/>'), '<w:t>\t</w:t>')
          .replaceAll(RegExp(r'<w:br[^>]*/>'), '<w:t>\n</w:t>');
      final matches = RegExp(r'<w:t(?: [^>]*)?>(.*?)</w:t>', dotAll: true)
          .allMatches(xml)
          .map((m) => m.group(1) ?? '')
          .toList();
      var text = matches.join(' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll(RegExp(r' +'), ' ')
          .replaceAll(RegExp(r'\n +'), '\n')
          .trim();
      if (text.isEmpty) return 'No readable text was found in this DOCX file.';
      if (text.length > 12000) text = '${text.substring(0, 12000)}\n\n… Preview truncated';
      return text;
    } catch (_) {
      return 'DOCX preview is unavailable. You can still export the original file.';
    }
  }

  static String _safeFileName(String name, {String? extension}) {
    var result = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (result.isEmpty) result = 'OIS_Wallet_${DateTime.now().millisecondsSinceEpoch}';
    if (extension != null && !result.toLowerCase().endsWith('.$extension')) {
      result = '$result.$extension';
    }
    return result;
  }
}
