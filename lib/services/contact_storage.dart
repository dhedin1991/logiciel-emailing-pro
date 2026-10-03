import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/contact.dart';
import 'trash_service.dart';

class ContactStorage {
  static const _key = 'contacts';
  final _storage = const FlutterSecureStorage();

  Future<List<Contact>> loadContacts() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveContacts(List<Contact> contacts) async {
    final raw = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> addContact(Contact contact) async {
    final contacts = await loadContacts();
    contacts.add(contact);
    await saveContacts(contacts);
  }

  /// Ajoute plusieurs contacts d'un coup (utilisé après un import CSV/Excel),
  /// en ignorant les doublons d'adresse e-mail déjà présents.
  Future<int> addContacts(List<Contact> newContacts) async {
    final contacts = await loadContacts();
    final existingEmails = contacts.map((c) => c.email.toLowerCase()).toSet();
    var added = 0;
    for (final contact in newContacts) {
      if (!existingEmails.contains(contact.email.toLowerCase())) {
        contacts.add(contact);
        existingEmails.add(contact.email.toLowerCase());
        added++;
      }
    }
    await saveContacts(contacts);
    return added;
  }

  /// Retire un contact ; il part dans la corbeille (restaurable).
  Future<void> removeContact(String id) => removeContacts({id});

  Future<void> removeContacts(Set<String> ids) async {
    final contacts = await loadContacts();
    final removed = contacts.where((c) => ids.contains(c.id)).toList();
    contacts.removeWhere((c) => ids.contains(c.id));
    await saveContacts(contacts);
    if (removed.isNotEmpty) {
      await TrashService.instance.add(
        type: 'contact',
        label: removed.length == 1
            ? (removed.first.name.isNotEmpty ? removed.first.name : removed.first.email)
            : '${removed.length} contacts',
        payloads: removed.map((c) => c.toJson()).toList(),
      );
    }
  }

  Future<void> updateContact(Contact updated) async {
    final contacts = await loadContacts();
    final index = contacts.indexWhere((c) => c.id == updated.id);
    if (index >= 0) {
      contacts[index] = updated;
      await saveContacts(contacts);
    }
  }
}
