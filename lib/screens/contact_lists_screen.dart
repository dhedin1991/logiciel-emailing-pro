import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/contact_list.dart';
import '../services/contact_import_service.dart';
import '../services/contact_list_storage.dart';
import '../services/contact_storage.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

class ContactListsScreen extends StatefulWidget {
  const ContactListsScreen({super.key});

  @override
  State<ContactListsScreen> createState() => _ContactListsScreenState();
}

class _ContactListsScreenState extends State<ContactListsScreen> {
  final _listStorage = ContactListStorage();
  final _contactStorage = ContactStorage();
  final _importService = ContactImportService();
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
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _showEditor({ContactList? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final selectedIds = <String>{...(existing?.contactIds ?? [])};
    var localContacts = List<Contact>.of(_contacts);
    String? importStatus;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nouvelle liste' : 'Modifier la liste'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom de la liste (ex : Clients VIP)')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['csv', 'xlsx', 'txt'],
                    );
                    final path = result?.files.single.path;
                    if (path == null) return;
                    try {
                      final imported = await _importService.importFromFile(path);
                      final added = await _contactStorage.addContacts(imported);
                      localContacts = await _contactStorage.loadContacts();
                      // Coche automatiquement tous les contacts importés dans cette liste.
                      for (final c in imported) {
                        final match = localContacts.firstWhere(
                          (lc) => lc.email.toLowerCase() == c.email.toLowerCase(),
                          orElse: () => c,
                        );
                        selectedIds.add(match.id);
                      }
                      setDialogState(() {
                        importStatus = '$added nouveau(x) contact(s) importé(s) et ajouté(s) à la liste.';
                      });
                    } catch (e) {
                      setDialogState(() => importStatus = 'Échec de l\'import : ${e.toString()}');
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importer un fichier dans cette liste (CSV, Excel, texte)'),
                ),
                if (importStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(importStatus!, style: const TextStyle(fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                if (localContacts.isEmpty)
                  const Text('Ajoutez d\'abord des contacts dans l\'onglet Contacts, ou importez un fichier ci-dessus.')
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: localContacts
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
    nameController.dispose();
  }

  Future<void> _remove(String id) async {
    final list = _lists.firstWhere((l) => l.id == id);
    await deleteWithUndo(
      context: context,
      itemLabel: list.name,
      onDelete: () async {
        await _listStorage.remove(id);
        await _load();
      },
      onUndo: () async {
        await _listStorage.add(list);
        await _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonListLoader();

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
                ? const EmptyState(
                    icon: Icons.list_alt,
                    title: 'Aucune liste pour le moment',
                    subtitle: 'Regroupez vos contacts par pays, type de client, etc.',
                  )
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
                            tooltip: 'Supprimer',
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
