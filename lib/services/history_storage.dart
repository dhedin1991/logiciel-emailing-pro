import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/sent_email_log.dart';

class HistoryStorage {
  static const _key = 'sent_email_history';
  static const _maxEntries = 500;
  final _storage = const FlutterSecureStorage();

  Future<List<SentEmailLog>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SentEmailLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add(SentEmailLog entry) async {
    final entries = await loadAll();
    entries.insert(0, entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _key);
  }

  Future<void> removeEntries(Set<String> ids) async {
    final entries = await loadAll();
    entries.removeWhere((e) => ids.contains(e.id));
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }
}
