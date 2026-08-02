import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/contact_list.dart';
import '../services/contact_list_storage.dart';
import '../services/contact_storage.dart';

class ContactListsScreen extends StatefulWidget {
  const ContactListsScreen({super.key});

  @override
  State<ContactListsScreen> createState() => _ContactListsScreenState();
}

class _ContactListsScreenState extends State<ContactListsScreen> {
  final _listStorage = ContactListStorage();
  final _contactStorage = ContactStorage();
  final _uuid = const Uuid();

  List<ContactList> _lists = [];
  List<Contact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lists = await _listStorage.loadAll();
    final contacts = await _contactStorage.loadContacts();
    setState(() {
      _lists = lists;
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _showEditor({ContactList? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final selectedIds = <String>{...(existing?.contactIds ?? [])};

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nouvelle liste' : 'Modifier la liste'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom de la liste (ex : Clients VIP)')),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const Text('Ajoutez d\'abord des contacts dans l\'onglet Contacts.')
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: _contacts
                          .map((c) => CheckboxListTile(
                                dense: true,
                                title: Text(c.name),
                                subtitle: Text(c.email),
                                value: selectedIds.contains(c.id),
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    selectedIds.add(c.id);
                                  } else {
                                    selectedIds.remove(c.id);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      if (existing == null) {
        await _listStorage.add(ContactList(id: _uuid.v4(), name: nameController.text.trim(), contactIds: selectedIds.toList()));
      } else {
        await _listStorage.update(ContactList(id: existing.id, name: nameController.text.trim(), contactIds: selectedIds.toList()));
      }
      await _load();
    }
  }

  Future<void> _remove(String id) async {
    await _listStorage.remove(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Listes de contacts', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Nouvelle liste'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _lists.isEmpty
                ? const Center(child: Text('Aucune liste pour le moment.'))
                : ListView.builder(
                    itemCount: _lists.length,
                    itemBuilder: (context, index) {
                      final list = _lists[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.list_alt),
                          title: Text(list.name),
                          subtitle: Text('${list.contactIds.length} contact(s)'),
                          onTap: () => _showEditor(existing: list),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(list.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
