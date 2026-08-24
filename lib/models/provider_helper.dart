import 'package:flutter/material.dart';
import 'package:wallet/models/db_helper.dart';
import 'package:wallet/services/auto_backup_service.dart';

class WalletProvider with ChangeNotifier {
  List<Wallet> wallets = [];

  Future<void> fetchWallets() async {
    wallets = await DatabaseHelper.instance.getWalletsSummary();
    notifyListeners();
  }

  Future<Wallet?> getWalletDetails(int id) async {
    return await DatabaseHelper.instance.getWalletById(id);
  }

  Future<void> deleteWallet(int id) async {
    await DatabaseHelper.instance.deleteWallet(id);
    wallets.removeWhere((w) => w.id == id);
    notifyListeners();
    AutoBackupService.triggerBackup();
  }

  Future<void> reorderWallets(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final wallet = wallets.removeAt(oldIndex);
    wallets.insert(newIndex, wallet);

    // Update order indices internally
    for (int i = 0; i < wallets.length; i++) {
      wallets[i].orderIndex = i;
    }

    await DatabaseHelper.instance.updateWalletsOrder(wallets);
    notifyListeners();
  }
}

class PassProvider with ChangeNotifier {
  List<Pass> passes = [];

  Future<void> fetchPasses() async {
    passes = await PassDatabaseHelper.instance.getAllPasses();
    notifyListeners();
  }

  Future<void> deletePass(int id) async {
    await PassDatabaseHelper.instance.deletePass(id);
    passes.removeWhere((p) => p.id == id);
    notifyListeners();
    AutoBackupService.triggerBackup();
  }

  Future<void> reorderPasses(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final pass = passes.removeAt(oldIndex);
    passes.insert(newIndex, pass);

    // Update order indices internally
    for (int i = 0; i < passes.length; i++) {
      passes[i].orderIndex = i;
    }

    await PassDatabaseHelper.instance.updatePassesOrder(passes);
    notifyListeners();
  }

  /// Deep search through all pass fields
  List<Pass> searchPasses(String query) {
    if (query.isEmpty) return passes;
    final lowercaseQuery = query.toLowerCase();

    return passes.where((pass) {
      // Basic fields
      if (pass.organizationName.toLowerCase().contains(lowercaseQuery)) return true;
      if (pass.description != null && pass.description!.toLowerCase().contains(lowercaseQuery)) return true;
      if (pass.logoText != null && pass.logoText!.toLowerCase().contains(lowercaseQuery)) return true;
      if (pass.barcodeValue.toLowerCase().contains(lowercaseQuery)) return true;
      if (pass.barcodeAltText != null && pass.barcodeAltText!.toLowerCase().contains(lowercaseQuery)) return true;

      // Search through dynamic fields
      if (pass.fields != null) {
        for (final section in pass.fields!.values) {
          if (section is List) {
            for (final field in section) {
              if (field is Map) {
                final label = field['label']?.toString() ?? '';
                final value = field['value']?.toString() ?? '';
                if ((label.isNotEmpty && label.toLowerCase().contains(lowercaseQuery)) ||
                    (value.isNotEmpty && value.toLowerCase().contains(lowercaseQuery))) {
                  return true;
                }
              }
            }
          }
        }
      }
      return false;
    }).toList();
  }
}

class IdentityProvider with ChangeNotifier {
  List<IdentityCard> identities = [];

  Future<void> fetchIdentities() async {
    identities = await IdentityDatabaseHelper.instance.getAllIdentities();
    notifyListeners();
  }

  Future<void> deleteIdentity(int id) async {
    await IdentityDatabaseHelper.instance.deleteIdentity(id);
    identities.removeWhere((i) => i.id == id);
    notifyListeners();
    AutoBackupService.triggerBackup();
  }

  Future<void> reorderIdentities(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final card = identities.removeAt(oldIndex);
    identities.insert(newIndex, card);

    for (int i = 0; i < identities.length; i++) {
      identities[i].orderIndex = i;
    }

    await IdentityDatabaseHelper.instance.updateIdentitiesOrder(identities);
    notifyListeners();
  }

  List<IdentityCard> searchIdentities(String query) {
    if (query.isEmpty) return identities;
    final lowercaseQuery = query.toLowerCase();

    return identities.where((card) {
      return card.name.toLowerCase().contains(lowercaseQuery) ||
          card.value.toLowerCase().contains(lowercaseQuery) ||
          card.cardType.toLowerCase().contains(lowercaseQuery) ||
          (card.category?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }
}



class EWalletProvider with ChangeNotifier {
  List<EWalletAccount> items = [];

  Future<void> fetchItems() async {
    items = await EWalletDatabaseHelper.instance.getAll();
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    await EWalletDatabaseHelper.instance.delete(id);
    items.removeWhere((e) => e.id == id);
    notifyListeners();
    AutoBackupService.triggerBackup();
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    await EWalletDatabaseHelper.instance.updateOrder(items);
    notifyListeners();
  }

  List<EWalletAccount> search(String query) {
    if (query.trim().isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((e) =>
      e.provider.toLowerCase().contains(q) ||
      e.accountName.toLowerCase().contains(q) ||
      e.phoneNumber.toLowerCase().contains(q)
    ).toList();
  }
}

class DocumentProvider with ChangeNotifier {
  List<DocumentItem> items = [];

  Future<void> fetchItems() async {
    items = await DocumentDatabaseHelper.instance.getAll();
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    await DocumentDatabaseHelper.instance.delete(id);
    items.removeWhere((e) => e.id == id);
    notifyListeners();
    AutoBackupService.triggerBackup();
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    await DocumentDatabaseHelper.instance.updateOrder(items);
    notifyListeners();
  }

  List<DocumentItem> search(String query) {
    if (query.trim().isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((e) =>
      e.title.toLowerCase().contains(q) ||
      e.category.toLowerCase().contains(q) ||
      e.fileName.toLowerCase().contains(q) ||
      e.notes.toLowerCase().contains(q)
    ).toList();
  }
}
