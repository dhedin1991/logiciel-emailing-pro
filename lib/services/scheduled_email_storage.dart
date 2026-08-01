import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/scheduled_email.dart';

class ScheduledEmailStorage {
  static const _key = 'scheduled_emails';
  final _storage = const FlutterSecureStorage();

  Future<List<ScheduledEmail>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => ScheduledEmail.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAll(List<ScheduledEmail> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> add(ScheduledEmail item) async {
    final items = await loadAll();
    items.add(item);
    await saveAll(items);
  }

  Future<void> remove(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }

  Future<void> update(ScheduledEmail updated) async {
    final items = await loadAll();
    final index = items.indexWhere((e) => e.id == updated.id);
    if (index >= 0) {
      items[index] = updated;
      await saveAll(items);
    }
  }
}
