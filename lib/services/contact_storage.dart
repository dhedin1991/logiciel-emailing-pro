import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/contact.dart';

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

  Future<void> removeContact(String id) async {
    final contacts = await loadContacts();
    contacts.removeWhere((c) => c.id == id);
    await saveContacts(contacts);
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
