import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wallet/models/finance_models.dart';

class FinanceImportRow {
  final DateTime date;
  final String description;
  final double amount;
  final String type;
  final String reference;
  const FinanceImportRow({required this.date, required this.description, required this.amount, required this.type, this.reference = ''});
}

class FinanceImportResult {
  final String fileName;
  final List<FinanceImportRow> rows;
  final List<String> headers;
  const FinanceImportResult({required this.fileName, required this.rows, this.headers = const []});
}

class FinanceImportService {
  static Future<FinanceImportResult?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    List<int>? bytes = file.bytes;
    if (bytes == null && file.path != null) bytes = await File(file.path!).readAsBytes();
    if (bytes == null) throw Exception('File tidak bisa dibaca.');
    final ext = (file.extension ?? '').toLowerCase();
    final table = ext == 'xlsx' ? _parseXlsx(bytes) : _parseDelimited(utf8.decode(bytes, allowMalformed: true));
    if (table.isEmpty) return FinanceImportResult(fileName: file.name, rows: const []);
    return _autoMap(file.name, table);
  }

  static List<List<String>> _parseDelimited(String raw) {
    final lines = const LineSplitter().convert(raw.replaceFirst('\ufeff', ''));
    if (lines.isEmpty) return [];
    final sample = lines.take(5).join('\n');
    final delimiters = [',', ';', '\t', '|'];
    var delimiter = ',';
    var best = -1;
    for (final d in delimiters) {
      final score = RegExp(RegExp.escape(d)).allMatches(sample).length;
      if (score > best) { best = score; delimiter = d; }
    }
    return lines.where((e) => e.trim().isNotEmpty).map((line) => _splitCsvLine(line, delimiter)).toList();
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final out = <String>[];
    final current = StringBuffer();
    bool quote = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (quote && i + 1 < line.length && line[i + 1] == '"') { current.write('"'); i++; } else { quote = !quote; }
      } else if (c == delimiter && !quote) {
        out.add(current.toString().trim()); current.clear();
      } else { current.write(c); }
    }
    out.add(current.toString().trim());
    return out;
  }

  static List<List<String>> _parseXlsx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    final shared = <String>[];
    if (sharedFile != null) {
      final xml = utf8.decode(List<int>.from(sharedFile.content as List), allowMalformed: true);
      for (final si in RegExp(r'<si[^>]*>(.*?)</si>', dotAll: true).allMatches(xml)) {
        final block = si.group(1) ?? '';
        final texts = RegExp(r'<t(?: [^>]*)?>(.*?)</t>', dotAll: true).allMatches(block).map((m) => _xmlDecode(m.group(1) ?? '')).toList();
        shared.add(texts.join(''));
      }
    }
    ArchiveFile? sheet = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheet == null) {
      final sheets = archive.files.where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')).toList();
      if (sheets.isNotEmpty) sheet = sheets.first;
    }
    if (sheet == null) return [];
    final xml = utf8.decode(List<int>.from(sheet.content as List), allowMalformed: true);
    final rows = <List<String>>[];
    for (final rm in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(xml)) {
      final block = rm.group(1) ?? '';
      final values = <int, String>{};
      int maxCol = 0;
      for (final cm in RegExp(r'<c([^>]*)>(.*?)</c>', dotAll: true).allMatches(block)) {
        final attrs = cm.group(1) ?? '';
        final cellBody = cm.group(2) ?? '';
        final ref = RegExp(r'r="([A-Z]+)[0-9]+"').firstMatch(attrs)?.group(1) ?? 'A';
        final col = _columnIndex(ref);
        maxCol = col > maxCol ? col : maxCol;
        final type = RegExp(r't="([^"]+)"').firstMatch(attrs)?.group(1);
        var value = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(cellBody)?.group(1) ?? '';
        if (type == 's') {
          final idx = int.tryParse(value) ?? -1;
          value = idx >= 0 && idx < shared.length ? shared[idx] : value;
        } else if (type == 'inlineStr') {
          value = RegExp(r'<t(?: [^>]*)?>(.*?)</t>', dotAll: true).firstMatch(cellBody)?.group(1) ?? '';
        }
        values[col] = _xmlDecode(value);
      }
      rows.add(List<String>.generate(maxCol + 1, (i) => values[i] ?? ''));
    }
    return rows;
  }

  static int _columnIndex(String letters) {
    int value = 0;
    for (final code in letters.codeUnits) value = value * 26 + (code - 64);
    return value - 1;
  }

  static String _xmlDecode(String value) => value
      .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"').replaceAll('&apos;', "'");

  static FinanceImportResult _autoMap(String fileName, List<List<String>> table) {
    int headerIndex = 0;
    int bestScore = -1;
    for (int i = 0; i < table.length && i < 15; i++) {
      final row = table[i].map((e) => e.toLowerCase()).join(' | ');
      int score = 0;
      for (final key in ['tanggal','date','amount','nominal','debit','credit','kredit','description','keterangan','mutasi','transaksi']) {
        if (row.contains(key)) score++;
      }
      if (score > bestScore) { bestScore = score; headerIndex = i; }
    }
    final headers = table[headerIndex].map((e) => e.trim()).toList();
    int find(List<String> terms) {
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].toLowerCase();
        if (terms.any(h.contains)) return i;
      }
      return -1;
    }
    final dateCol = find(['tanggal','date','waktu','time']);
    final descCol = find(['keterangan','description','deskripsi','merchant','uraian','transaksi','remark']);
    final amountCol = find(['amount','nominal','jumlah','nilai','mutation','mutasi']);
    final debitCol = find(['debit','keluar','withdrawal']);
    final creditCol = find(['credit','kredit','masuk','deposit']);
    final refCol = find(['referensi','reference','ref','id transaksi','transaction id']);

    final rows = <FinanceImportRow>[];
    for (int r = headerIndex + 1; r < table.length; r++) {
      final row = table[r];
      if (row.every((e) => e.trim().isEmpty)) continue;
      String cell(int idx) => idx >= 0 && idx < row.length ? row[idx].trim() : '';
      double debit = FinanceFormat.parseMoney(cell(debitCol));
      double credit = FinanceFormat.parseMoney(cell(creditCol));
      double amount = FinanceFormat.parseMoney(cell(amountCol));
      String type = 'expense';
      if (credit > 0) { amount = credit; type = 'income'; }
      else if (debit > 0) { amount = debit; type = 'expense'; }
      else if (amount < 0) { amount = amount.abs(); type = 'expense'; }
      else if (amount > 0) {
        final joined = row.join(' ').toLowerCase();
        type = joined.contains('kredit') || joined.contains('credit') || joined.contains('masuk') ? 'income' : 'expense';
      }
      if (amount <= 0) continue;
      final description = cell(descCol).isEmpty ? row.where((e) => e.trim().isNotEmpty).take(3).join(' ') : cell(descCol);
      rows.add(FinanceImportRow(date: _parseDate(cell(dateCol)), description: description, amount: amount, type: type, reference: cell(refCol)));
    }
    return FinanceImportResult(fileName: fileName, rows: rows, headers: headers);
  }

  static DateTime _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return DateTime.now();
    final excel = double.tryParse(value);
    if (excel != null && excel > 20000 && excel < 100000) {
      return DateTime(1899, 12, 30).add(Duration(days: excel.floor()));
    }
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;
    for (final pattern in [
      RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$'),
      RegExp(r'^(\d{1,2})[.](\d{1,2})[.](\d{2,4})$'),
    ]) {
      final m = pattern.firstMatch(value);
      if (m != null) {
        var year = int.parse(m.group(3)!); if (year < 100) year += 2000;
        return DateTime(year, int.parse(m.group(2)!), int.parse(m.group(1)!));
      }
    }
    return DateTime.now();
  }
}

