import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'email_cleaning_service.dart';

class CleaningListsStorage {
  static const _genericKey = 'cleaning_generic_prefixes';
  static const _disposableKey = 'cleaning_disposable_domains';
  final _storage = const FlutterSecureStorage();

  Future<List<String>> loadGenericPrefixes() async {
    final raw = await _storage.read(key: _genericKey);
    if (raw == null) return List.of(defaultGenericPrefixes);
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> saveGenericPrefixes(List<String> list) async {
    await _storage.write(key: _genericKey, value: jsonEncode(list));
  }

  Future<List<String>> loadDisposableDomains() async {
    final raw = await _storage.read(key: _disposableKey);
    if (raw == null) return List.of(defaultDisposableDomains);
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> saveDisposableDomains(List<String> list) async {
    await _storage.write(key: _disposableKey, value: jsonEncode(list));
  }
}
