import 'dart:io';
import 'package:flutter/services.dart';
import 'package:wallet/models/finance_models.dart';

class FinanceNativeService {
  static const MethodChannel _channel = MethodChannel('com.oisgrafika.wallet/finance');

  static bool get supported => Platform.isAndroid;

  static Future<void> updateWidgets({required double available, required double liabilities, required double receivables, required double netWorth, required String nextDue}) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('updateWidgets', {
        'available': FinanceFormat.rupiah(available, compact: true),
        'liabilities': FinanceFormat.rupiah(liabilities, compact: true),
        'receivables': FinanceFormat.rupiah(receivables, compact: true),
        'netWorth': FinanceFormat.rupiah(netWorth, compact: true),
        'nextDue': nextDue,
      });
    } catch (_) {}
  }

  static Future<void> setWidgetPrivacy(bool hidden) async {
    if (!supported) return;
    try { await _channel.invokeMethod('setWidgetPrivacy', {'hidden': hidden}); } catch (_) {}
  }

  static Future<bool> getWidgetPrivacy() async {
    if (!supported) return false;
    try { return await _channel.invokeMethod<bool>('getWidgetPrivacy') ?? false; } catch (_) { return false; }
  }

  static Future<String?> consumeLaunchAction() async {
    if (!supported) return null;
    try { return await _channel.invokeMethod<String>('consumeLaunchAction'); } catch (_) { return null; }
  }

  static Future<bool> isNotificationAccessEnabled() async {
    if (!supported) return false;
    try { return await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false; } catch (_) { return false; }
  }

  static Future<void> openNotificationAccessSettings() async {
    if (!supported) return;
    try { await _channel.invokeMethod('openNotificationAccessSettings'); } catch (_) {}
  }

  static Future<List<FinanceNotificationDraft>> getNotificationDrafts() async {
    if (!supported) return [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getNotificationDrafts') ?? [];
      return raw.map((e) => FinanceNotificationDraft.fromNative(Map<dynamic, dynamic>.from(e as Map))).toList();
    } catch (_) { return []; }
  }

  static Future<void> removeNotificationDraft(String id) async {
    if (!supported) return;
    try { await _channel.invokeMethod('removeNotificationDraft', {'id': id}); } catch (_) {}
  }

  static Future<String> ocrImage(String path) async {
    if (!supported) return '';
    try { return await _channel.invokeMethod<String>('ocrImage', {'path': path}) ?? ''; } catch (_) { return ''; }
  }
}
