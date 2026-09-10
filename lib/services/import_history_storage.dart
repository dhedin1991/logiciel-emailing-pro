import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ImportLogEntry {
  final String id;
  final String type; // 'contact_import' | 'email_cleaning'
  final DateTime timestamp;
  final String summary;

  ImportLogEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'summary': summary,
      };

  factory ImportLogEntry.fromJson(Map<String, dynamic> json) => ImportLogEntry(
        id: json['id'] as String,
        type: json['type'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        summary: json['summary'] as String,
      );
}

class ImportHistoryStorage {
  static const _key = 'import_history';
  static const _maxEntries = 200;
  final _storage = const FlutterSecureStorage();

  Future<List<ImportLogEntry>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => ImportLogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add(ImportLogEntry entry) async {
    final entries = await loadAll();
    entries.insert(0, entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    await _storage.write(key: _key, value: jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _key);
  }

  Future<void> removeEntries(Set<String> ids) async {
    final entries = await loadAll();
    entries.removeWhere((e) => ids.contains(e.id));
    await _storage.write(key: _key, value: jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}
