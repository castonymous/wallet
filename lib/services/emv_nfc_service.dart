import 'package:emv_nfc_reader/emv_nfc_reader.dart';

class NfcBankCardData {
  final String pan;
  final String expiry;
  final String cardholder;
  final String label;

  const NfcBankCardData({
    required this.pan,
    required this.expiry,
    required this.cardholder,
    required this.label,
  });

  String get lastFour {
    if (pan.length <= 4) return pan;
    return pan.substring(pan.length - 4);
  }

  String get maskedPan {
    if (pan.isEmpty) return 'Not available';
    if (pan.length <= 4) return pan;
    return '•••• •••• •••• $lastFour';
  }
}

/// Read-only EMV NFC helper used only to speed up adding a user's own card.
///
/// OIS Finance intentionally keeps only the fields needed by the wallet form.
/// It does not retain or expose PIN, CVV/CVC, cryptographic keys, transaction
/// history, counters, or other EMV diagnostic fields returned by the plugin.
class EmvNfcService {
  final EmvNfcReader _reader = EmvNfcReader();

  Future<NfcBankCardData?> scanBankCard() async {
    final data = await _reader.startReading();
    if (data == null) return null;

    final pan = _digits(data['pan']);
    final expiry = _normalizeExpiry(data['expiry']);

    return NfcBankCardData(
      pan: pan,
      expiry: expiry,
      cardholder: (data['cardholder'] ?? '').trim(),
      label: (data['label'] ?? '').trim(),
    );
  }

  static String _digits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  /// Wallet stores expiry as MMYY. EMV readers may expose MM/YY, MMYY,
  /// or the EMV 5F24 representation YYMMDD, so normalize the common forms.
  static String _normalizeExpiry(String? value) {
    final digits = _digits(value);
    if (digits.length >= 6) {
      final yy = digits.substring(0, 2);
      final mm = digits.substring(2, 4);
      final month = int.tryParse(mm) ?? 0;
      if (month >= 1 && month <= 12) return '$mm$yy';
    }
    if (digits.length == 4) {
      final first = int.tryParse(digits.substring(0, 2)) ?? 0;
      final second = int.tryParse(digits.substring(2, 4)) ?? 0;
      if (first >= 1 && first <= 12) return digits; // MMYY
      if (second >= 1 && second <= 12) {
        return '${digits.substring(2, 4)}${digits.substring(0, 2)}'; // YYMM
      }
    }
    return '';
  }
}
