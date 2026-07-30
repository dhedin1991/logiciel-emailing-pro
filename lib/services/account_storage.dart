import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/email_account.dart';

/// Gère la sauvegarde chiffrée des comptes connectés sur l'appareil.
/// Utilise le trousseau Windows (Credential Manager) ou Android (Keystore)
/// selon la plateforme — jamais de mot de passe ou jeton en clair.
class AccountStorage {
  static const _key = 'connected_accounts';
  final _storage = const FlutterSecureStorage();

  Future<List<EmailAccount>> loadAccounts() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => EmailAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAccounts(List<EmailAccount> accounts) async {
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> addOrUpdateAccount(EmailAccount account) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.email == account.email);
    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    await saveAccounts(accounts);
  }

  Future<void> removeAccount(String email) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.email == email);
    await saveAccounts(accounts);
  }
}
