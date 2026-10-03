import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/contact_list.dart';
import 'trash_service.dart';

class ContactListStorage {
  static const _key = 'contact_lists';
  final _storage = const FlutterSecureStorage();

  Future<List<ContactList>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => ContactList.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAll(List<ContactList> lists) async {
    final raw = jsonEncode(lists.map((l) => l.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> add(ContactList list) async {
    final lists = await loadAll();
    lists.add(list);
    await saveAll(lists);
  }

  Future<void> remove(String id) async {
    final lists = await loadAll();
    final removed = lists.where((l) => l.id == id).toList();
    lists.removeWhere((l) => l.id == id);
    await saveAll(lists);
    if (removed.isNotEmpty) {
      await TrashService.instance.add(
        type: 'contactList',
        label: removed.first.name,
        payloads: removed.map((l) => l.toJson()).toList(),
      );
    }
  }

  Future<void> update(ContactList updated) async {
    final lists = await loadAll();
    final index = lists.indexWhere((l) => l.id == updated.id);
    if (index >= 0) {
      lists[index] = updated;
      await saveAll(lists);
    }
  }
}
